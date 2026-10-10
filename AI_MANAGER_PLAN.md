# AI Manager: implementation plan

**Status:** not started. The app currently ships only the entry point: the ✨ button in the app bar
(`formation_app_bar.dart`). It opens a "coming soon" explainer page, `AiManagerPage`
(`app/lib/features/ai_manager/ui/pages/ai_manager_page.dart`), at `/ai-manager`. This document is the
plan for building the real feature.

## What it is

The AI Manager is an animated character, the manager's assistant in the dugout. It lives in a glassy
panel that opens over whatever screen the manager is on. It already knows the sport, the lineup and the
screen it was opened from. It does five things:

1. **Squad review.** One tap gives a short write-up covering tier balance, weak slots and a captain pick.
2. **Chat.** Free-form questions about the manager's own lineup, points and holdings.
3. **Stock intel.** For a question like "What is AAPLx all about?", it gathers the latest information and
   answers with an interactive stats board, which can switch to a chart or a bubble map.
4. **Suggested moves.** Concrete actions the manager applies with a tap: set captain, fill a slot,
   change formation. It never signs or trades.
5. **Rules explained.** Scoring, alpha against SPYx, substitutions and risk tiers.

**Costs.** Each reply costs **1 credit**. Credits are sold in packs **priced in USD and paid in SKR**.
New accounts get a small trial allowance, a free starter squad, and one free custom avatar.

**Positioning.** It gives advice only. Scores still come from the deterministic engine, which keeps
`pitch.md` point 3 ("a match engine, not AI") true.

## The experience

### Opening it

- The ✨ button in the app bar opens the AI Manager **over the current screen**. It is no longer a
  separate page:
  - **Phone:** a `DraggableScrollableSheet` that starts at about 60% height and can be dragged to full
    height.
  - **Wide windows:** a centred dialog, about 560×720.
- **The glass look:**
  - `BackdropFilter` blur (sigma about 24) over a translucent `AppColors.surface` at about 70%
    opacity, with a 1px light border and a soft lime glow behind the character.
  - When reduced motion is requested (`MediaQuery.disableAnimations`), animations are swapped for
    plain fades.
- The `/ai-manager` route stays, so links still work. It opens the same panel on top of the home screen.
- Closing keeps the conversation for the rest of the session (see Context).

### Layout inside the panel

```
┌──────────────────────────────────────────────┐
│ (character, animated)  Coach Nova  [42 cr] ✕ │
│  "Your DEF line is leaking points…"          │
├──────────────────────────────────────────────┤
│ [Review squad] [Captain pick] [Explain alpha]│ ← quick chips, change with screen
│                                              │
│  You: what is AAPLx all about?               │
│  ┌ AAPLx · Apple ─────────── Blue chip ┐     │
│  │ $231.40  +1.2% 24h   α +0.4 (7d)    │     │ ← stats-board card
│  │ [Price] [vs SPYx] [Bubble map]      │     │ ← toggles the view in place
│  │ News: … (source links)              │     │
│  │ [Make captain] [Buy more]           │     │ ← actions wired into the app
│  └─────────────────────────────────────┘     │
│                                              │
│ [ Ask your manager…                ] [Send]  │
└──────────────────────────────────────────────┘
```

- **Character header.** The character's animation follows what is happening:

  | State | When |
  |---|---|
  | idle | waiting for input |
  | thinking | a request is in flight |
  | talking | the reply streams in |
  | celebrating | points went up, or a suggestion was applied |
  | concerned | the reply is a warning |

- **Quick chips** change with the screen the panel was opened from:
  - draft board: "Fill my empty slots"
  - team: "Why am I losing points?"
  - a stock: "Tell me about AAPLx"
  - league: "How do I catch #1?"
- **Credits chip** opens the buy-credits sheet.

## Characters

### Five presets

Each preset has its own look and its own personality. The personality tilts both its advice and its
tone.

| Character | Personality | Advice style |
|---|---|---|
| The Veteran | calm, old-school | `safe`: stable and blue-chip heavy |
| The Analyst | data-first, precise | `balanced`, with numbers in every answer |
| The Maverick | bold, playful | `bold`: momentum and growth |
| The Mentor | encouraging, explains a lot | `balanced`, teaches the rules as it goes |
| The Scout | always hunting new names | `balanced`, suggests less-known catalogue stocks |

- The personality goes into the system prompt: tone, plus a `style` hint that leans picks toward
  `safe`, `balanced` or `bold`. The starter-squad `style` is the same value.
