# Formation — Scoring Design

> How points work across Football, Basketball and American Football, and how to make scoring a
> game of strategy rather than a mirror of the market.
> Product spec: [formation-stocklana-spec.md](../potential_pivot/formation-stocklana-spec.md) ·
> Build plan: [formation-ui-plan.md](formation-ui-plan.md)

---

## 1. What scoring has to do

1. **Reward decisions, not the market.** If the whole market rallies, everyone shouldn't win.
2. **Make positions matter.** A goalkeeper and a striker should be judged differently, so the draft
   is a real puzzle.
3. **Give a reason to come back.** Fantasy players make a few decisions every week (captain,
   bench, transfers). We need the same ritual.
4. **Stay honest.** Rosters are real holdings, so every rule must survive the `MIN(start, end)`
   anti-gaming check: nothing can be earned by buying at the right moment.
5. **Be explainable in ten seconds** to a judge.

## 2. Where we are today

| Rule | Status |
|---|---|
| 1 point per basis point of average roster return, per hourly tick | Built |
| `MIN(start, end)` balance: only shares held all window count | Built |
| Duels won by higher return over the window | Built |
| **Football: FPL squad, formations, captain ×2, vice, bench auto-subs** | **Built (this change)** |

The gaps: points follow market direction (a green day lifts everyone), positions only restrict
which stocks are eligible, and after drafting there is nothing to decide.

---

## 3. What fantasy sports teach

| Game | Mechanic | Lesson for us |
|---|---|---|
| **FPL** | 15-player squad, any formation with 1 GK / 3+ DEF / 1+ FWD, captain ×2, vice as backup, ordered bench auto-subs, two sets of chips per season (Wildcard, Free Hit, Triple Captain, Bench Boost). New in 2025/26: defensive contribution points. | The same event is worth different points by position (a defender's goal pays more than a forward's), so role changes value. Captain = one high-conviction weekly call. |
| **NBA fantasy** | *Points* leagues (volume) vs *head-to-head categories* (win 5 of 9 stat categories; "punting" categories is a strategy). | Categories make a head-to-head matchup many small contests, and let players build a team to win specific ones. |
| **NFL fantasy** | PPR (points per reception) changes which positions are valuable; FLEX and Superflex create scarcity. | One scoring knob reshapes the whole draft. |
| **DFS (DraftKings)** | Salary cap, ownership %, contrarian picks create separation in tournaments. | Low-owned picks are a strategy in themselves. |
| **Fantasy Stocks (FS Digital)** — closest competitor | Sector-based roster slots, weekly H2H, score = weekly % move, bull/bear positioning, Friday close decides. | Weekly H2H on stock moves works as a format. Our edge: real holdings, not paper, and 24/7 xStocks instead of market hours. |

---

## 4. The menu of mechanics

Effort is for this codebase. Anti-gaming checks the `MIN` rule still holds.

