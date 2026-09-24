# Formation — 2-Day Build Plan

> Pivoting the Formation codebase to Formation (fantasy sports for real tokenized stocks) for Stocklana.
> Product spec: [formation-stocklana-spec.md](../potential_pivot/formation-stocklana-spec.md)
>
> **Deadline:** Friday, September 18, 2026, 4:00 PM ET. Submission is the Android app as a demo video
> plus an APK.
>
> **Scope:** the Flutter app **and** the NestJS backend, built together. The earlier version of this
> plan built the whole UI against static fixtures and deferred the backend. That doesn't fit two days:
> judges score a working end-to-end demo, so both layers are built in parallel. Fixtures survive only as
> seed data and as a test stand-in.

---

## 1. Decisions

| Decision | Choice | Why |
|---|---|---|
| Client | **Flutter (Android)**, not the spec's Next.js | Wallet connect (MWA) and balance reads already work in [wallet_cubit.dart](../app/lib/features/wallet/ui/cubits/wallet_cubit.dart). Rewriting costs a day. MWA is Android-only, which is fine for a demo video + APK. |
| Backend | **NestJS** in [backend/](../backend/) | Scaffold already exists. It owns scoring, cron, Jupiter calls, and trophies. |
| Database | **Supabase Postgres**, called from NestJS | Already a dependency; schema from spec §4.2. The app never talks to Supabase directly. |
| On-chain program | **None** | Spec non-goal. [formation_program/](../formation_program/) is ignored. |
| Navigation | **3 nav bar tabs, one per sport:** Football, Basketball, American Football | Each sport is its own page with League / Team tabs. Profile moves to the app bar (§2.1). |
| Sport modes | **All three pages ship; Basketball's Team tab is the must-have** | One `SportPage(mode)` widget serves all three. Only the board shape differs, so Football and American Football are fixtures + court/pitch paint. If a board isn't ready, that Team tab shows a "coming soon" state; its League tab still works. |
| Create league | **FAB on every sport page shows "Coming soon"** | Private leagues are cut from the MVP (spec §6), but the entry point signals the roadmap. |
| Trophy | **Memo tx from a server keypair** (explorer link); Metaplex NFT is a stretch | Memo keeps the on-chain story with no mint infrastructure. |
| Auth | **SIWS-style signed message** via MWA `signMessages`, verified with tweetnacl | About an hour. Fallback: register by wallet address alone, called out as a known shortcut. |
| Fake live data | **None** | No price jitter. Scores move only through real ticks, triggered on demand by an admin endpoint. |

---

## 2. Architecture

```
Flutter app ──HTTP──▶ NestJS ──▶ Supabase (Postgres)
   │                    ├──▶ Solana RPC (xStock balances, Helius key)
   │                    ├──▶ Jupiter Price API (prices)
   │                    ├──▶ Jupiter quote/swap (platformFeeBps + feeAccount added server-side)
   │                    └──▶ Memo tx for trophies (server keypair)
   └── MWA: signAndSendTransactions on the swap tx NestJS returns
```

- **Swaps:** the app sends `{wallet, outputMint, usdcAmount}`. NestJS calls Jupiter `/quote` with
  `platformFeeBps` and `/swap` with `feeAccount`, then returns the base64 unsigned transaction plus quote
  details. The app signs and sends it via MWA, then calls `POST /roster/slots` once it's confirmed. Fee
  config never reaches the client.
- **Balances:** the app reads balances only to label stocks Held or Buy in the picker. Scoring always
  reads chain from the backend.
- **Demo control:** `POST /admin/tick` and `POST /admin/duels/:id/settle`, guarded by an
  `ADMIN_KEY` header. The app shows the buttons only in debug builds.

### 2.1 App structure

```
HomePage (CrystalNavigationBar, IndexedStack)
├── [sports_soccer]      SportPage(football)
├── [sports_basketball]  SportPage(basketball)
└── [sports_football]    SportPage(americanFootball)

SportPage(mode)
├── AppBar: title = sport name
│   actions: [Reports] [Notifications] [Profile avatar]   ← pushed routes
├── TabBar: League | Team
│   ├── League tab: global Classic leaderboard for this mode
│   │               current user's row highlighted inline + pinned rank banner
│   │               tap a row → challenge that player to a duel
│   └── Team tab:   no roster → "Draft your team" → draft board
│                   roster → ScoreHeader, board/slot cards, next-tick countdown,
│                   "My duels" section (active / pending invites / past)
└── FAB "Create league" → toast/snackbar: "Private leagues are coming soon"
```