- **Animation:** one **Rive** file per character, each with a state machine for the five states above.
  This needs a designer. Until the art exists, ship static portraits with Flutter's own effects: a gentle
  bob, a glow that pulses while "thinking", and a bounce for "celebrating".

### Custom avatar from a photo

**Flow:**
1. The user uploads a photo and ticks "This is me, or I have permission".
2. The backend sends the photo to a **Gemini image model** with a style prompt that matches the presets'
   art style.
3. It generates **three expressions**: neutral, thinking and celebrating.
4. The user picks one of the five personalities for their avatar.

**Rules:**
- **Price:** the first custom avatar is free. Each regeneration costs `ASSISTANT_AVATAR_CREDITS`
  credits.
- **Privacy:** the photo is processed in memory and never stored. Only the generated images are kept.
- **Safety:** refuse when the model's safety filters trigger or no face is found, and refund the credits
  if any were charged.
- **Storage:** three small WebP images, about 50 KB each, kept in Postgres (`assistant_avatars`) and
  served from `GET /assistant/avatar/:userId/:expression` with long cache headers. No new storage
  service is needed.
- **Animation:** cross-fade between the three expressions, with the same bob and glow effects as the
  presets.

## Context sent with every message

The app attaches a **context envelope** to every request. The backend adds the server-side data, so
the app never has to send anything it could forge.

```ts
type AssistantContext = {
  mode: SportMode;                 // the sport tab the user is on
  screen: 'team' | 'draft' | 'league' | 'leagues' | 'stock' | 'profile' | 'manager';
  focus?: { mint?: string; leagueId?: string; managerId?: string; slotIndex?: number };
  characterId: string;             // preset id or 'custom'
};
```

**Server-side additions, per request:**
- **Roster:** lineup, formation, captain and vice-captain, from the `roster` module.
- **Points:** session points, season points, rank and the number of entrants (`general-scoring`,
  `league`).
- **Substitutions:** used and free today (`daily_substitutions`).
- **Recent performance:** alpha per held stock (`price_ticks` and `points_ledger`).
- **Wallet balances**, from `chain.service.ts`.
- **Catalogue slice:** symbol, tier, price and 24h change. The model may only suggest stocks from this
  list.
- **Rules summary:** `domain/formation.ts`, `captaincy.ts`, `validate.ts` and
  `scoring/engine/rules/*.ts`.
- **Focus details:** if `focus.leagueId` is set, the standings of that league. If `focus.mint` is set,
  that stock's price history.

**Chat history:**
- The app sends the last 20 messages, each capped at 1,000 characters.
- `AssistantCubit` keeps the history for the session. The last conversation per sport is also saved on
  the device, so closing and reopening the panel doesn't lose it.

## Answers: hybrid cards

Gemini returns structured JSON (`responseSchema`). The text part streams in, and the cards follow it.

```ts
type AssistantReply = {
  text: string;
  mood: 'neutral' | 'happy' | 'concerned';  // drives the character animation
  cards: Card[];
  suggestions: Suggestion[];
  sources?: { title: string; url: string }[];  // from search grounding
};

type Card =
  | { type: 'statBoard'; mint: string; stats: { label: string; value: string; tone?: 'up' | 'down' }[];
      views: ('price' | 'vsBenchmark' | 'bubbles')[] }
  | { type: 'lineChart'; title: string; series: { name: string; points: [number, number][] }[] }
  | { type: 'barChart'; title: string; bars: { label: string; value: number }[] }
  | { type: 'bubbleMap'; title: string; bubbles: { label: string; size: number; value: number; group?: string }[] }
  | { type: 'table'; columns: string[]; rows: string[][] }
  | { type: 'compare'; mints: string[] }
  | { type: 'html'; html: string; height: number };  // fallback, see below
```

### Native cards (the default)

- Flutter renders them with `fl_chart` for the line and bar charts. The bubble map is a `CustomPainter`
  with a simple force-directed layout.
- Everything uses the app's theme and tier colours.
- **Interaction:**
  - Tap to change the time range (1D, 7D, 30D).
  - Switch between the price, vs-SPYx and bubble views.
  - Long-press a point to see its value.
- **The numbers come from the server, not the model.** For `statBoard`, `lineChart` and `compare`, the
  model only chooses *which* card and *which* mint. The backend fills in the figures from
  `price_ticks`, the catalogue and the ledger. Charts can't show invented numbers, and the model's
  output stays small.
- **Bubble map examples:**
  - your squad, with size for position value, colour for alpha and grouping by tier
  - the catalogue, with size for liquidity and colour for 24h change

