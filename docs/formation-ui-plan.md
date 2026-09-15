# Formation — Phased UI Implementation Plan

> Pivoting the Symbians Flutter app to the Formation UX (fantasy sports for real tokenized stocks).
> Product spec: [formation-stocklana-spec.md](../potential_pivot/formation-stocklana-spec.md)
>
> **Scope of this plan:** the Flutter UI only, built entirely on **static/dummy data**. No backend
> calls, no Solana reads, no Jupiter swaps. Every screen renders from in-memory fixtures so the whole
> flow is clickable and demoable before a single endpoint exists. Backend wiring is Phase 8+, out of
> scope here.

---

## 1. Why static-data-first

The app already has a working shell — theme, navigation, wallet connect, routing, code generation.
What it does not have is any Formation screen. Building those screens against fixtures first means:

- The full demo flow is clickable in days, not weeks, and can be shown while the backend is half-built.
- Every widget is built against a typed model, so swapping `FixtureRepository` for a real one later is
  a one-line change per cubit, not a rewrite.
- The NestJS backend in [backend/](../backend/) can be developed in parallel against the same models.

The existing pages already follow exactly this pattern — [strategy_marketplace_page.dart](../app/lib/features/strategy/ui/pages/strategy_marketplace_page.dart)
hardcodes its cards inline. The plan keeps the convention but moves fixtures into a dedicated layer
so they are swappable rather than inlined in `build()`.

---

## 2. What survives the pivot

Taking stock before deleting anything.

### Keep as-is

| Path | Why |
|---|---|
| [core/theme/theme.dart](../app/lib/core/theme/theme.dart) | Dark palette + `AppTextStyles.mono` is exactly right for a finance/sports app. No changes. |
| [core/widgets/](../app/lib/core/widgets/) | `EmptyState`, `LoadingIndicator`, `RoundedTextField` all reusable verbatim. |
| [core/extensions/](../app/lib/core/extensions/) | Toast helpers, iterable helpers, widget helpers. |
| [features/wallet/](../app/lib/features/wallet/) | `WalletCubit` (MWA connect + balances), `ConnectWalletView`, `ConnectedWalletView`. The draft flow needs exactly this. |
| [features/notifications/](../app/lib/features/notifications/) | Retarget copy to duel invites + settlement results; widgets unchanged. |
| [features/onboarding/](../app/lib/features/onboarding/) | Retarget copy only. |

### Keep, adapt lightly

| Path | Change |
|---|---|
| [features/home/ui/pages/home_page.dart](../app/lib/features/home/ui/pages/home_page.dart) | Same `CrystalNavigationBar` shell, 3 tabs → 4 (Roster, League, Duels, Profile). |
| [features/profile/](../app/lib/features/profile/) | Keep `ProfileCard`, `SectionHeader`, `ActionTile`, `TokenBalance`. Replace the Credits section with a trophy case + W/L record. |
| [features/strategy/ui/widgets/stat_pill.dart](../app/lib/features/strategy/ui/widgets/stat_pill.dart) | Promote to `core/widgets/stat_pill.dart`. Add a `color` parameter — it currently hardcodes `AppColors.success`, but scores go negative. |

### Delete

`features/agent/`, `features/strategy/` (after rescuing `stat_pill`), `features/credits/`,
`features/reports/`, `domain/entity/chat_message.dart`.

`agent_card.dart` and `strategy_card.dart` are worth reading once for card layout before deleting —
`RosterSlotCard` and `DuelCard` are the same shape.

---

## 3. Domain model (built in Phase 1, used by everything after)

```dart
enum SportMode { basketball, football, americanFootball }

enum RiskTier { blueChip, stable, balanced, growth, momentum }

class XStock {                 // one of the 41 tokenized equities
  String symbol;               // 'TSLAx'
  String companyName;          // 'Tesla, Inc.'
  String mint;                 // Solana mint address
  RiskTier tier;
  double priceUsd;
  double change24hPct;
  String? logoAsset;
}

class PositionSlot {           // a slot shape, per sport
  String label;                // 'GK', 'PG', 'QB', 'FLEX'
  RiskTier requiredTier;       // constrains which stocks are eligible
  Offset boardPosition;        // 0..1 normalized, for pitch/court layout
}

class RosterSlot {             // a filled (or empty) slot
  PositionSlot position;
  XStock? stock;               // null = empty
  double balance;              // token amount held
  double entryPriceUsd;
}

class Roster {
  SportMode mode;
  List<RosterSlot> slots;
  double totalValueUsd;
  double returnPct;            // window return
  int points;                  // returnPct * 10000, 1bp = 1pt
}

class LeaderboardEntry {
  int rank;
  String username;
  String walletAddress;
  int points;
  int streak;
  bool isCurrentUser;
}

enum DuelStatus { pending, active, settled, declined }

class Duel {
  String id;
  LeaderboardEntry challenger;
  LeaderboardEntry opponent;
  SportMode mode;
  Duration duration;           // 1h / 6h / 24h / 3d / 7d
  DuelStatus status;
  DateTime startTime;
  DateTime endTime;
  double? challengerReturnPct;
  double? opponentReturnPct;
  String? winnerId;
}

class Trophy {
  String id;
  String title;
  DateTime awardedAt;
  String? mintAddress;
}
```