- **App bar actions** reuse the existing pattern from
  [agent_tab_page.dart](../app/lib/features/agent/ui/pages/agent_tab_page.dart): `analytics_outlined`
  → `ReportsRoute`, `notifications_outlined` → `NotificationsRoute`, plus a new profile avatar (or
  `person_outline`) → `ProfileRoute`. Build it once as `FormationAppBar` and use it on all three pages.
- **Duels live inside the Team tab** of the sport they're played in (a duel is always for one mode).
  Challenges start from a League row or a "Challenge a friend" button in the "My duels" section. Duel
  detail and create-duel are pushed routes.
- **Tab state:** the nav bar's `IndexedStack` keeps each sport page alive, and each `SportPage` owns
  its own `TabController`, so switching sports doesn't reset the selected tab.

---

## 3. Codebase triage

### Flutter — keep as-is

| Path | Why |
|---|---|
| [core/theme/theme.dart](../app/lib/core/theme/theme.dart) | Dark palette + `AppTextStyles.mono` suits a finance/sports app. |
| [core/widgets/](../app/lib/core/widgets/) | `EmptyState`, `LoadingIndicator`, `RoundedTextField` reused verbatim. |
| [core/extensions/](../app/lib/core/extensions/) | Toast, iterable, widget helpers. |
| [features/wallet/](../app/lib/features/wallet/) | MWA connect + balances. Extended, not rewritten (§5, Day 1). |

### Flutter — adapt

| Path | Change |
|---|---|
| [home_page.dart](../app/lib/features/home/ui/pages/home_page.dart) | Same `CrystalNavigationBar`, still 3 items: `sports_soccer`, `sports_basketball`, `sports_football` → `SportPage(mode)`. |
| [agent_tab_page.dart](../app/lib/features/agent/ui/pages/agent_tab_page.dart) | Lift its app bar actions (Reports, Notifications) and FAB pattern into `FormationAppBar` + the create-league FAB, then delete the page. |
| [features/profile/](../app/lib/features/profile/) | No longer a nav tab: `ProfileTabPage` → `@RoutePage() ProfilePage`, pushed from the app bar. Replace Credits with trophy case + W/L record across all sports. |
| [features/reports/](../app/lib/features/reports/) | Keep: it's already a "coming soon" page. Retarget copy to portfolio analytics (sector exposure, risk breakdown), matching the spec's premium tier. |
| [features/notifications/](../app/lib/features/notifications/), [features/onboarding/](../app/lib/features/onboarding/) | Copy only. Polling for duel invites is enough; no push. |
| [stat_pill.dart](../app/lib/features/strategy/ui/widgets/stat_pill.dart) | Move to `core/widgets/`, add a `color` param (scores go negative). |
| [wallet_cubit.dart](../app/lib/features/wallet/ui/cubits/wallet_cubit.dart) | Rename identity to Formation; add `signMessage`, `signAndSendTransaction`, and `getTokenBalances(List<String> mints)` (generalize the USDC block, drop SKR). |

### Flutter — delete

`features/agent/` (after lifting the app bar), `features/strategy/` (after rescuing `stat_pill`),
`features/credits/`, `domain/entity/chat_message.dart`, the `flame` dependency, and the
`assets/sprites/` entries in `pubspec.yaml`.

### Flutter — new feature layout

```
features/sport/     SportPage(mode), FormationAppBar, CreateLeagueFab
features/league/    LeagueTab, LeaderboardRow, MyRankBanner, LeagueCubit
features/team/      TeamTab, ScoreHeader, RosterSlotCard, LiveTickIndicator, TeamCubit
features/draft/     DraftBoardPage, FormationBoard, PositionSlotChip, StockPickerSheet, BuyStockSheet, DraftCubit
features/duel/      MyDuelsSection, DuelCard, CreateDuelPage, DuelDetailPage, HeadToHeadBar, DurationPicker, TrophyAwardDialog, DuelCubit
features/shared/    domain models (§4), ApiClient, FixtureRepository
```

Cubits take `SportMode` in their constructor, so each `SportPage` gets its own instances.

### Backend — new modules

