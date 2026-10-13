# Scoring and match experience: implementation plan

**Goal:** scoring that's tight, fair and ready for more asset types, wrapped in a weekly sports rhythm
that makes picking a balanced team that beats the market fun to follow.

**Phases:**

| Phase | What | Depends on |
|---|---|---|
| 0 | Immediate data fixes | — (done or ready) |
| 1 | Scoring integrity | — |
| 2 | Seasons and match weeks | 1 |
| 3 | Live events and skill visible | 1, 2 |
| 4 | Push notifications (FCM) | 3 for the best pushes; can start any time |
| 5 | Portfolio-building layer | 1 |

Each phase ships and is deployed on its own.

---

## Why (incident, 2026-10-12)

A football team showed -461.9, which had become -519.4 by the time the fix was applied. Read-only queries
on the production ledger found:

1. **A broken price fed the score.** JNJx is priced by a thin pool on Jupiter. Its price sat frozen for
   hours, then stepped down, from $428.67 to $251.36 in four steps, and never recovered. Johnson & Johnson
   shares did nothing of the sort. At 1 point per 0.1% of alpha, JNJx cost 496.7 points on a holding
   worth about $1.20.
2. **A bug in daily events.** `reSnapshot` only refreshes the session's opening lineup when a tick lands
   *exactly* on the session boundary (`sessionStart(now) === now`). Ticks land at :03 past the hour, so
   this never happens. Daily events were measured from the first price ever recorded: JNJx "conceded"
   for -14.9%, -29.5% and -39.9% on consecutive days.
3. **No defences.** Any price was trusted, with no check that an asset is priced reliably, no
   plausibility check, and no limits.

## Principles

- **Show everything, score what's reliable.** Every listed asset stays visible, draftable and tradable.
  Whether it *scores* is decided objectively from the data, on every tick.
- **Scoring rules are asset-agnostic.** The engine scores a price series against a benchmark. A new
  tokenized asset is onboarded by listing it with an asset class. It scores once its price meets the same
  requirements as everything else, with no code change.
- **No new paid data.** Jupiter stays the price source. Pyth's paid tier is out of reach, and its free
  on-chain equity accounts on Solana are weeks stale.
- **Skill, not luck, over time.** The weekly rhythm and visible skill stats reward consistency and
  balance.
- **Talk about beating the market, never "profit".** It's a game of skill, not investment advice.

---

## Phase 0: immediate data fixes

### 0.1 Score correction: applied 2026-10-12

anton / football: **-519.4 → +14.3**, in one transaction, verified so that the ledger sum equals
`classic_scores`.
- **Alpha +496.7:** JNJx's contribution removed on all 78 ticks it was held (Oct 9 06:03 to Oct 12 12:03
  UTC), treating it as not scoring. DFDVx's real moves are left as banked.
- **Events +37:** the three daily rollups recomputed with true per-day returns and JNJx zeroed:
  -7 → 0, -10 → +7, -6 → +7.
- **How it's recorded:** two compensating ledger rows with the existing `alpha` and `events` kinds.
  Their `detail.correction = 'jnjx-2026-10-12'` holds the reason and the before/after values. History
  wasn't edited.

**Still open until Phase 1 deploys:** the live backend runs the old code. JNJx stays in that lineup and
keeps stepping, and the daily events still use stale opening prices, so the score will drift again.
Swap JNJx out, or deploy Phase 1 quickly. A follow-up correction for the period since the fix can reuse
the same script.

### 0.2 Seed players: real xStocks holders (query ready, not run)

`backend/scripts/seed-xstock-holders.sql` points the four existing seed players at real wallets and adds
three more, seven in total.
- **How the wallets were chosen:** found on-chain on 2026-10-12, keeping only ordinary wallets holding
  6–24 different xStocks and leaving out pools, programs and institutional wallets.
- **What changes:** seed manager profiles show real xStocks portfolios.
- **What stays demo data:** the names and season points. Seeds stay excluded from scoring.
- **Decide before running:** these wallets haven't joined Formation. Profiles should carry a small "demo
  player" label, so real holdings aren't presented as someone's actual game choices.

---

## Phase 1: scoring integrity

### 1.1 Daily events fix

A session opens on the first bank whose `sessionStart(now)` is later than the `sessionStart` of the
previous bank. That's when `session_snapshot` is refreshed. Tests cover ticks at :03 past the hour
crossing midnight.