### Roster shapes

| Mode | Slots | Layout |
|---|---|---|
| Basketball | 5 — PG, SG, SF, PF, C | Half-court |
| Football | 11 — GK, ×4 DEF, ×3 MID, ×3 FWD (4-3-3) | Full pitch, vertical |
| American Football | 9 — QB, ×2 RB, ×3 WR, TE, FLEX, K | Field, offensive formation |

Tier mapping per the spec: GK/C = `blueChip`; DEF = `stable`; MID/SF/PF = `balanced`;
PG/SG = `growth`; FWD = `momentum`. FLEX accepts any tier.

> **Decision to confirm:** the spec says American Football is "largest, most positions" without
> fixing a roster. 9 slots above is a proposal — it keeps the field readable on a phone. Football's
> 11 is already the widest shape the board layout has to survive.

---

## 4. Phases

Each phase ends with the app building and running. Ship order is deliberate: the demo script in
§7 of the spec is walkable end-to-end from Phase 5 onward.

---

### Phase 0 — Strip and re-shell

Clear the old product out and stand up empty Formation tabs.

**Delete:** `features/agent/`, `features/strategy/`, `features/credits/`, `features/reports/`,
`domain/entity/chat_message.dart`.

**Create:**
```
core/widgets/stat_pill.dart          (moved from strategy/, + color param)
features/roster/ui/pages/roster_tab_page.dart      stub
features/league/ui/pages/league_tab_page.dart      stub
features/duel/ui/pages/duel_tab_page.dart          stub
```

**Edit:** `home_page.dart` → 4 tabs with icons `sports_soccer`, `leaderboard`, `sports_mma`,
`person`. `app_route.dart` → drop agent/strategy/report routes, then regenerate:
`dart run build_runner build --delete-conflicting-outputs`.

**Done when:** `flutter build apk --release` succeeds, app launches to four tabs, three of them
empty-state placeholders.

---

### Phase 1 — Fixtures and models

Pure Dart, no widgets. Everything above §3 becomes real code plus the data to fill it.

**Create:**
```
features/shared/domain/            all models from §3
features/shared/data/fixtures/
  xstock_fixtures.dart             ~41 entries, realistic prices + tiers
  roster_fixtures.dart             one filled roster per sport mode
  leaderboard_fixtures.dart        ~50 ranked entries, user seeded at ~#12
  duel_fixtures.dart               2 active, 1 pending invite, 3 settled
  trophy_fixtures.dart             3 trophies
features/shared/data/fixture_repository.dart
```

`FixtureRepository` mirrors the method signatures the real repository will have
(`Future<Roster> getRoster(SportMode)`, `Future<List<Duel>> getDuels()`, …) and returns fixtures
behind a short `Future.delayed` so loading states are exercised for real.

Mint addresses can be placeholder strings this phase — nothing reads chain yet.

**Done when:** `flutter test` passes a fixture sanity test (every roster is fully filled, every
slot's stock tier matches its position's required tier).

---

### Phase 2 — Draft flow

The signature screen. Most of the product's character lives here.

```
features/draft/ui/pages/sport_select_page.dart     3 mode cards, roster size + character
features/draft/ui/pages/draft_board_page.dart      the pitch/court with tappable slots
features/draft/ui/widgets/formation_board.dart     CustomPaint pitch + positioned slots
features/draft/ui/widgets/position_slot_chip.dart  empty | filled state
features/draft/ui/widgets/stock_picker_sheet.dart  searchable, tier-filtered
features/draft/ui/widgets/buy_stock_sheet.dart     quote preview + confirm (static)
features/draft/ui/cubits/draft_cubit.dart
```

`FormationBoard` draws the surface with `CustomPaint` (pitch lines, court arc, yard lines by mode)
and lays slots out via `Align` on each `PositionSlot.boardPosition`. Normalized coordinates keep
all three sports on one widget.

The picker marks each stock **Held** (green, fills instantly) or **Buy** (routes to the buy sheet).
Roughly half the fixtures should be held so both paths are demoable.

