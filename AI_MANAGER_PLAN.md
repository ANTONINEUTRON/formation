# AI Manager: implementation plan

**Status:** not started. The app currently ships only the entry point: the ✨ button in the app bar
(`formation_app_bar.dart`). It opens a "coming soon" explainer page, `AiManagerPage`
(`app/lib/features/ai_manager/ui/pages/ai_manager_page.dart`), at `/ai-manager`. This document is the
plan for building the real feature.

## What it is

The AI Manager is an assistant that advises the manager. It reads their squad, points and live prices,
and then does four things:

1. **Squad review.** One tap gives a short write-up covering tier balance, weak slots and a captain pick.
2. **Chat.** Free-form questions about the manager's own lineup, points and holdings.
3. **Suggested moves.** Concrete actions the manager applies with a tap: set captain, fill a slot,
   change formation. It never signs or trades.
4. **Rules explained.** Scoring, alpha against SPYx, substitutions and risk tiers.

Each reply costs **1 credit**. Credits are sold in packs **priced in USD and paid in SKR**.

**Positioning.** It gives advice only. Scores still come from the deterministic engine, which keeps
`pitch.md` point 3 ("a match engine, not AI") true.

## Backend: `backend/src/assistant/` (NestJS)

All routes sit behind the existing bearer guard (`backend/src/auth/auth.guard.ts`).

| Route | Body | Returns |
|---|---|---|
| `POST /assistant/review` | `{ mode }` | `{ text, suggestions[], credits }` |
| `POST /assistant/chat` | `{ mode, messages[] }` | `{ text, suggestions[], credits }` |
| `GET /assistant/credits` | none | `{ balance, packs[] }` |
| `POST /assistant/credits/quote` | `{ packId }` | `{ quoteId, skrAmount, usd, expiresAt }` |
| `POST /assistant/credits/build` | `{ quoteId }` | the unsigned transaction (base64) |
| `POST /assistant/credits/confirm` | `{ quoteId, signature }` | `{ balance }` |

### LLM: Google Gemini behind an interface

- An `LlmProvider` interface with a `generate({ system, messages, responseSchema })` method. The
  implementation is a `GeminiProvider` built on `@google/genai`.
- The env vars go in `backend/.env` and `.env.example`: `GEMINI_API_KEY` and `GEMINI_MODEL`.
- **Never put the key in the app's envied config.** The web build ships those values to the browser.
- Request JSON output through `responseSchema`, shaped as `{ text: string, suggestions: Suggestion[] }`.

### Grounding context

The backend builds this per request from data it already has:

- **Roster, formation, captain and vice-captain:** the `roster` module.
- **Rules:** a summary of `domain/formation.ts` (tier per slot), `captaincy.ts`, `validate.ts` and the
  per-sport rules in `scoring/engine/rules/*.ts`.
- **Catalogue:** symbol, tier, price and 24h change, from `xstocks/xstocks-catalogue.service.ts`. The
  model may only suggest stocks that appear in this list.
- **Recent performance:** a new read over the `price_ticks` and `points_ledger` tables, giving alpha per
  held stock against `BENCHMARK_MINT` over the current window.
- **Substitutions used today:** the `daily_substitutions` table (3 free per day).
- **Wallet balances:** from `chain.service.ts`, so suggestions know what the manager already owns.

### Validating suggestions

```ts
type Suggestion =
  | { kind: 'setCaptain'; slotIndex: number; vice?: boolean }
  | { kind: 'fillSlot'; slotIndex: number; mint: string }
  | { kind: 'setFormation'; formation: string };
```

Before returning, run each suggestion through the existing `domain/validate.ts` against the current
roster, and drop any that are invalid. Set a `needsPurchase` flag on any `fillSlot` for a stock the
wallet doesn't hold.

## Credits: SKR packs priced in USD

### Migration `backend/migrations/011_assistant_credits.sql`

- `assistant_credits(user_id pk, balance int not null default 0, updated_at)`
- `credit_quotes(id pk, user_id, pack_id, skr_amount numeric, usd numeric, expires_at, used bool)`
- `credit_purchases(signature text unique, user_id, pack_id, skr_amount, usd, credits, created_at)`
- `assistant_usage(id, user_id, kind, tokens_in, tokens_out, cost_credits, created_at)`

