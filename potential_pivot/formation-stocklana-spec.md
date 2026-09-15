# Formation — Fantasy Sports for Real Stocks

*A Stocklana Hackathon build. Working title: "Formation" (soccer formation / stock formation double meaning) — rename freely, e.g. LineupX, Draft Day, TickerLeague.*

> **One-liner:** Fantasy football, but the roster is your real wallet, the players are tokenized stocks, and every win is backed by money you actually own.

---

## 1. The Idea, Vividly

Picture a Discord full of friends who've been arguing about stocks for years. Every week someone says "I'm buying NVDA, who's in?" and nothing ever gets tracked — no record of who called it, who chickened out, who was actually right. Meanwhile, tens of millions of people already know exactly how to turn that kind of argument into a game: draft a roster, face an opponent, watch the scoreboard move, brag when you win. That's fantasy football. Nobody's built it for stocks, for real, with real ownership on the other end.

Formation is that game. A user connects a Solana wallet, picks a sport mode — Football, Basketball, or American Football — and drafts a roster of tokenized stocks (xStocks) into that sport's positions. If they already hold the stock, it slots straight in. If they don't, one tap routes them through a real Jupiter swap to buy it, right there in the draft screen. From that moment on, their roster *is* their real portfolio, organized into a game.

Every hour, the score moves — up if the roster's real value went up, down if it didn't — visibly, live, addictively. Every player is automatically in the global Classic league for their sport, climbing an all-time leaderboard. Any player can also challenge a specific friend to a head-to-head duel: pick a duration, they accept, and whoever's roster performs better over that exact window wins bragging rights, a spot on the leaderboard, and an on-chain trophy.

Nobody's money ever moves between players. There's no pool, no escrow, no smart contract to write or trust. The "stake" was always just each person's own real holdings — which is what makes this buildable in days instead of months, and honest instead of a gambling product wearing a fantasy-sports costume.

**Why now, why Solana:** tokenized equities (xStocks) trade 24/7 on-chain even when NYSE is closed — Solana tokenized stock volume has reportedly topped combined NYSE+NASDAQ volume with a majority of trades happening after market hours. A stock game on any other rail goes dead every night and every weekend. This one never stops ticking, which is the whole reason an hourly-scored game is even possible here.

---

## 2. Why This Wins the Judging Bar

Stocklana's stated judging question is *"could this be a real app that people will actually use?"* Formation's answer:

- **Proven demand pattern, new asset class.** Fantasy sports already has a massive, obsessive, paying audience. This isn't inventing new behavior — it's porting validated behavior onto real financial assets.
- **Real Solana relevance, not decorative.** Every roster slot is a real on-chain token balance. Every draft pick that isn't already held triggers a real Jupiter swap. Every score is computed from real, verifiable on-chain state. This could not exist on a traditional brokerage.
- **No custody, no smart contract, no regulatory grey zone.** Nobody's funds are pooled or transferred by the app. The app never controls user funds — it only reads balances and prompts swaps the user signs themselves. This is a deliberate design choice, and a strong answer to the "compliance" angle Stocklana explicitly calls out as a focus area.
- **A credible, working revenue model from day one** (see §7) that requires zero extra infrastructure beyond what's already being built for the core loop.

---

## 3. Core Mechanics

### 3.1 Sport Modes (Roster Shapes)

Three modes, each a different roster shape mapped to risk categories — not cosmetic reskins, but different strategic puzzles:

| Mode | Roster size | Character | Position → risk category example |
|---|---|---|---|
| **Basketball** | 5 slots | Fast, low-commitment, easiest onboarding | PG/SG = growth, SF/PF = balanced, C = blue-chip anchor |
| **Football (Soccer)** | 11 slots (e.g. 4-3-3) | The flagship mode — balance risk across a "pitch" | GK = safest blue-chip anchor, Defenders = stable/dividend, Midfielders = balanced/growth, Forwards = high-volatility/momentum |
| **American Football** | Largest, most positions | Deepest, most strategic, for power users | QB = core conviction pick, RB/WR/TE = varied risk tiers, FLEX = wildcard |