| # | Mechanic | What it does | Effort | Anti-gaming |
|---|---|---|---|---|
| A | **Raw return** (today) | Points follow price | — | ✅ |
| B | **Beat the market (alpha vs SPYx)** | Base points = stock return − SPYx return. Removes market direction. | S — one extra price per tick | ✅ Holding SPYx scores 0 base |
| C | **Beat your position peers** | Base = return − average return of same-tier stocks | S | ✅ |
| D | **Role events** ("goals", "clean sheets") | Bonuses by role for threshold moves | M | ✅ Uses counted balances |
| E | **Captain / vice** | ×2 on one pick | **Built** (football) | ✅ Applies from next window |
| F | **Bench + auto-subs** | Insurance when a starter is sold | **Built** (football) | ✅ |
| G | **Chips** | Triple Captain, Bench Boost, once per month | M | ✅ Must be played before the gameweek |
| H | **Sector cap** | Max 3 stocks per sector (FPL's max 3 per club) | S | n/a |
| I | **Differential bonus** | +10% on positive points for stocks <10% owned in the league | S | ✅ |
| J | **Gameweeks + transfer hits** | 1 free swap per gameweek, extra swaps −4 pts | M | ✅ Discourages churn |
| K | **Category duels** | Head-to-head won on categories, not one number | M | ✅ |
| L | **Gameweek lineup lock** | Lineup changes apply next gameweek | S | ✅ Removes hourly captain-hopping |

---

## 5. Recommendation: one engine, three personalities

### 5.1 Shared engine (all sports)

1. **Gameweeks.** Football and American Football: weekly (Monday 00:00 UTC → Sunday).
   Basketball: daily "game nights". Hourly ticks keep a *live* score moving; role events settle
   when the gameweek closes. Classic league = sum of gameweek points. **Gameweek length is
   configurable, so the demo runs 1-hour gameweeks.**
2. **Base points: beat the market (B).** Each counted starter earns **1 point per 0.1% it beats
   SPYx** over the gameweek (negative if it lags). Summed across starters, like FPL. A stock that
   beats the market by 3% in a week is +30, roughly FPL's scale.
3. **Real-money role events (D).** Bonuses use the stock's own return, so "you actually made
   money" is rewarded on top of beating the market.
4. **Lineup lock (L).** Formation, captain and bench lock at gameweek start.
5. **`MIN(start, end)` stays everywhere.**

### 5.2 Football — FPL mirror (weekly)

| Event | GK | DEF | MID | FWD |
|---|---|---|---|---|
| Base: per 0.1% beating SPYx | 1 | 1 | 1 | 1 |
| **Goal**: each full +3% own gain | 6 | 6 | 5 | 4 |
| **Assist**: beat SPYx by ≥ 1% | 3 | 3 | 3 | 3 |
| **Clean sheet**: own return ≥ 0 | 4 | 4 | 1 | 0 |
| **Goals conceded**: each full −2% own loss | −1 | −1 | 0 | 0 |

- Captain ×2 (after events), vice-captain backup, like-for-like auto-subs (already built).
- Chips, one of each per month: **Triple Captain**, **Bench Boost**.
- Squad rule: **max 3 stocks per sector**.

*Why it's strategic:* a steady stock (KOx) rarely scores goals but banks clean sheets; if it ever
jumps 3% it pays more than a striker's goal. Momentum forwards score goals but concede nothing
extra, so they're high ceiling. Formation choice becomes a real risk call: 5-4-1 in a choppy week,
3-4-3 when you expect momentum.

### 5.3 Basketball — fast and head-to-head (daily game nights)

| Event | Rule | Points |
|---|---|---|
| Base | per 0.1% beating SPYx | 1 |
| **Bucket** | each full +1% own gain (guards PG/SG only) | 2 |
| **Block** | Center finishes green on a day SPYx is red | 5 |
| **Double-double** | 2+ starters beat SPYx by ≥ 1% on the same day | 5 (team) |
| **Go-to scorer** | Captain ×1.5 | — |

**Duels are category head-to-heads (K), won 3–2 style:**
Alpha (team return vs SPYx) · Hit rate (% of starters green) · Best pick (top single return) ·
Defense (least-bad worst pick) · Hot hand (longest run of green hourly ticks).
You can "punt" a category, e.g. go all-in on Best pick and concede Defense.

### 5.4 American Football — deepest, weekly with lock

| Event | Rule | Points |
|---|---|---|
| Base ("yards") | per 0.1% beating SPYx | 1 |
| **Touchdown** | each full +4% own gain (QB/RB/WR/TE/FLEX) | 6 |
| **Reception (PPR)** | WR/TE: each green day | 0.5 |
| **Turnover** | each full −4% own loss | −2 |
| **Clean pocket** | QB never drops more than 2% below the week's open | 4 |
| **Field goal** | K: each green day | 1 |

- No captain: the QB's clean-pocket bonus is the conviction pick.
- Lineup locks at "kickoff" (Monday). Optional later: Superflex (a second QB-tier slot).

### 5.5 Worked example (Football gameweek)

SPYx +1.0%. Captain TSLAx +7.5% (FWD); JNJx −2.4% (DEF); KOx +0.4% (DEF).

| Pick | Base | Events | Total |
|---|---|---|---|
| TSLAx (C) | +65 | Goal ×2 = +8, Assist +3 | (65 + 11) × 2 = **152** |
| JNJx | −34 | Conceded −1 | **−35** |
| KOx | −6 | Clean sheet +4 | **−2** |

KOx lagged the market but still earned its clean sheet: role matters.

---

## 6. What to build by the deadline

The Friday demo needs points that move and make sense, not every mechanic.

| Priority | Item | Estimate |
|---|---|---|
| **Now** | FPL formations, captain, vice, bench auto-subs (football) | **Done** |
| **Must** | Base = beat SPYx (B) in both scoring engines | 2–3h |
| **Must** | Gameweek ledger table + configurable length (1h for demo) | 3–4h |
| **Must** | Football event table (§5.2) settled at gameweek close; live provisional score | 3h |
| Should | Basketball captain ×1.5 + events; AF events + lock | 3h |
| Later | Chips, sector cap, transfer hits, differential bonus, category duels | roadmap slide |

The new work adds a `gameweek_scores` table (user, mode, gameweek start, base points, event points,
breakdown JSON). The hourly tick writes provisional rows, and gameweek close finalizes them and
adds them to `classic_scores`. Duels settle on points over their window instead of raw return.

---

## 7. Decisions needed

1. **Base points:** beat SPYx (B, recommended), beat position peers (C), or keep raw return (A)?
2. **Cadence:** weekly gameweeks (Football/AF) plus daily game nights (Basketball)?
3. **Scope by Friday:** Football events only, or all three sports' tables?
4. **Basketball duels:** categories (K), or the same points duel as the other sports?

---

## Sources

- [FPL rules](https://fantasy.premierleague.com/help/rules) ·
  [What's new for 2025/26](https://www.premierleague.com/en/news/4373187/whats-new-for-202526-changes-in-fantasy-premier-league) ·
  [Changes explained](https://www.premierleague.com/en/news/4362211/all-you-need-to-know-about-changes-to-fantasy-for-202526)
- [Fantasy basketball: points vs categories (RotoWire)](https://www.rotowire.com/basketball/article/fantasy-basketball-scoring-points-categories-97198) ·
  [9-cat strategy (Yahoo)](https://sports.yahoo.com/fantasy/article/fantasy-basketball-9-cat-leagues-101-draft-strategy-for-the-2025-26-nba-season-173554094.html)
- [Fantasy football scoring formats compared](https://fantasybutler.com/blog/fantasy-football-scoring) ·
  [PPR, Half-PPR, Superflex explained](https://rosterlytic.com/sideline/explainers/fantasy-football-scoring-formats)
- [Contrarian DFS strategy (PFF)](https://www.pff.com/news/fantasy-football-how-to-use-a-contrarian-strategy-to-win-in-daily-fantasy)
- [Fantasy Stocks by FS Digital (App Store)](https://apps.apple.com/us/app/fantasy-stocks-by-fs-digital/id6760236937)
