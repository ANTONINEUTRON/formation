# Formation — Build Plan to Submission

**Deadline: 8 October 2026** (CLOCK IN, Solana Mobile Hackathon). Written 2 October 2026.
Audience: the build team.

Submission artifacts required: functional Android **APK**, **GitHub repo**, **demo video**, **pitch
deck**. Technical requirements: **Mobile Wallet Adapter** + **Solana Mobile Stack** integration,
demonstrably mobile-first. Winners must publish to the **Solana dApp Store** to claim prizes.
Separate **$10,000 SKR prize** for best SKR integration.

Pitch content lives in [pitch.md](pitch.md). Strategy rationale lives in
[FORMATION_STRATEGY.md](FORMATION_STRATEGY.md). This document is code only.

---

## 0. Decisions locked before any code

| Decision | Resolution | Why |
|---|---|---|
| Opponent in a match | **The market (SPYx)** | Always available, no matchmaking, and the match becomes a rendering of alpha |
| Match determinism | **Fully deterministic from price ticks** | Replayable, auditable, and never feels arbitrary. No model decides outcomes |
| Video mode | **Post-submission** | Latency and per-render cost can't be de-risked in six days; a janky render hurts UX scoring |
| SKR scope | **Render credits, mascot skins, private leagues** | Never on the scoring surface — a purchasable multiplier would contradict the alpha thesis |
| ORE | **Dropped for this submission** | No ORE track, sponsorship or bonus exists in CLOCK IN. Two tokens dilute the SKR claim and double the work |
| Substitution cost | **Stays in points** (`SUBSTITUTION_COST = 4`) | Already shipped and correct. Charging SKR would make a scoring penalty purchasable |
| Minimum to play | **One filled slot** | Removes the onboarding cliff, and short-handed matches motivate swaps |
| Custom Solana program | **None** | Balances from chain, prices and routing from Jupiter, user signs everything |

**One rule above all others:** buying and selling stay unlimited and free. Swap fees are the revenue
model, so no mechanic may ever make purchasing more expensive. Specifically — **a newly bought stock
filling an eligible or empty slot is a free fill, never a substitution.** Subs only cost when
rotating between two stocks already owned. Without this rule the true cost of a purchase becomes
"swap fee + sub cost," which taxes the one action that pays us.

---

## 1. Match engine

### 1.1 What already exists

The engine is half built, which is why this is a two-day feature rather than a rewrite.

- [`scoring/engine/rules/football.ts`](backend/src/scoring/engine/rules/football.ts) already emits
  named `ScoreEvent`s from a `SlotContext`: `goal` per 3% of own return (`GOAL_STEP = 0.03`, points
  by role GK 6 / DEF 6 / MID 5 / FWD 4), `assist` at ≥1% alpha, `clean_sheet`, `conceded` per −2%
  (`CONCEDED_STEP = 0.02`, GK and DEF only). Basketball and American football have parallel rule
  files.
- [`scoring/engine/metrics.ts`](backend/src/scoring/engine/metrics.ts) has `priceAt`,
  `changeBetween`, `sessionWindows`, `sessionReturns`, `lowestRelative`, `longestGreenRun`.
- [`scoring/engine/types.ts`](backend/src/scoring/engine/types.ts) has `LineupSnapshot`,
  `PriceBook`, `PriceTick`, `ScoreWindow`, `SlotExits`, `ScoreEvent`.
- [`scoring/engine/score-entry.ts`](backend/src/scoring/engine/score-entry.ts) aggregates it all,
  handles captaincy, exits and the substitution charge.

**The gap is exactly one thing: events have no timestamps.** The rules know *what* happened; the
tick history knows *when*. A match is those two joined.

### 1.2 New module layout

```
backend/src/match/
├── engine/
│   ├── types.ts            # MatchTimeline, MatchEvent, MatchSide, MatchResult
│   ├── crossings.ts        # tick at which a threshold was first crossed
│   ├── clock.ts            # window time → match minute
│   ├── opponent.ts         # the Market XI's goals from benchmark return
│   ├── build-match.ts      # orchestrator: ScoreInput → MatchTimeline
│   └── build-match.spec.ts
├── match.service.ts        # snapshot + tick loading, caching, persistence
└── match.controller.ts     # GET /match/:mode/latest, GET /match/:id, POST /match/preview
```

Keep `engine/` free of NestJS and database imports, matching the existing `scoring/engine`
convention — pure functions, directly unit-testable.

### 1.3 Core types