Each mode draws from the same pool of supported xStocks (currently 41 tokenized US equities, issued 1:1-backed against real shares — Tesla, Apple, Microsoft, GameStop, etc., tradeable via Jupiter on Solana). Position slots simply constrain *which risk tier* of stock can go where, which is what creates real drafting strategy instead of "just pick 5 hot tickers."

A user's roster for a given sport mode is **one live roster**, shared across the Classic league and every currently-open duel in that mode — there's only one real portfolio, after all.

### 3.2 Draft Flow

1. User connects wallet (Phantom / Backpack — Backpack is a nice tie-in since Backpack Securities issues/mints xStocks).
2. User picks a sport mode and sees the position slots for that shape.
3. For each slot, user searches/picks an eligible xStock.
   - **Already held in wallet** → slot fills immediately using their real current balance.
   - **Not held** → inline prompt to buy via Jupiter Swap API (USDC → xStock), signed by the user's own wallet. On confirmation, the slot fills with the new real holding.
4. Draft complete → roster is live and being scored from the next hourly tick onward.

### 3.3 Classic Global League

- One global, auto-enrolled leaderboard **per sport mode**. Every drafted user is automatically ranked.
- **Never resets** for this build (no seasons) — pure lifetime accrued points. Seasons are a roadmap item, not MVP.
- Updated every hour (see §3.5 for the scoring mechanism).

### 3.4 Head-to-Head (H2H) Duels

- **No auto-matching, no ladder, no "league" object.** Purely peer-to-peer: Player A sends a challenge to Player B (by wallet address, username, or shareable link).
- At challenge creation, **Player A selects the duration** — recommend a small preset set for a fast, buildable UI: **1h / 6h / 24h / 3d / 7d**. (1h exists specifically so a full duel can be demoed live in front of judges.)
- Player B accepts (or declines) as proposed — no negotiation/counter-offer in this build.
- On accept, a duel record is created with `start_time = now`, `end_time = now + duration`.
- At settlement (`end_time` reached), the backend reads both players' current on-chain balances, computes each player's point delta over the window (§3.5), and declares a winner. No funds move — winner gets standings credit + a trophy (§3.6).
- A user can have multiple concurrent duels open at once, all scored off the same live roster.

### 3.5 Scoring — The Actual Formula

**Core principle:** you cannot lock tokens in a self-custodied wallet, so don't try. Instead, snapshot real holdings at the start of a scoring window, read the real wallet again at the end, and score the verified difference.

**Hourly Classic tick (runs every hour, per active user, per sport mode):**

```
For each roster slot with token T:
  start_amount = balance of T at last hour's snapshot
  end_amount   = balance of T right now (read from Solana)
  counted_amount = MIN(start_amount, end_amount)   # anti-gaming rule, see below
  price_start  = price of T at last snapshot (Pyth / Jupiter)
  price_end    = price of T right now
  slot_return_pct = (price_end - price_start) / price_start   # only if counted_amount > 0

roster_return_pct = AVERAGE(slot_return_pct across all filled slots)
points_delta = roster_return_pct * 10,000   # 1 basis point of return = 1 point

user.classic_score += points_delta
store new balance/price snapshot as next hour's baseline
```

**Duel settlement (runs once, at `end_time`):** identical math, but `start_amount`/`price_start` come from the duel's accept-time snapshot and `end_amount`/`price_end` come from a live read at `end_time`, over the whole duel window (not hourly increments). Whoever's `roster_return_pct` (or cumulative points over the window) is higher wins.

**Why `MIN(start_amount, end_amount)`:** this is the anti-gaming rule, and it matters — without it, a user could deposit a large amount of a token that's currently pumping right before a snapshot and instantly inflate their score with capital that had nothing to do with skill. Using the smaller of the two balances means only shares genuinely held across the *whole* window count toward the price-return calculation. Selling some mid-window still honestly drags the score down (the smaller end balance becomes the basis for future windows); buying more mid-window just doesn't count until the *next* window's baseline. Simple to compute, no extra infrastructure, closes the most obvious exploit a judge would spot in seconds.

