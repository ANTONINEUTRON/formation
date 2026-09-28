# Formation

> Fantasy football where the players are real stocks. Beat the market, keep every share.

Formation is fantasy sports played with the tokenized US equities (xStocks) in your
own Solana wallet. You field a squad — a football XI, a basketball five or an
American Football nine — and every position demands a different risk tier: the
goalkeeper has to be a blue chip, the forwards have to be momentum names.

Because a slot can only be filled by a stock you genuinely hold, playing and
investing are the same act. Nobody is talked into a trade; they are picking a
striker.

You score for **beating the market**, not for going up. A pick earns points on
how far it outperforms SPYx over the same window, so a rising market hands
nobody an advantage. And nothing is ever pooled or staked: there is no prize
pool and no entry fee, you keep every share, and winning gets you standing on a
leaderboard.

- **App** — [Android release](https://github.com/ANTONINEUTRON/formation/releases/tag/stocklana)
- **Site** — <https://formation.titalabs.xyz>

---

## How it works

**Draft.** Connect a Solana wallet and pick a sport. Each slot accepts one risk
tier of xStock. If you already hold it, the slot fills from your real balance;
if you don't, you buy it inline through Jupiter, signed in your own wallet.
There is no maximum squad size, because there is no maximum to what you may
own — anything you hold outside the starting lineup sits on the bench.

**Scoring.** Base points are alpha, not return: one point per 0.1% a pick beats
SPYx. Points bank on every price tick rather than waiting for a window to
close, so the leaderboard moves while you watch it. On top of that, each sport
has its own role events — goals, clean sheets and conceded goals in football,
buckets and blocks in basketball, touchdowns and turnovers in American Football
— rolled up once per session, because a 3% move means nothing over five
minutes. Football captains score double and have a vice-captain as backup;
basketball's go-to scorer is ×1.5.

**Transfers and substitutions** are priced in opposite directions on purpose.
Buying and selling is unlimited and free. Subbing a bench stock into the
starting lineup is free three times a day and then costs points. Selling a pick
mid-window doesn't void it — it keeps the points it earned up to the sale price.

**The social layer.** Every manager's rank, record, lineup and wallet is public
on chain, so no profile needs their permission. Follow someone and you're told
when they change their lineup. *Adopt their wallet* opens a sheet of everything
they hold, ticked; untick what you don't want, set one budget, and buy the rest.
It copies their picks, not their position sizes — the budget splits evenly, so
you copy what someone thinks rather than how rich they are.

**Revenue** is basis points on every swap, taken through Jupiter's platform fee
inside the transaction the player already signs. No separate billing, no
custody, no extra infrastructure. Players can pay in USDC, SOL or SKR.

**Why Solana.** xStocks trade around the clock, so continuous scoring is only
possible here — a stock game on any other rail dies every night and weekend.
There is no custom smart contract: balances come from chain, prices and routing
from Jupiter, and the user signs everything.

---

## Repository layout

```
symbianss/
├── app/            # Flutter (Android-first) — wallet connect, draft, team, leagues
├── backend/        # NestJS + Postgres — scoring engine, leagues, swap orchestration
└── landing_page/   # Static marketing site (index.html)
```

### Backend

NestJS with Kysely over Postgres. Prices and swap routes come from Jupiter;
balances from a Solana RPC.

- `scoring/` — the engine. `engine/score-entry.ts` scores one locked lineup;
  `general-scoring.service.ts` banks the running Classic league on every tick;
  `price-tick.service.ts` is the heartbeat that records prices and triggers it.
- `domain/` — sport shapes and risk tiers (`sport.ts`), captaincy, league
  periods, payable tokens.
- `xstocks/` — the catalogue, refreshed from Jupiter on an interval.
- `league/`, `leagues/`, `managers/`, `notifications/`, `roster/`, `swap/`,
  `wallet/`, `users/`, `auth/`, `admin/` — the HTTP surface.

### App

Flutter, Android-first, using Mobile Wallet Adapter (`solana_mobile_client`) so
every transaction is signed in the user's own wallet. `flutter_bloc` for state,
`auto_route` for navigation, feature-first structure under `lib/features/`.

---

## Getting started

**Prerequisites:** Node.js 20+, Postgres 14+, Flutter 3+, an Android device or
emulator with a Solana wallet installed.

### Backend

```bash
cd backend
npm install
cp .env.example .env     # then fill in DATABASE_URL, AUTH_SECRET, ADMIN_KEY
npm run db:migrate
npm run start:dev        # http://localhost:3000
```

`.env.example` documents every variable, including several with sharp edges —
Jupiter fee accounts must be *token* accounts rather than wallet addresses, and
`SKR_DECIMALS` must match the mint exactly. Read it before filling `.env` in.

The xStocks catalogue loads from Jupiter at boot when the table is empty, so
seeding isn't required. `npm run seed` adds demo managers for a populated
leaderboard.

Tests need `TEST_DATABASE_URL` set:

```bash
npm test          # unit
npm run test:int  # integration
npm run test:e2e  # end-to-end
npm run test:all  # everything
```

### App

```bash
cd app
flutter pub get
flutter run
```

Point the app at your backend via its Envied configuration; it defaults to the
deployed API.

### Landing page

Static — open `landing_page/index.html`, or serve the directory with any static
file server. Deployed through Firebase Hosting (`firebase.json`).

---

## Design notes

**No pooled funds, by design.** Formation has no prize pool, no entry fee and
never moves anyone's money between wallets. This is a deliberate constraint, not
an oversight: in 2015 the SEC shut down Stock Battle over a prize whose value
depended on securities performance, and in June 2024 India's SEBI cut fantasy
platforms off from exchange price data. Formation has no pot to win and no
exchange feed to switch off. Any feature that stakes tokens on ranking would
undo both.

**Scoring ignores position size.** Holding $1 of a stock scores exactly the same
as holding $10,000. The league measures stock picking, so revenue has to come
from how often people trade rather than from how much they hold.

**Thin pools are a game-integrity lever.** Points scale with the price move
against the benchmark, and a pool holding a few dollars can be moved a long way
for a few dollars more. `CATALOGUE_MIN_LIQUIDITY_USD` is the control: `0` lists
all ~100 xStocks, roughly 41 clear $1,000 and 30 clear $5,000.

**Availability.** xStocks are issued under Regulation S and are not available to
US, Canadian, UK or Australian persons. Formation serves the ~110 countries
where they can be held.

---

## Known gaps

- Android-first; iOS and web are unexercised.
- Role events trigger on a pick's own return rather than its alpha, so a broad
  rally still pays points that the "beat the market" framing says it shouldn't.
- `classic_scores.streak` is read by the API and rendered in the app, but only
  the seed script ever writes it — real users can't build a streak yet.
- Event thresholds were tuned for crypto volatility rather than equities and are
  still being adjusted.