```ts
export interface MatchEvent {
  /** Match minute, 0-based. */
  minute: number;
  /** Epoch ms of the tick that caused it — kept for audit and replay. */
  at: number;
  side: 'home' | 'market';
  /** Reuses the scoring codes: goal | assist | clean_sheet | conceded | ... */
  code: string;
  label: string;
  /** Slot that produced it; null for market events. */
  slotIndex: number | null;
  symbol: string | null;
  role: string | null;
  points: number;
  /** The own-return or alpha value at the crossing, for the commentary line. */
  value: number;
}

export interface MatchSide {
  name: string;
  goals: number;
  /** Filled slots only. 1..11 for football. */
  playerCount: number;
  shortHanded: boolean;
}

export interface MatchTimeline {
  mode: SportMode;
  window: ScoreWindow;
  /** Match length in minutes: 90 football, 48 basketball, 60 american_football. */
  duration: number;
  home: MatchSide;
  market: MatchSide;
  events: MatchEvent[];
  /** Hash of (window, mints, tick ids) — same input must yield the same match. */
  fingerprint: string;
}
```

### 1.4 The three algorithms

**(a) Crossings — when did it happen?**

For each filled slot, walk its ticks once and record the first tick at or after which each
threshold multiple is crossed. A slot that ends at +7% own return produced goals at the first
crossing of 3% and of 6%, at those ticks' timestamps — not two goals at the window end.

```ts
/** First tick at which value crosses each multiple of [step], in order. */
export function crossings(
  ticks: PriceTick[], openingPrice: number, step: number, direction: 1 | -1,
): { multiple: number; at: number; value: number }[]
```

Monotonic high-water mark: track the furthest multiple reached so far and only emit on a new
maximum, so a stock oscillating around 3% scores one goal, not twelve. This is the single most
important correctness detail in the engine — write the test first.

Events that are inherently session-scoped (`clean_sheet`, and the session roll-ups in
`metrics.sessionReturns`) have no crossing moment. Place them at the final whistle.

**(b) Clock — window time → match minute**

```ts
export const minuteOf = (at: number, w: ScoreWindow, duration: number): number =>
  Math.min(duration, Math.max(0, Math.floor((at - w.start) / (w.end - w.start) * duration)));
```

Deterministic, no interpolation. Collisions are fine — two goals in the 54th minute is a normal
football event. Sort by `at`, then `slotIndex`, so ordering is stable.

**(c) The Market XI — the opponent**

The benchmark's own run produces the opposition's goals, using the same step so the two sides are
directly comparable:

```
marketGoals = floor( max(0, benchmarkReturn - homeMeanReturn) / GOAL_STEP )
```

Timed by running `crossings` over the benchmark ticks against the home side's running mean return.
The result is that **the scoreline is the alpha**: if you're beating SPYx you're winning, and the
final score is a number a user can read without understanding basis points.

The Market XI always fields 11. It does not go short-handed. That asymmetry is the point.

### 1.5 Partial squads — the required path

A user with **one** supported stock must get a playable match.

- **Eligibility:** `filledSlots >= 1`. No formation validity check for match generation (keep the
  existing validation for league entry only).
- **Short-handed display:** `home.playerCount = filledSlots`, `shortHanded = playerCount < shape
  length`. Render as "4 v 11" in the match header. This is a real football situation and reads as
  drama, not as an error state.
- **Scoring unaffected.** `score-entry.ts` already averages alpha across *filled* slots, so a short
  squad is neither penalised nor advantaged. Do not change this.
- **No auto-concede for missing slots.** The existing role guard in `football.ts` already restricts
  `conceded` to filled GK and DEF slots, so an empty defence simply produces no concede events.
  Verify with a test; do not "fix" it into a penalty.
- **Clean sheet** requires a filled GK. With no keeper it is unavailable rather than failed.
- **Empty-state copy** is a product surface, not a fallback: *"You're playing 1 v 11. Sign another
  player."* with a one-tap route into the draft. This is the acquisition loop — the match motivates
  the swap.

### 1.6 API

| Route | Purpose |
|---|---|
| `GET /match/:mode/latest` | The most recent completed session's match for the caller |
| `GET /match/:id` | A stored match by id, for sharing and replay |
| `POST /match/preview` | Match from an arbitrary window — powers the demo and the admin replay |

`POST /match/preview` with an explicit window is what makes the demo safe: a live feed outage during
judging can't break the showcase, because any historical window replays identically.

### 1.7 Tests to write first

- A threshold crossed and re-crossed yields one event, not many (high-water mark).
- A slot ending at +7% yields goals at the 3% and 6% crossing ticks, not at the whistle.
- One filled slot produces a valid timeline with `playerCount = 1, shortHanded = true`.
- Zero filled slots is rejected cleanly, not a crash.
- Empty defence produces no `conceded` events.
- `benchmarkReturn > homeMeanReturn` produces market goals; the reverse produces none.
- Same `ScoreInput` twice yields an identical `fingerprint` and identical event ordering.
- A sold pick keeps the events it earned before the exit (existing `exits` semantics).