### HTML fallback (when no native card fits)

- Rendered in a **sandbox**:
  - Web: an `<iframe sandbox="allow-scripts">`, without `allow-same-origin`.
  - Android: a `WebView` with no JavaScript bridge.
- A strict Content Security Policy: `default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:`.
  This blocks network access, so the page can't fetch anything or leak anything.
- **Data goes in, never out.** The backend injects the data as a JSON blob, and the HTML only draws it.
- **Actions** go through `postMessage` against an allowlist (`openStock`, `setCaptain`, `fillSlot`). The
  app validates every action exactly as it validates suggestions, and nothing runs without a tap.
- Capped at 30 KB and a fixed height. The backend strips anything that fails the policy.
- Costs **2 credits**, because the reply is much longer.

## Live data

- **News and company context:** Gemini's built-in **Google Search grounding**. The answer cites its
  sources, and the card shows those links. These are text facts only; numbers in charts never come from
  search.
- **Prices, alpha, tier and points:** Formation's own data, from `price_ticks`, the catalogue and the
  ledger.
- **Tokenized-stock facts:** what an xStock is and that 1 xStock tracks 1 share. These come from the
  catalogue plus a short fixed explainer in the system prompt.
- **Cost:** a search-grounded reply costs **2 credits**, because grounding adds a per-request fee.
  Replies that don't use search stay at 1.

## Backend: `backend/src/assistant/` (NestJS)

All routes sit behind the existing bearer guard (`backend/src/auth/auth.guard.ts`).

| Route | Body | Returns |
|---|---|---|
| `POST /assistant/review` | `{ context }` | `AssistantReply` + `credits` |
| `POST /assistant/chat` | `{ context, messages[] }` | a stream (SSE) of text, then the cards, suggestions and credits |
| `POST /assistant/starter` | `{ mode, budgetUsd, style? }` | a starter squad (see Onboarding) |
| `GET /assistant/characters` | none | the presets, plus the user's custom avatar if any |
| `PUT /assistant/character` | `{ characterId, personality? }` | the saved choice |
| `POST /assistant/avatar` | the photo as multipart, plus `personality` | `{ avatarUrls, credits }` |
| `GET /assistant/avatar/:userId/:expression` | none | WebP |
| `GET /assistant/credits` | none | `{ balance, packs[] }` |
| `POST /assistant/credits/quote` | `{ packId }` | `{ quoteId, skrAmount, usd, expiresAt }` |
| `POST /assistant/credits/build` | `{ quoteId }` | the unsigned transaction (base64) |
| `POST /assistant/credits/confirm` | `{ quoteId, signature }` | `{ balance }` |

### LLM: Google Gemini behind an interface

- An `LlmProvider` interface with these methods:
  - `generate({ system, messages, responseSchema, tools })`
  - `stream(...)`
  - `generateImage({ prompt, image })`

  The implementation is a `GeminiProvider` built on `@google/genai`. Search grounding is passed in as a
  `tools` entry.
- The env vars go in `backend/.env` and `.env.example`: `GEMINI_API_KEY`, `GEMINI_MODEL` and
  `GEMINI_IMAGE_MODEL`.
- **Never put the key in the app's envied config.** The web build ships those values to the browser.

### Validating suggestions

```ts
type Suggestion =
  | { kind: 'setCaptain'; slotIndex: number; vice?: boolean }
  | { kind: 'fillSlot'; slotIndex: number; mint: string }
  | { kind: 'setFormation'; formation: string };
```

Before returning, run each suggestion through the existing `domain/validate.ts` against the current
roster, and drop any that are invalid. The backend also attaches these annotations for the UI:

- `needsPurchase`: the wallet doesn't hold the stock.
- `substitutionCost`: 0 if it fits in today's free substitutions, otherwise the point cost, using
  `substitutionCost()` from `score-entry.ts`.
- `rosterVersion`: lets the app spot a suggestion that is out of date.

## Credits: SKR packs priced in USD

### Migration `backend/migrations/011_assistant.sql`

- `assistant_credits(user_id pk, balance int not null default 0, trial_granted bool, updated_at)`
- `credit_quotes(id pk, user_id, pack_id, skr_amount numeric, usd numeric, expires_at, used bool)`
- `credit_purchases(signature text unique, user_id, pack_id, skr_amount, usd, credits, created_at)`
- `assistant_usage(id, user_id, kind, tokens_in, tokens_out, grounded bool, cost_credits, created_at)`
- `assistant_profiles(user_id pk, character_id text, personality text, free_avatar_used bool)`
- `assistant_avatars(user_id, expression, image bytea, created_at, primary key (user_id, expression))`
- `users.starter_draft_used boolean not null default false` (see Onboarding)