```
backend/src/
  config/        env: SUPABASE_URL, SUPABASE_SERVICE_KEY, RPC_URL, JUPITER_FEE_ACCOUNT,
                 PLATFORM_FEE_BPS, TROPHY_KEYPAIR, ADMIN_KEY
  db/            supabase client provider
  auth/          POST /auth/nonce, POST /auth/verify → bearer token
  xstocks/       GET /xstocks (mint list + tier + live price)
  chain/         balance reads (getTokenAccountsByOwner), price reads (Jupiter Price API)
  roster/        GET /roster/:mode, POST /roster/slots
  scoring/       pure scoreWindow() + hourly cron + POST /admin/tick
  league/        GET /league/:mode
  duel/          POST /duels, POST /duels/:id/accept|decline, GET /duels, settle cron (every minute)
  swap/          POST /swap/quote, POST /swap/build
  trophy/        award + memo tx
```

Dependencies: `@nestjs/schedule`, `@nestjs/config`, `@supabase/supabase-js`, `@solana/web3.js`,
`tweetnacl`, `bs58`.

---

## 4. Shared domain

Written once as Dart models (`features/shared/domain/`) and mirrored as TypeScript types. JSON field
names are the contract between the two.

```dart
enum SportMode { basketball, football, americanFootball }
enum RiskTier { blueChip, stable, balanced, growth, momentum }

class XStock { String symbol; String companyName; String mint; RiskTier tier;
               double priceUsd; double change24hPct; String? logoUrl; }

class PositionSlot { String label; RiskTier? requiredTier; /* null = FLEX */
                     Offset boardPosition; /* 0..1, client-only */ }

class RosterSlot { PositionSlot position; XStock? stock; double balance; }

class Roster { SportMode mode; List<RosterSlot> slots; double totalValueUsd;
               double lastReturnPct; int classicPoints; int? classicRank; }

class LeaderboardEntry { int rank; String userId; String username; String walletAddress;
                         int points; int streak; bool isCurrentUser; }

enum DuelStatus { pending, active, settled, declined }

class Duel { String id; LeaderboardEntry challenger; LeaderboardEntry opponent;
             SportMode mode; Duration duration; DuelStatus status;
             DateTime? startTime; DateTime? endTime;
             double? challengerReturnPct; double? opponentReturnPct; String? winnerId; }

class Trophy { String id; String title; DateTime awardedAt; String? txSignature; }
```

### Roster shapes

| Mode | Slots | Layout |
|---|---|---|
| Basketball | 5: PG, SG, SF, PF, C | Half-court |
| Football | FPL squad of 15: 2 GK, 5 DEF, 5 MID, 3 FWD. Starting XI in any FPL formation (3-4-3 … 5-4-1), captain ×2, vice, ordered bench with like-for-like auto-subs | Vertical pitch + bench strip |
| American Football | 9: QB, 2×RB, 3×WR, TE, FLEX, K | Field, offensive formation (stretch; Team tab shows "coming soon" until ready) |

Tier mapping: GK/C = `blueChip`; DEF = `stable`; MID/SF/PF = `balanced`; PG/SG = `growth`;
FWD = `momentum`; FLEX = any.

### Scoring (spec §3.5)

One pure function in `scoring/score-window.ts`, shared by the hourly tick and duel settlement, with
unit tests:

```
for each filled slot:
  counted = min(startBalance, endBalance)
  if counted > 0: slotReturn = (endPrice - startPrice) / startPrice
rosterReturn = average(slotReturn over counted slots)
points = round(rosterReturn * 10_000)
```

Tests to cover: price up/down, balance sold to zero (slot excluded), balance increased (no extra
credit), empty roster (0), and 5 vs 11 slots giving the same magnitude for the same return.

---

## 5. Schedule

Each block ends with the app building. **Bold** items are the demo's critical path; the rest can slip.

### Day 1 — Core loop working

**Morning (≈4h)**

| Flutter | Backend |
|---|---|
| **Strip + reshell:** deletes from §3; nav bar → 3 sport items; `SportPage` with `FormationAppBar` (Reports, Notifications, Profile), League/Team `TabBar` stubs, and the "Coming soon" create-league FAB; Profile becomes a pushed route; regenerate routes (`dart run build_runner build --delete-conflicting-outputs`) | **Nest modules scaffold, config, Supabase client** |
| **Domain models (§4)** + `ApiClient` (http + bearer token) | **Supabase schema** from spec §4.2 (+ `nonces`, `is_seed` on `users`) |
| | **xStock mint list:** verify real mints against Jupiter's token list, assign tiers by hand, seed `xstocks` table |

**Afternoon (≈4h)**