---

## 2. Flutter match screen

New feature module `app/lib/features/match/`, following the existing `features/*` convention.

- **Pitch view.** Static 2D pitch, mascot chips at formation positions. Short-handed squads show
  empty positions as outlines with a "sign a player" affordance.
- **Timeline playback.** Replay `events` against the match clock — a scrub bar, a running
  scoreline, and an event feed that fills as the clock advances. The data is a finished timeline, so
  playback is pure UI with no live dependency. It works offline, which also makes the demo video
  bulletproof.
- **Commentary strings.** Template per event code off `label`, `symbol` and `value`:
  *"34' — TSLAx finishes it off. +3.1% and climbing."* Template strings, not generated text.
- **Mascots.** `assets/mascots/<SYMBOL>.png` plus a generic fallback, resolved by ticker. A static
  asset table, no model involved. Ship 10–15 recognisable names and fall back for the rest.
- **Share card.** Render the final scoreline to an image via `share_plus` (already a dependency).
  Free distribution, and the natural upsell surface for paid video renders later.

---

## 3. SKR integration

Targets the separate $10,000 prize. The design rule is that SKR buys compute and cosmetics, never
points.

- **Match highlight renders.** The honest anchor: video generation has real per-render cost, so
  charging for it is economics rather than a toll. Ship the *purchase and queue* path now with the
  2D share card as the delivered artifact; video lands post-submission behind the same transaction.
- **Mascot skins and kits.** Pure cosmetic, zero scoring effect.
- **Private leagues.** Create a league with a code, friends only.
- Reuse [`domain/pay-tokens.ts`](backend/src/domain/pay-tokens.ts), which already models USDC / SOL
  / SKR payment.
- New: `backend/src/entitlements/` — an append-only ledger of SKR spends and what each unlocked.
  Verify the transfer on chain by signature before granting; never trust a client claim.

**Do not** put SKR on substitutions or captaincy. Both affect points. A purchasable multiplier
makes capital legible instead of judgment, which contradicts the one mechanic nothing else in the
corpus has.

---

## 4. Admin dashboard

Judges should see fees earned on screen. It is the shortest proof of a working revenue model, and
it costs a day.

### 4.1 What exists

[`admin/admin.controller.ts`](backend/src/admin/admin.controller.ts) has `AdminGuard` and four
write-only demo controls: `POST /admin/catalogue/refresh`, `/admin/tick`, `/admin/leagues/process`,
`/admin/leagues/:id/settle`. There are no read endpoints and no UI.

### 4.2 Read endpoints to add

| Route | Contents |
|---|---|
| `GET /admin/overview` | Users, wallets connected, rosters by sport, DAU, matches generated |
| `GET /admin/revenue` | Swap count and notional volume, **fees earned** (total / 24h / 7d), fee per user, SKR spend by entitlement |
| `GET /admin/health` | Last tick time, **price feed staleness per mint**, last scoring run, last league settlement, failed jobs |
| `GET /admin/squads` | Distribution of filled-slot counts — how many users are short-handed, and at what size they stop. This is the funnel metric that tells you whether the match drives swaps |
| `GET /admin/catalogue` | Supported xStocks, last Jupiter sync, mints missing prices |
| `GET /admin/errors` | Recent failures: swap builds, signature verifications, tick fetches |
| `GET /admin/matches` | Recent matches with fingerprint, duration, event count, short-handed flag |

### 4.3 UI

Single-page dashboard served as a static asset from NestJS behind `AdminGuard`. No separate app, no
build step, no new deploy target. Tiles for the overview and revenue numbers, a feed-staleness
table, a filled-slot histogram, and buttons wired to the four existing demo controls plus a
**replay match** control hitting `POST /match/preview`.

Resist building this in Next.js. It is a six-day window and this is an internal tool.

---

## 5. Day-by-day

Six working days. Each day ends with something committed and demonstrable.

### Day 0 — Thu 2 Oct (remainder)
- Lock the four positioning decisions in [pitch.md](pitch.md). **Fill in the launch country and
  league** — the one blank in the deck.
- Decide the mascot shortlist (10–15 tickers).
- Confirm the geofence approach for non-US-persons.