### Config

| Variable | Example | Meaning |
|---|---|---|
| `ASSISTANT_PACKS` | `50:1,300:5,1000:15` | `credits:usd` pairs |
| `ASSISTANT_TREASURY` | an SKR token account | where SKR payments land |
| `ASSISTANT_QUOTE_SECONDS` | `60` | how long a quote holds |
| `ASSISTANT_TRIAL_CREDITS` | `5` | credits granted on first use |
| `ASSISTANT_AVATAR_CREDITS` | `20` | cost of each avatar regeneration after the free one |

If `SKR_MINT`/`SKR_DECIMALS` (from `domain/pay-tokens.ts`) or `ASSISTANT_TREASURY` are missing, purchases
are disabled. This follows how pay tokens refuse to guess values.

**Users without SKR.** When the wallet's SKR balance is too low, the buy-credits sheet offers
"Swap USDC → SKR" through the existing swap flow.

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

- **Reserve:** in one database transaction, take the reply's cost off the balance with
  `where balance >= cost`. The cost is 1 credit, or 2 if the reply is search-grounded or HTML. If the
  balance is too low, return HTTP 402 and the app opens the buy sheet.
- **Ask Gemini.** If the call fails, refund the credits and return 502. Log the token counts to
  `assistant_usage`.
- **Grounded replies:** the backend can't know in advance whether the model will use search. It reserves
  2 credits whenever search is enabled for the request and refunds 1 if the model doesn't use it.

### Limits

- Per-user rate limit, for example 10 requests per minute and 3 avatar generations per day.
- At most 20 messages of history, each up to 1,000 characters.
- `maxOutputTokens` set on every call.

## App: `app/lib/features/ai_manager/`

- **Data.**
  - Add the assistant methods to `FormationRepository`
    (`features/shared/data/formation_repository.dart`): review, chat (streamed), starter, characters,
    avatar upload, credits, and the quote, build and confirm calls.
  - Implement them in `api_repository.dart`.
  - Add fakes to `fixture_repository.dart` (canned replies with every card type) so the offline demo
    works.
- **Models.** `AssistantReply`, `AssistantCard` (a sealed class, one subtype per card), `Suggestion`,
  `CreditPack`, `Character` and `AssistantContext`.
- **State.**
  - `AssistantCubit`: messages per sport, credits, the in-flight request, and the character's state
    (idle, thinking, talking, celebrating, concerned).
  - On HTTP 402, it opens the buy sheet.
  - **The context is built by the panel's opener.** The ✨ button reads the current sport tab, the
    route, and any focused stock, league or slot.
- **Widgets.**
  - `AssistantSheet`: a glassy `DraggableScrollableSheet` on phones and a dialog on wide windows,
    following the existing sheet/dialog switch in `core/widgets/adaptive_sheet.dart`.
  - `CharacterView`: Rive, or static images with simple Flutter animations.
  - `QuickChips`, `ChatList` and `Composer`.
  - One widget per card type: `StatBoardCard`, `LineChartCard`, `BarChartCard`, `BubbleMapCard`,
    `TableCard`, `CompareCard`, and `HtmlCard` (an iframe on web, a WebView on Android).
  - `SuggestionCard`:
    - **Apply** calls the existing `DraftCubit` methods `makeCaptain`, `makeViceCaptain`, `pick` and
      `setFormation`.
    - If the stock isn't owned, it says **Buy & apply** and opens `buy_stock_sheet`.
    - It shows the substitution cost first ("uses 1 of 3 free subs", or "costs 4 pts").
    - It marks itself **Applied** afterwards, or **Out of date** if the `rosterVersion` no longer
      matches.
  - `BuyCreditsSheet`: reuses the `core/widgets/pay_token_picker.dart` styling, and offers the swap to
    SKR when needed.
  - `CharacterPicker`: the five presets plus "Create from photo", using `image_picker` for the upload.
- **Empty state.** The character introduces itself, followed by the quick chips.

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
3. **Pick your manager.** Choose one of the five characters. The choice is saved after connecting, and
   making a custom one from a photo comes later. It reviews your squad, answers questions and suggests
   moves, and you always decide. Your first squad is on them.

- **Show the intro only once.** Store an `onboarding_seen` flag in local storage, using the same
  persistence the bearer token already uses. Returning users who are only reconnecting a wallet skip
  straight to the last screen.