### Config

| Variable | Example | Meaning |
|---|---|---|
| `ASSISTANT_PACKS` | `50:1,300:5,1000:15` | `credits:usd` pairs |
| `ASSISTANT_TREASURY` | an SKR token account | where SKR payments land |
| `ASSISTANT_QUOTE_SECONDS` | `60` | how long a quote holds |
| `ASSISTANT_FREE_CREDITS` | `0` | credits granted on first use |

If `SKR_MINT`/`SKR_DECIMALS` (from `domain/pay-tokens.ts`) or `ASSISTANT_TREASURY` are missing, purchases
are disabled. This follows how pay tokens refuse to guess values.

### Purchase flow

The flow mirrors `swap/`, which already has quote, build and confirm steps.

1. **Quote.**
   - Price the pack: `usd / SKR price`, using Jupiter `/price/v3` through `chain.service.ts`.
   - Scale the amount by the mint's real decimals.
   - Store the quote with an expiry.
2. **Build.** Create an SPL `transferChecked` of SKR from the user's associated token account (ATA) to
   `ASSISTANT_TREASURY`. Include the quote id as a memo.
3. **Sign.** The app signs and sends through the existing `WalletConnector`: MWA on Android, Wallet
   Standard on web.
4. **Confirm.** Fetch the transaction, then check all of the following:
   - it succeeded
   - the signer is the user's wallet
   - the mint is SKR, the destination is the treasury, and the amount is at least the quoted amount
   - the memo is the quote id
   - the quote hasn't expired or been used

   Then insert into `credit_purchases`. The unique signature makes replays impossible. Add the credits
   to the balance in the same database transaction.

### Charging a reply

In one database transaction, decrement the balance with `where balance >= 1`. If the decrement fails,
return HTTP 402 and the app shows the buy-pack sheet.

Then call Gemini. If the call fails, refund the credit and return 502. Log the token counts to
`assistant_usage`.

### Limits

- Per-user rate limit, for example 10 requests per minute.
- At most 20 messages of history, each up to 1,000 characters.
- `maxOutputTokens` set on every call.

## App: `app/lib/features/ai_manager/`

- **Data.** Add these methods to `FormationRepository` (`features/shared/data/formation_repository.dart`):
  - `assistantReview`
  - `assistantChat`
  - `assistantCredits`
  - `quoteCredits`
  - `buildCreditPurchase`
  - `confirmCreditPurchase`

  Implement them in `api_repository.dart`, and add fakes to `fixture_repository.dart` so the offline
  mode still works.
- **Models.** Add `AssistantReply`, `Suggestion` and `CreditPack` to `features/shared/domain/models.dart`
  (or a feature-local `domain/`).
- **State.** An `AssistantCubit` holding the messages, credits, loading flag and error. On HTTP 402 it
  opens the buy sheet.
- **UI.** Turn `AiManagerPage` from the explainer into the working screen:
  - a credits chip in the app bar, which opens `BuyCreditsSheet` (reuse the styling from
    `core/widgets/pay_token_picker.dart`)
  - a "Review my squad" button and a chat list with an input box
  - suggestion cards with **Apply**, which calls the existing `DraftCubit` methods `makeCaptain`,
    `makeViceCaptain`, `pick` and `setFormation`
  - for a `needsPurchase` suggestion, the card opens the existing `buy_stock_sheet` instead
  - on desktop width, the chat sits beside a compact squad view, following the existing layout rules
  - keep the explainer content as the empty state

## Onboarding for new accounts

Today `_AppGate` in `app/lib/features/app/app.dart` shows `OnboardingPage`
(`app/lib/features/onboarding/ui/pages/onboarding_page.dart`) whenever no wallet is connected. That
page is just the logo, the tagline and `ConnectWalletView`. New accounts will instead go through three
intro screens, connect a wallet, and then get a free starter squad from the AI Manager.

### Part 1: three intro screens, before connecting a wallet

A `PageView` with dot indicators, plus **Skip** and **Next** buttons. The last screen ends on the existing
`ConnectWalletView`.