### Day 1 — Fri 3 Oct — match engine core
- `match/engine/` types, `crossings.ts`, `clock.ts`, `opponent.ts`, `build-match.ts`.
- Every test in §1.7, including the one-slot and empty-defence cases. Tests first on `crossings`.
- Exit criterion: `build-match.spec.ts` green, and a JSON timeline printed from a real historical
  window.

### Day 2 — Sat 4 Oct — match API + screen
- `match.service.ts`, `match.controller.ts`, the three routes, match persistence with fingerprint.
- Flutter `features/match/`: pitch view, timeline playback, event feed, commentary templates.
- Exit criterion: a real wallet's match plays end to end on a device.

### Day 3 — Sun 5 Oct — partial squads + the loop
- Short-handed rendering, mascot assets and fallback, "sign another player" route into the draft.
- **Free-fill rule:** a purchase into an eligible or empty slot must not be charged as a
  substitution. Add a regression test — this one protects revenue.
- Share card via `share_plus`.
- Exit criterion: a one-stock wallet opens the app, sees 1 v 11, and reaches the draft in one tap.

### Day 4 — Mon 6 Oct — SKR + admin
- `entitlements/` ledger, on-chain signature verification, SKR purchase path for renders, skins and
  private leagues.
- Admin read endpoints and the static dashboard page.
- Exit criterion: an SKR purchase grants an entitlement, and fees earned render on the dashboard.

### Day 5 — Tue 7 Oct — demo and packaging
- Release APK, signed, installed clean on hardware.
- **Record the demo video in the shot order in [pitch.md](pitch.md)** — including the Seed Vault
  prompt on Seeker. Film this early in the day; it always takes longer than planned.
- Finish the deck. Begin the dApp Store listing: icon, screenshots, description, geofence note.
- Exit criterion: APK, video and deck all exist in final form.

### Day 6 — Wed 8 Oct — buffer and submit
- Submit in the morning. Treat the afternoon as contingency, not as build time.
- README refresh, repo tidy, verify the GitHub link a judge will click actually builds.

**If a day slips, cut in this order:** private leagues → mascot skins → share card → admin
`/errors` and `/matches`. **Never cut:** the match engine, the one-slot path, the free-fill rule,
Seed Vault on camera, or the deck.

---

## 6. Post-submission — video mode

Deliberately out of scope until after 8 October. The 2D engine is the match; video is the share.

The architecture is already right for it: the deterministic `MatchTimeline` is a storyboard. Each
event is a shot, with a known minute, actor, mascot and value. Video generation becomes
image-to-video per shot plus a concatenation, with no new game logic.

### Research task — model selection

Evaluate image-to-video models against these criteria, in priority order:

1. **Character consistency across shots** — the same mascot must survive a cut. This is the hard
   constraint and the usual failure mode.
2. **Cost per second of output** at the length of a highlight reel (target: 20–30s, 4–6 shots).
3. **Latency**, and whether an async queue is acceptable. With SKR paid up front and a push
   notification on completion, minutes are tolerable; the UX does not require real time.
4. **Image conditioning fidelity** — how closely the output honours a supplied mascot image.
5. **Terms of service** for commercial use and for brand-derived imagery.

Candidates to benchmark: the current image-to-video offerings from Google (Veo line), OpenAI (Sora
line), Runway, Luma, Pika, Kling, and the open-weight options via Replicate or fal. Treat all
capability and pricing claims as needing verification at evaluation time — this space moves monthly
and nothing here should be taken from memory.

Run the benchmark as a fixed harness: one storyboard, five models, same mascot inputs, compare cost,
latency and consistency side by side.

### Mascot source assets

Mascots are the conditioning images, so they gate video quality. Commission or generate a
consistent set — one style, one camera angle, transparent background — before any video work. Use
original characters inspired by the company, not trademarked logos, since renders are public and
shareable.

### Delivery

Async queue, SKR debited on request, push notification on completion, result cached against the
match `fingerprint` so the same match is never rendered twice.

---

## 7. Submission checklist

- [ ] APK builds clean and installs on hardware
- [ ] Mobile Wallet Adapter working, **Seed Vault prompt filmed on Seeker**
- [ ] Solana Mobile Stack integration demonstrable
- [ ] One-stock wallet produces a playable match
- [ ] Buying into an empty slot is free — regression test green
- [ ] SKR purchase grants an entitlement, verified on chain
- [ ] Admin dashboard shows fees earned
- [ ] Demo video follows the shot order, under 4 minutes
- [ ] Deck has no "zero risk" claim anywhere
- [ ] Deck names a launch country
- [ ] Geofence for non-US-persons in place
- [ ] GitHub repo public, README current, builds from a clean clone
- [ ] dApp Store listing drafted
- [ ] Submitted at solanamobile.com/hackathon