### 1.2 Scoring eligibility: the requirements an asset must meet to score

On every tick, each asset gets a status, `eligible` or `not_scoring` with a reason, computed over a
trailing 24 hours:

| Requirement | Default |
|---|---|
| A current price | a tick within the last 2 |
| Continuously priced | its price changed on ≥ 50% of ticks while the benchmark moved |
| Pool depth | ≥ $1,000 (`SCORING_MIN_LIQUIDITY_USD`); this only affects scoring, not listing |
| No repeated implausible jumps | ≤ 1 rejected jump (§1.3) in 24 hours |

- **Hysteresis:** an asset turns `not_scoring` as soon as any requirement fails. It turns `eligible`
  again only after 24 hours of passing.
- **Effect on a team:** a pick that isn't scoring banks 0 and shows a **"Not scoring: <reason>"** badge
  everywhere it appears. The Manager can keep it, bench it or swap it.

### 1.3 Per-tick guards

1. **Hold unconfirmed jumps.** A move of more than `MAX_TICK_MOVE` (10%) relative to the benchmark banks
   nothing, and the baseline stays where it was.
   - If the price reverts on the next tick, nothing is ever banked.
   - If it stays, the move is banked clamped to 10%, and a rejected jump is recorded.
2. **Clamp:** any one tick is at most ±100 base points per pick.
3. **Daily caps:**
   - base points: ±150 per pick per session
   - role events: ±60 per pick per session (today they're uncapped: a +30% day pays 10 goals)

### 1.4 Asset classes, for onboarding new assets

- **Data:** `xstocks.asset_class` (default `us_equity`) and `xstocks.liquidity_usd`. The catalogue
  already fetches liquidity and now stores it.
- **Benchmarks:** `domain/assets.ts` maps each class to its benchmark, e.g. `us_equity → SPYx`,
  `commodity → GLDx`. Alpha is measured against the class benchmark.
- **To onboard a new asset type:**
  1. Add a catalogue source.
  2. Map its class and benchmark.
  3. Eligibility decides when it starts scoring.

### 1.5 Data model (migration `015_scoring_quality.sql`)

- `xstocks`: `asset_class` and `liquidity_usd`.
- `asset_scoring_status (mint pk, eligible, reason, since, checked_at, metrics jsonb)`.
- `scoring_anomalies (id, mint, at, kind, detail)`, recording held jumps, clamps and status changes.
- `points_ledger.kind`: add `'correction'`, so future corrections are labelled as such.

### 1.6 Display

- The "Not scoring" badge in the lineup, the picker and Assistant Manager cards.
- The Assistant Manager's context includes each pick's scoring status.
- Copy: "24/7 scoring" becomes "scores whenever its price is reliable".

**Phase 1 tests:**
- JNJx's real price series, replayed, scores 0.
- A reverting spike banks nothing.
- A persistent 15% step banks a clamped 10%.
- The caps hold.
- Hysteresis works.
- A non-equity asset is measured against its own benchmark.
- Events with :03 ticks across midnight.

---

## Phase 2: seasons and match weeks

### 2.1 Seasons: 12 weeks

- Four seasons a year, roughly one per earnings season, so latecomers can compete and there's a finale
  every quarter.
- `seasons (id, number, starts_at, ends_at)`. `classic_scores` becomes per-season (add `season_id`), and
  `points_ledger` rows carry their season.
- **Season end:**
  - final standings are frozen into `season_results`
  - badges are awarded ("Season 3 champion", top 10%)
  - points reset to zero
- **Carried across seasons:** skill rating, career alpha, badges, and the season history on the profile.

### 2.2 Match weeks: Monday open to Friday close

- **Kick-off:** Monday 9:30am ET. **Full time:** Friday 4pm ET. Ticks and banking keep running all
  week. A match week is a window over the ledger, not a separate engine.
- **Weekend transfer window:** from Friday full time to Monday kick-off, substitutions are **free and
  unlimited**. During the week, the existing 3 free substitutions a day apply, with a 4-point cost
  beyond that.
- **Private leagues become fixtures:**
  - head-to-head pairings each match week (round-robin), with 3 points for a win and 1 for a draw
  - a league table with W/D/L and form dots
  - duels stay as single fixtures
  - this reuses the existing league open/settle code
- **Result card at full time:** the scoreline, man of the match, a goals timeline and the turning point.
  It's shareable through the manager and league link previews.

### 2.3 Global leaderboard

| Board | Ranks | Resets |
|---|---|---|
| **This week** | Points banked this match week | Every Monday |
| **Season** | Points this season | Every 12 weeks |
| **Skill** | Skill rating (§3.2) | Never (all-time, with a minimum number of weeks) |

The global board stays scored by points. Head-to-head fixtures only exist in private leagues.

---

## Phase 3: live events and skill visible

### 3.1 Live events

- **Each tick:** compare every pick's return since the day's open with the event thresholds, and record
  **provisional** events in `live_events (user, sport, slot, code, points, status, at)`.
- **The daily rollup** confirms them or marks them **"Disallowed"** if the price fell back. The ledger
  only records confirmed events, so the leaderboards never count provisional points.
- **App:**
  - a provisional icon on the pick, with a dotted outline
  - a goal card with the character celebrating
  - the live fixture scoreline on the team screen
  - a goals timeline
- **Eligibility:** only eligible assets fire events. Thanks to Phase 1, a broken price can't score a goal.

### 3.2 Skill visible

- **Skill rating:** risk-adjusted alpha, meaning mean weekly alpha ÷ its volatility, scaled to 0–100 and
  shrunk toward the average until about 6 weeks of history exist. It rewards steady market-beating over
  one lucky spike.
- **Stats on profiles and boards:**
  - **Alpha:** "beats the market by +2.1% a week on average"
  - **Hit rate:** "% of picks that beat the S&P 500"
  - **Form:** the last 5 fixtures
  - **Shrewd captain:** % of weeks the captain outscored the team average
- **Badges:** Golden Boot, Clean-sheet king, Shrewd captain, and season finishes.
- **Data:** a `weekly_stats` table worked out at full time from the ledger and price ticks. No new data
  sources are needed.

---

## Phase 4: push notifications (FCM)

Every in-app notification already goes through `NotificationsService.push()` / `pushMany()`. FCM is
added there, so everything that notifies today also pushes. FCM itself is free.

- **App:** `firebase_messaging`, a permission prompt, and the device token registered with the backend.
  Web push needs a service worker (`firebase-messaging-sw.js`) and a VAPID key.
- **Backend:**
  - `device_tokens (user_id, token, platform, created_at, last_seen_at)`
  - `firebase-admin` with a service account
  - dead tokens are pruned when FCM rejects them
- **Pushes:**
  - match week: kick-off, half-time (Wednesday) and full-time result
  - live goals, when Phase 3 is in
  - "Your captain isn't scoring: stale price"
  - transfer window open
  - season finale
- **Guardrails:**
  - per-type toggles in Settings
  - quiet hours, in the user's time zone
  - at most one goal push per pick per day
  - a daily push budget per user
- **Note:** Android needs no extra setup beyond `google-services.json` and the Firebase project, which
  already exists. iOS would need APNs keys later.

---

## Phase 5: portfolio-building layer

Build on the tier system (blue chip, stable, balanced, growth, momentum), which already makes every team
diversified by design.

- **Skill rating is risk-adjusted** (Phase 3). This makes the balance lesson explicit: steady beats
  lucky.
- **Team balance bonus (optional):** +5 a week for a team spanning 4 or more sectors. Sector tags are
  curated once in the catalogue, and new asset classes bring their own.
- **Weekly portfolio health card from the Assistant Manager:** tier balance, sector concentration, and
  who carried or dragged the team, framed as lessons ("Your defence held while tech fell: that's what
  defence is for").
- **Copy:** "beat the market, balance your team, stay consistent". Never "profitable".

---

## Defaults (all settings)

| Setting | Value |
|---|---|
| `MAX_TICK_MOVE` | 10% |
| Base cap per pick per day | ±150 |
| Event cap per pick per day | ±60 |
| `SCORING_MIN_LIQUIDITY_USD` | $1,000 |
| Continuously priced | ≥ 50% of ticks over 24 hours |
| Eligibility hysteresis | 24 hours |
| Season length | 12 weeks |
| Match week | Monday 9:30am ET to Friday 4pm ET |
| Transfer window | Friday 4pm ET to Monday 9:30am ET, free substitutions |
| Push limits | 1 goal push per pick per day, quiet hours on |