1. **Your stocks are your players.** You pick real tokenized stocks (xStocks) for each slot in a
   formation. Each slot needs a risk tier.
2. **You score when they beat the market.** Points come from alpha against SPYx. You get a captain
   (double points), 3 free substitutions a day, and leagues to compete in.
3. **Meet your AI Manager.** It reviews your squad, answers questions and suggests moves, and you
   always decide. Your first squad suggestion is free.

- **Show the intro only once.** Store an `onboarding_seen` flag in local storage, using the same
  persistence the bearer token already uses. Returning users who are only reconnecting a wallet skip
  straight to the last screen.
- **Layout.** At desktop width, show the three screens side by side above the connect button instead of
  as a carousel, following the existing window-based layout rules.

### Part 2: free starter squad, after connecting the wallet

**Backend: detecting a new account**
- `GET /users/me` (`backend/src/users/users.controller.ts`) gains a field
  `onboarding: { starterDraftUsed: boolean }`.
- **Migration:** add `users.starter_draft_used boolean not null default false` to `011_assistant_credits.sql`.

**The starter draft**
- The app shows the starter flow when `starterDraftUsed` is false **and** the user's roster for the
  chosen mode is empty.
- **Sport.** The user picks football, basketball or American football. This sets `mode` for the roster
  endpoints.
- **Budget.** The user enters an amount to spend. Default $10, and at least the per-buy minimum from
  `domain/pay-tokens.ts` times the number of slots. They also pick the pay token, USDC or SKR, using the
  existing `pay_token_picker.dart`.

**Endpoint `POST /assistant/starter`**
- Body: `{ mode, budgetUsd, style? }`, where `style` is one of `safe`, `balanced` or `bold`, chosen with
  a single toggle in the UI.
- It **costs no credit** but works only once. In one database transaction it checks
  `starter_draft_used = false` and sets it to true. If the Gemini call fails, it sets the flag back to
  false.
- It returns a formation, a captain, a vice-captain and one stock per slot. The amounts are split across
  slots and every slot must meet the minimum buy.
- It is validated like every other suggestion: each slot's tier must match `domain/formation.ts`, and
  every stock must be in the catalogue.

**App screen `StarterSquadPage`**
- Shows the proposed squad on the existing `formation_board` widget, with the AI's short reasoning per
  pick.
- The user can tap a slot to swap the stock (existing `stock_picker_sheet`), change the formation, or
  regenerate once.
- **Confirm** does two things in this order:
  1. Writes the roster through the existing `DraftCubit` calls `setFormation`, `pick` and `makeCaptain`.
  2. Buys the stocks the wallet doesn't hold, one at a time, through the existing swap flow
     (`buy_stock_sheet` and the quote, build and confirm endpoints). The user signs each swap.

  A partial failure leaves a valid roster with some slots not yet owned. The existing team view
  already handles that.
- **"I'll build it myself"** skips to the normal draft board and marks the starter draft as used.

**Placement.** Add a step after connecting in `_AppGate`. Either route to `StarterSquadPage`, or
show it as the initial route inside `_ConnectedApp` when it is needed.

### Onboarding tests
- **Backend:** `/assistant/starter` succeeds once and is rejected the second time. A failed call
  clears the flag again. Invalid tiers are fixed up or rejected.
- **App:**
  - Widget tests: the intro shows once, Skip goes to connect, and the starter screen appears only for an
    empty roster.
  - Fixture fakes for the starter response.

## Tests

- **Backend (vitest):**
  - credit accounting: a double confirm fails, an expired quote is rejected, an underpaid amount is
    rejected, and a failed LLM call refunds the credit
  - suggestion validation drops illegal moves
  - all with a mocked `LlmProvider`
- **App:** `AssistantCubit` tests using the fixture repository, including the 402 path that opens the
  buy sheet.
- **Manual:** buy the smallest pack with real SKR, check the balance, ask a question, and apply one
  suggestion.

## Decide at build time

- Pack sizes and USD prices.
- The number of free trial credits, if any, on top of the free starter squad.
- The default starter budget, and whether the starter flow can be reopened later from the AI Manager
  page.
- The Gemini model and tier, based on cost per review against quality.
- Whether to keep chat history server-side. Default: no, the client sends recent history.