- **Layout.** At desktop width, show the three screens side by side above the connect button instead of
  as a carousel, following the existing window-based layout rules.

### Part 2: free starter squad, after connecting the wallet

**Backend: detecting a new account**
- `GET /users/me` (`backend/src/users/users.controller.ts`) gains a field
  `onboarding: { starterDraftUsed: boolean }`.
- **Migration:** the `starter_draft_used` column in `011_assistant.sql`.

**The starter draft**
- The app shows the starter flow when `starterDraftUsed` is false **and** the user's roster for the
  chosen mode is empty.
- **Sport.** The user picks football, basketball or American football. This sets `mode` for the roster
  endpoints.
- **Budget.** The user enters an amount to spend. Default $10, and at least the per-buy minimum from
  `domain/pay-tokens.ts` times the number of slots. They also pick the pay token, USDC or SKR, using the
  existing `pay_token_picker.dart`.
- **Style.** The chosen character's personality sets the default style. The user can still change it.

**Endpoint `POST /assistant/starter`**
- Body: `{ mode, budgetUsd, style? }`, where `style` is one of `safe`, `balanced` or `bold`.
- It **costs no credit** but works only once. In one database transaction it checks
  `starter_draft_used = false` and sets it to true. If the Gemini call fails, it sets the flag back to
  false.
- It returns a formation, a captain, a vice-captain and one stock per slot. The amounts are split across
  slots and every slot must meet the minimum buy.
- It is validated like every other suggestion: each slot's tier must match `domain/formation.ts`, and
  every stock must be in the catalogue.

**App screen `StarterSquadPage`**
- The chosen character presents the squad on the existing `formation_board` widget, with a short reason
  per pick.
- The user can tap a slot to swap the stock (existing `stock_picker_sheet`), change the formation, or
  regenerate once.
- **Confirm** does two things in this order:
  1. Writes the roster through the existing `DraftCubit` calls `setFormation`, `pick` and `makeCaptain`.
  2. Buys the stocks the wallet doesn't hold, one at a time, through the existing swap flow
     (`buy_stock_sheet` and the quote, build and confirm endpoints). The user signs each swap.

  If some buys fail, the stocks already bought still score, because one held stock in the lineup is
  enough to be entered. The remaining slots can be filled later.
- **"I'll build it myself"** skips to the normal draft board and marks the starter draft as used.

**Placement.** Add a step after connecting in `_AppGate`. Either route to `StarterSquadPage`, or
show it as the initial route inside `_ConnectedApp` when it is needed.

## Build order

Each phase works on its own, so the work can stop after any of them:

1. **Core.**
   - Backend: Gemini provider, context envelope, review and chat, credits with SKR purchase.
   - App: the glassy sheet, static character portraits, chat, suggestion cards.
2. **Rich answers.** Native cards (stat board, line and bar charts, table, compare), search grounding
   with sources, and quick chips per screen.
3. **Onboarding.** The three intro screens and the free starter squad.
4. **Characters.** The five personalities, the Rive animations once the art is ready, the bubble map,
   and the HTML fallback card.
5. **Custom avatars.** Photo to avatar, free once.

## Tests

- **Backend (vitest):**
  - credit accounting: a double confirm fails, an expired quote is rejected, an underpaid amount is
    rejected, a failed LLM call refunds the credit, and an ungrounded reply refunds the extra credit
  - suggestion validation drops illegal moves, and `substitutionCost` is correct
  - the server fills chart data: a card asking for a mint returns real `price_ticks`, not model output
  - the HTML fallback is stripped and size-capped, and blocked network access doesn't break rendering
  - `/assistant/starter` succeeds once and is rejected the second time, and a failed call clears the
    flag again
  - the first avatar is free and the second is charged
  - all with a mocked `LlmProvider`
- **App:**
  - `AssistantCubit` tests using the fixture repository, including the 402 path that opens the buy sheet
  - golden tests for each card type
  - widget tests: the intro shows once, and the starter screen appears only for an empty roster
- **Manual:**
  - buy the smallest pack with real SKR
  - ask "What is AAPLx all about?" and check the stats board, the chart toggle and the source links
  - apply one suggestion, and create one avatar

## Decide at build time

- Pack sizes and USD prices.
- The trial credit count (default 5) and the cost of regenerating an avatar.
- The default starter budget, and whether the starter flow can be reopened later from the AI Manager.
- The Gemini text and image models and their tiers, based on cost per reply against quality.
- Who designs the five characters and their Rive animations, and the shared art style the photo avatars
  must match.
- Character names. The ones above are placeholders.