**Why average, not sum, across slots:** keeps the score a normalized "portfolio return" figure regardless of roster size — a 5-slot Basketball roster and an 11-slot Football roster stay comparable in magnitude.

**Why real value, not paper simulation:** because the roster is real holdings from the moment it's drafted, there is no separate "convert winnings into a real purchase" step needed — a player already owns exactly what their roster says, the whole time. This was a design simplification we found mid-brainstorm: fantasy participation *is* investing, not a game that occasionally triggers investing.

### 3.6 Rewards (No Custody, By Design)

Nobody's money is transferred as a result of winning — the "stake" was always the real holdings themselves. What winning gets you:

- **Standings & streaks** on the Classic leaderboard and duel record (win/loss history).
- **An on-chain trophy/badge**, minted to the winner's wallet after a duel or a notable Classic milestone — cheap to build, great demo moment, reinforces the "verifiable, on-chain" story.
- *(Roadmap, not MVP)* fee rebates on future buys, extra roster slots unlocked, sponsored league placements.

---

## 4. Technical Architecture

**Explicit non-goal: no custom Solana program.** Everything below uses existing infrastructure — this is a deliberate scope decision to make a solo, few-day build achievable, and it's also the reason there's no custody/compliance risk to defend to judges.

### 4.1 Stack

- **Frontend:** Next.js + TypeScript + Tailwind, mobile-first. Solana wallet adapter (Phantom, Backpack).
- **Backend:** Next.js API routes / serverless functions + a scheduled job runner (cron — e.g. Vercel Cron or a simple scheduled worker) for the hourly tick and duel settlements.
- **Database:** Supabase (Postgres) — relational, real-time-friendly, trivial auth-by-wallet-signature pattern.
- **On-chain reads:** Solana RPC (`getParsedTokenAccountsByOwner` / `getTokenAccountBalance`) to read xStock balances for any wallet.
- **Price data:** Pyth price feeds and/or Jupiter Price API for xStock pricing at snapshot time.
- **Trade execution:** Jupiter Swap API (`/quote` + `/swap`) for the in-draft "buy" flow. Non-custodial — user signs their own transaction.
- **Revenue:** Jupiter's built-in platform fee mechanism — pass `platformFeeBps` on the quote request and a `feeAccount` (any token account you control) on the swap request. No separate referral-dashboard registration needed (Jupiter removed that requirement as of Jan 2025) — fee is deducted atomically inside the same swap transaction the user already signs. Recommend 20–50 bps.

### 4.2 Data Model (suggested Supabase schema)

```
users
  id, wallet_address (unique), username, created_at

rosters
  id, user_id, sport_mode ('football' | 'basketball' | 'american_football'),
  created_at, is_active

roster_slots
  id, roster_id, position_label ('GK' | 'DEF' | ... | 'FLEX' etc.),
  token_mint, token_symbol

hourly_snapshots
  id, roster_id, token_mint, balance, price_usd, captured_at

classic_scores
  user_id, sport_mode, total_points, updated_at

duels
  id, challenger_id, opponent_id, sport_mode, duration_hours,
  status ('pending' | 'active' | 'settled' | 'declined'),
  start_time, end_time, winner_id

duel_snapshots
  id, duel_id, user_id, token_mint, balance, price_usd, captured_at
  -- one row per roster slot, per participant, per checkpoint (start/end)

trophies
  id, user_id, type ('duel_win' | 'classic_milestone'), awarded_at, mint_address
```

### 4.3 Scheduled Jobs