| Flutter | Backend |
|---|---|
| **Team tab empty state** → "Draft your team" → draft board for that page's mode (Basketball first) | **`chain/` balance + price reads** |
| **`FormationBoard`** (`CustomPaint` court + `Align` slots), `PositionSlotChip` | **`GET /xstocks`, `GET /roster/:mode`, `POST /roster/slots`** (slot fill validates tier + real balance > 0) |
| **Stock picker sheet** (tier-filtered, Held/Buy from wallet balances) | Auth nonce + verify |
| `DraftCubit`; wallet `signMessage` login | |

**Evening (≈3h)**

| Flutter | Backend |
|---|---|
| **Buy sheet:** quote, est. shares, price impact, **platform fee line**; confirm → MWA sign & send → poll confirmation → fill slot | **`POST /swap/quote`, `POST /swap/build`** with fee params |

**Day 1 gate:** a real ~$1 USDC → xStock mainnet swap from the draft screen fills a slot, and the fee
lands in the fee account. If Jupiter has no route for xStocks, switch to the fallback now: the buy
sheet shows a live quote, and slots fill only from existing holdings.

### Day 2 — Scoring, league, duels, demo

**Morning (≈4h)**

| Flutter | Backend |
|---|---|
| **Team tab (drafted):** `ScoreHeader` (mono points, green/red, `flutter_animate` counter), `RosterSlotCard`, `LiveTickIndicator` ("next tick in 42:13") | **`scoreWindow()` + tests** |
| **League tab:** top-3 treatment, current-user row highlighted inline + pinned rank banner (for the page's mode; no mode switcher needed) | **Hourly cron + `POST /admin/tick`:** snapshot → score → `classic_scores` → new baseline |
| | **`GET /league/:mode`**; seed ~30 `is_seed` users with scores |

**Afternoon (≈4h)**

| Flutter | Backend |
|---|---|
| **"My duels" section in the Team tab:** active / pending / past; prominent accept/decline | **`POST /duels`, accept/decline, `GET /duels?mode=`**; accept writes start snapshots for both players |
| **Create duel:** from a League row tap or "Challenge a friend"; opponent by wallet or username, duration presets 1h/6h/24h/3d/7d, share link (`share_plus`) | **Settle cron (every minute) + `POST /admin/duels/:id/settle`**: end snapshots → `scoreWindow()` → winner |
| **Duel detail:** `HeadToHeadBar`, countdown, debug "settle now", trophy dialog | **Trophy award:** DB row + memo tx, signature stored |

**Evening (≈3h)**

- Profile page (pushed from the app bar): record summary (W/L, streak, best rank per sport), trophy
  case with explorer links; wallet section unchanged. Reports page copy retargeted.
- Onboarding copy, app name/identity, icon if time allows.
- **Full run of the spec §7 demo script on two wallets/devices, twice.**
- **Record the demo video.** Update the root README for Formation.

### Buffer — Friday morning until 4 PM ET

Bugs and re-recording only. Stretch goals, in order and only if the demo is already recorded:
Football board → American Football board → Metaplex NFT trophy → landing page reskin.

---

## 6. Parallel split (if two people)

Flutter and backend columns above are independent after the Day 1 morning. Agree the JSON shapes in §4
first, and the Flutter side keeps a `FixtureRepository` implementing the same interface so it isn't
blocked on endpoints. Solo: work down the critical path top to bottom, backend item first in each block.

---

## 7. Risks

| Risk | Mitigation |
|---|---|
| Jupiter routes/liquidity for xStocks | Test a real swap on Day 1 evening; fallback defined above. |
| Public RPC rate limits during tick | Free Helius key; batch reads per wallet with `getTokenAccountsByOwner` (all tokens, filter by mint). |
| 11-slot board overflow at 360dp | Football is a stretch goal; check at 360dp before shipping it. |
| Real funds during testing | Keep test wallets to a few dollars of USDC. |
| MWA session flakiness on sign & send | Reuse the existing `LocalAssociationScenario` pattern; always close the session in `finally`. |
| Empty leaderboard / no opponent at demo | Seed users; second wallet pre-funded and pre-drafted. |

---

## 8. Explicitly out

Private leagues, matchmaking, seasons, roster locking, escrow/pooled funds, duel negotiation (all per
spec §6), plus for this build: league creation (FAB shows "Coming soon"), reports content (page stays
"coming soon"), subscriptions, push notifications, and any fake-moving price data.