`buy_stock_sheet` shows amount, estimated shares, price impact, and a **platform fee line** — the
revenue model is visible in the UI, which matters for judging. Confirm is a fake 1.5s delay.

**Done when:** a roster can be drafted from empty to full in every sport mode, both held and buy
paths, with state surviving tab switches.

---

### Phase 3 — Roster home

The tab you land on once drafted.

```
features/roster/ui/pages/roster_tab_page.dart      real implementation
features/roster/ui/widgets/score_header.dart       big points number + return % + rank
features/roster/ui/widgets/roster_slot_card.dart   per-slot row: symbol, tier, value, contribution
features/roster/ui/widgets/live_tick_indicator.dart  "next tick in 42:13"
features/roster/ui/cubits/roster_cubit.dart
```

`ScoreHeader` is the emotional core — large mono points figure, green/red, animated with
`flutter_animate`'s counter. A local `Timer.periodic` jitters fixture prices every few seconds so the
number visibly moves during a demo. Gate it behind `kDebugMode || kDemoMode` so it cannot ship as
fake live data.

Empty state (no roster yet) routes to Phase 2's sport select.

**Done when:** roster renders for all three modes, points tick visibly, per-slot contributions sum
to the header figure.

---

### Phase 4 — Classic leaderboard

```
features/league/ui/pages/league_tab_page.dart
features/league/ui/widgets/leaderboard_row.dart    rank, name, points, streak
features/league/ui/widgets/sport_mode_tabs.dart    segmented switcher
features/league/ui/widgets/my_rank_banner.dart     pinned to bottom
features/league/ui/cubits/league_cubit.dart
```

Top 3 get distinct treatment. The current user's row is highlighted inline **and** pinned in a
bottom banner so it is visible however far down they are.

**Done when:** switching sport mode swaps the board, user row highlighted in both places.

---

### Phase 5 — Duels

Completes the demo script.

```
features/duel/ui/pages/duel_tab_page.dart          active / pending / past sections
features/duel/ui/pages/create_duel_page.dart       opponent + duration presets
features/duel/ui/pages/duel_detail_page.dart       head-to-head
features/duel/ui/widgets/duel_card.dart
features/duel/ui/widgets/duration_picker.dart      1h / 6h / 24h / 3d / 7d
features/duel/ui/widgets/head_to_head_bar.dart     diverging bar, both returns
features/duel/ui/widgets/duel_countdown.dart
features/duel/ui/widgets/trophy_award_dialog.dart  confetti moment
features/duel/ui/cubits/duel_cubit.dart
```

`HeadToHeadBar` is a single diverging bar from a shared centre — instantly readable who is ahead.
Pending invites need prominent accept/decline. `create_duel_page` accepts a wallet address or
username and offers a share link (`share_plus` is already a dependency).

Include a debug-only "settle now" affordance on an active duel so the win moment can be shown
without waiting an hour.

**Done when:** an invite can be created, accepted from the pending list, opened, force-settled, and
the trophy dialog fires.

---

### Phase 6 — Profile and trophy case

```
features/profile/ui/pages/profile_tab_page.dart    edit: drop credits section
features/profile/ui/widgets/trophy_case.dart       grid of earned trophies
features/profile/ui/widgets/record_summary.dart    W/L, streak, best rank
```

Keep the wallet + balances sections exactly as they are. Trophies show mint address and link out to
an explorer — reinforces the on-chain story.

**Done when:** profile shows record, trophy case, and connected wallet with no credits UI left.

---

### Phase 7 — Polish

Motion with `flutter_animate` (staggered list entries, score counter, trophy confetti). Every list
gets real empty, loading and error states via the existing `EmptyState` / `LoadingIndicator`.
Onboarding copy rewritten for Formation. App icon and splash updated. Pass over every screen at
360dp width — `FormationBoard` with 11 slots is the one at real risk of overflow.

**Done when:** no overflow warnings at 360dp, every list has all three states, release APK builds.

---

## 5. Sequencing notes

- **Phases 0 and 1 must land first** and are the cheapest. Everything after depends on the models.
- **Phases 3, 4, 5 are independent** of each other once Phase 1 is in. If splitting work, that is
  the split.
- **Phase 2 is the long pole** — `FormationBoard` is the only genuinely novel widget. Start it
  early, and build Basketball (5 slots, simplest) before Football.
- **Phase 7 can be partially skipped** under deadline pressure. Phases 0–5 are the demo.

---

## 6. Out of scope here

Backend wiring, SIWS auth against the NestJS backend, real Solana balance reads, real Jupiter
quotes and swaps, the hourly scoring tick, and trophy minting. All of those replace
`FixtureRepository` implementations behind the interfaces defined in Phase 1 — no widget built in
Phases 2–7 should need to change.