- **Hourly tick** (every user × every active roster): read balances, read prices, compute `points_delta` per §3.5, update `classic_scores`, write new `hourly_snapshots` row.
- **Duel settlement** (fires at each duel's specific `end_time`): read both participants' balances/prices, compute both `roster_return_pct`s, write `winner_id`, mint a trophy for the winner.

### 4.4 External APIs Used

- Jupiter `/quote` and `/swap` (trade execution + platform fee)
- Jupiter or Pyth price feed endpoints (scoring)
- Solana RPC (balance reads)
- *(Optional, not required for MVP)* Backpack Securities Mint/Redeem API — only relevant if you later want issuance-side features; not needed for the game loop.

---

## 5. Revenue Model

1. **Primary — swap fee on every buy.** 20–50 bps via Jupiter's `platformFeeBps`/`feeAccount`, collected atomically inside the swap transaction the user already signs during drafting. Zero extra engineering — it's a parameter on a call already being made.
2. **Secondary — freemium subscription.** Free: one sport mode, standard roster, basic Classic ranking. Paid: multiple concurrent sport modes, deeper analytics (sector exposure, risk breakdown), custom profile/trophy case, priority duel invites. Pure SaaS, no on-chain dependency.
3. **Later-stage (roadmap, mention in pitch, don't build):** sponsored league placements from xStocks issuers/exchanges (Backpack, Kraken, Bybit all want distribution for tokenized equities), on-ramp affiliate revenue, cosmetic trophy customization.

---

## 6. MVP Scope for This Build

**In scope (must ship):**
- Wallet connect
- Draft flow for at least one sport mode fully, ideally all three (Basketball first — smallest roster, fastest to build; expand to Football/American Football if time allows)
- Real-holdings-aware draft (already-held check + Jupiter buy prompt)
- Hourly Classic scoring + global leaderboard per sport mode
- H2H duel request/accept flow with preset durations, snapshot-based settlement
- `MIN(start,end)` anti-gaming rule
- Jupiter platform fee wired into every swap
- Basic dashboard: my roster, my Classic rank, my open/past duels, live points ticking

**Explicitly cut (say so proudly in the pitch, don't apologize):**
- Private leagues / league creation
- Auto-matchmaking H2H ladder
- Seasons / score resets
- Roster locking (unnecessary — see §3.5)
- Any pooled funds, escrow, or custom Solana program
- Duel duration negotiation (proposer sets it, other side just accepts/declines)

---

## 7. Demo Script (for judges)

1. Connect wallet → land straight on a live Classic leaderboard (seed it beforehand so it's never empty).
2. Draft a Basketball roster in under a minute — show one slot auto-fill from an existing holding, one slot trigger a real Jupiter buy.
3. Watch the hourly tick fire (or trigger it manually for the demo) — points visibly move, roster value updates.
4. Challenge a second wallet (a teammate's, or the judge's own, if they'll connect) to a **1-hour** duel.
5. Let it resolve live during the demo — winner declared, trophy minted.
6. Flip to the leaderboard — standings updated, streak shown.
7. Close on: non-custodial by design (no smart contract, no escrow, real revenue from day one via Jupiter fees), and the "24/7 tokenized stocks are what make an hourly-scored game even possible" line tying it straight back to why this belongs on Solana specifically.

---

## 8. Open Items / v2 Roadmap (mention, don't build)

- Seasons with resets and season-end prizes (cosmetic, not custodial)
- Private leagues (the original "Circles" concept — bring back once the global engine is proven)
- Position-weighted scoring multipliers (forward picks count double, etc.)
- Duel duration negotiation / counter-offers
- Sponsored leagues, on-ramp affiliate integration
- Backpack Securities Mint/Redeem API integration for issuance-side features

---

## 9. Hackathon Context (for reference)

- Event: Stocklana, Solana Foundation's inaugural hackathon on hackathons.solana.com
- Prompt: "The stock market is open for building." $100K total prize pool.
- Submission deadline: **Friday, September 18, 2026, 4:00 PM ET**
- Judging lens: "could this be a real app that people will actually use?" — real user problem, functional end-to-end demo, Solana relevance, execution quality
- Suggested focus areas covered by this build: **Consumer applications** (primary), touches on **Trading** and **Infrastructure/compliance** (via the non-custodial design decision)
