# Formation — Hackathon Strategy & Opportunity Analysis

> Research conducted with Colosseum Copilot (builder-project corpus, crypto archives, The Grid, web).
> **As of 2026-10-02.**

Two hard deadlines frame everything: Stocklana judging concluded today (Oct 2), and
**CLOCK IN — the Solana Mobile Hackathon — closes October 8, 2026.** That leaves six days,
which changes the recommendations from "build more" to "re-frame and prove."

---

## Similar Projects

> These are hackathon submissions — demos and prototypes, not production products, and many
> are no longer active. Most hackathon projects don't become companies. They're here to show
> what has been tried.

- **Crypto Fantasy League (CFL)** (`crypto-fantasy-league-(cfl)`) — **1st Place Gaming, Breakout
  (Apr 2025), $25,000.** Draft crypto token squads, PvP on real market movements,
  MagicBlock-powered, explicitly "built for Solana Mobile." Closest precedent, and proof the
  mechanic can win.
- **CoinChamp** (`coinchamp`, Radar, Sep 2024) — "DraftKings-style fantasy crypto trading with
  play-to-earn portfolio competitions." Did not place.
- **Market Fantasy League** (`market-fantasy-league`, Cypherpunk, Sep 2025) — draft virtual crypto
  *and RWA* portfolios in fantasy leagues. Did not place. Closest to Formation's asset class.
- **Arbitron** (`arbitron`) and **TokenDraft** (`tokendraft`), both Cypherpunk — fantasy draft
  contests with prize pools. Neither placed.
- **deStreet** (`destreet:-trade-onchain-with-friends`) — **2nd Place DAOs & Communities,
  Renaissance (Mar 2024), $20,000.** Non-custodial mobile dApp for social copy-trading via
  Jupiter. Formation's "Adopt their wallet" is a direct descendant of a prize-winning mechanic.
- **Trepa** (`trepa`) — **1st Place Consumer Apps, Breakout, $25,000.** Mobile app where you stake
  on crowd *opinions* rather than outcomes. Won by reframing prediction away from gambling — the
  same move Formation makes with alpha-vs-return.
- **REKT** (`rekt`) — **3rd Place DeFi, Cypherpunk, $15,000.** Gamified mobile perps app with
  mini-games. Also an accelerator company.
- **LootGO** (`lootgo`) — **Mobile Award, Breakout, $25,000.** Move-to-earn geolocation game. The
  only pure Mobile Award winner in the corpus; won on a real-world loop a phone uniquely enables.
- **AlphaFC** (`alphafc`) — **1st Place DAOs & Network States, Radar, $30,000**, and an accelerator
  company. Football fan ownership with real financial stakes. Not a competitor, but proof that
  football + real financial exposure reads as a serious category to these judges.

**Pattern that matters:** fantasy-portfolio games have been submitted in all four hackathons
(Renaissance → Cypherpunk) and **only one ever placed.** The seven that failed all share two traits
Formation does not: virtual/drafted portfolios, and a prize pool. The one that won had neither
novelty of asset nor real holdings — but it had *mobile* and *real-time*.

**Accelerator check:** ran `acceleratorOnly` on the semantic query. Ten adjacent results, no direct
match — `crypto-fantasy-league-(cfl)`, `alphafc`, `rekt`, `supersize`, `the-arena`, `pregame`. The
overlap is tonal (sports, gamified trading), not positional. No accelerator company is doing
fantasy sports over real tokenized-equity holdings.

---

## Archive Insights

- **"What to Build in Solana DeFi: 10 Ideas for 2026"** (`superteam_blog`) — **Idea #1, quoting
  Ramzy of the Solana Foundation, is: *"Find a new way to get a consumer audience to try trading
  tokenized equities. Mobile-first and geo-specific GTM."*** That is Formation's one-line
  description written by the ecosystem that will judge it. Same piece: tokenized equity supply on
  Solana at an ATH of $684M, ~800K addresses holding, versus Robinhood's 28.4M funded customers
  and Groww's 12.9M in India alone. "The stocks are now onchain; we still need to bring the next
  million users."
- **Same source, on timing** — "63% of tokenized-equity spot volume on Solana happened outside U.S.
  exchange hours." The hard number that justifies continuous scoring. Formation's README argues a
  stock game "dies every night and weekend" on other rails; this stat proves the *demand* is
  already concentrated in exactly those hours.
- **Same source, on geography** — names Vietnam, Nigeria, Pakistan, Indonesia, Ukraine and the
  Philippines as places with "a thin choice of local stocks" where global investing is "slow,
  expensive, or blocked," and advises starting "with a task the customer already needs to complete."
- **"Blockchain's two cultures: The computer vs. the casino"** (`a16z_crypto`) — the framing to
  pre-empt. Judges sort consumer finance apps into "computer" (builds something) or "casino"
  (extracts). Formation's no-prize-pool, no-entry-fee, keep-every-share design is a *computer*
  answer; say so out loud rather than hoping it is inferred.
- **"Gen Z's American Dream: 5 Leg Parlay Your Way to Basic Physiological Needs"**
  (`alliance_essays`) — documents how sports-betting mechanics captured young men's financial
  attention post-COVID. Formation borrows that exact grammar (squad, matchday, captain) and points
  it at ownership instead of a wager. That is the thesis sentence, and it has an archive behind it.

---

## Current Landscape

### Angle 1 — Consumer wedge for tokenized equities

- **Key players:** xStocks/Backed (700+ stocks and ETFs, >$800M AUM), Remora Markets
  (`remora_markets`, Solana-native tokenized stocks), Grand (`grand`, swipe-driven mobile
  multi-asset app), Berry (`berry`, fractional US equities from $1), Dexly, DeGate. Kamino,
  Jupiter and Loopscale accept tokenized stocks as collateral.
- **Recent developments:** xStocks volume on Raydium tripled in Q2 2026 to $1.63B; >190,000 xStocks
  holders by July 2026; Solana captured 82% of global tokenized-equity market share with $1.45B
  July volume; StonkFun has done >$1.2B cumulative volume pairing coins with tokenized stocks.
- **Maturity: Growing, and crowded on the trading-UI layer.** Grid saturation for the relevant
  categories: **193 products across 153 distinct roots** tagged Solana. Every one of them is a
  terminal, a wallet or an exchange. None is a game.

### Angle 2 — Gamified / fantasy investing

- **Key players:** FantasyFunds and Fantasy Stock League (weekly head-to-head leagues on live market
  data, both paper-trading); Public and Stocktwits on the social-investing side; the eight hackathon
  fantasy-portfolio projects above.
- **Gap:** every one of them is **virtual**. The portfolio is a scorecard, not a position.
  Formation's "a slot can only be filled by a stock you genuinely hold" is the structural difference
  and the entire defensibility.
- **Maturity: Established but undifferentiated.** Paper-trading fantasy has no revenue model beyond
  subscriptions and ads, which is why none of these became large.

### Angle 3 — Solana Mobile distribution

- **CLOCK IN:** Sep 8 – **Oct 8, 2026**; winners early November. $125,000 across ten teams
  ($30k / $25k / $20k / $15k / $10k, then five at $5k) **plus a separate $10,000 SKR-integration
  prize.** Requires a functional Android APK, Mobile Wallet Adapter and Solana Mobile Stack
  integration, demonstrably mobile-first design, GitHub repo, demo video and pitch deck. Winners
  must ship to the Solana dApp Store, and also receive featured dApp Store placement, co-marketing,
  Seeker devices and a call with Anatoly Yakovenko.
- **Judging criteria, in their order:** stickiness and product-market fit for Seeker users; UX
  quality; innovation in mobile; presentation and demo clarity.
- **Maturity: Emerging and thin.** Only one Mobile Award winner (`lootgo`) exists in the corpus, and
  mobile-native consumer apps are sparse relative to 1,090 Cypherpunk Consumer Apps submissions.
  This is the least crowded door available.

---

## Insights & Gaps

- **The ask already exists in writing.** Solana Foundation published "mobile-first consumer wedge for
  tokenized equities, geo-specific GTM" as the #1 DeFi idea for 2026. Almost no one in the corpus is
  building it. That is an unusual alignment and the single largest asset.
- **The mechanic is well-trodden; the substrate is not.** Eight fantasy-portfolio attempts, seven
  failures. What failed was virtual drafting with prize pools. Nobody has attempted fantasy sports
  over *real holdings* with *alpha-based* scoring.
- **The scoring design is the real innovation and it is buried.** "One point per 0.1% a pick beats
  SPYx" eliminates beta — in a bull market everyone's portfolio rises and a return-scored game
  becomes a coin flip on market direction. Alpha scoring makes skill legible. No project in the
  corpus does this.
- **Gap: geography.** Ramzy's ask has two halves and the README answers only one. There is no geo in
  it. xStocks is non-US-persons only, which means the addressable market is *structurally* emerging
  markets — the constraint and the thesis are the same fact, and it isn't being used.
- **Gap: the retention loop is per-tick, not per-day.** Points banking on every price tick is
  elegant, but "stickiness" is judging criterion #1 and continuous accrual gives a user no reason to
  open the app at a specific moment.
- **Gap: SKR is decorative.** "Players can pay in USDC, SOL or SKR" will not win a $10,000 prize for
  creative SKR integration.

---

# Deep Dive: Top Opportunity

**The opportunity is not "fantasy sports for stocks." It is: the game is the onboarding funnel for
tokenized equities in emerging markets, and the swap is the product.**

## Market Landscape

- **Key players and what they offer:** Remora Markets, Grand, Berry, Dexly and DeGate all deliver
  tokenized-equity access on mobile with fractional ownership, 24/7 trading and gasless swaps. Grand
  adds swipe-discovery and AI behavioral profiling — the closest thing to a consumer wedge anyone
  has shipped. On the game side, FantasyFunds and Fantasy Stock League run live-data fantasy leagues
  with zero real exposure.
- **Grid evidence:** 193 products / 153 distinct roots in `rwa_tokenisation_platform` +
  `financial_services_platform` + `game` tagged Solana. Keyword recall on "tokenized stock" returned
  15 products — all exchanges, terminals and wallets, zero games. Remora Markets (`remora_markets`,
  `rwa_tokenisation_platform`) is the Solana-native comparable; Block Street (`block_street`) runs
  Everst and Aqua for lending and institutional execution.
- **Classification: Differentiation opportunity — Segment + UX.** The asset access layer is well
  covered; the *reason to start* is not. 800K addresses hold tokenized equities against Robinhood's
  28.4M funded customers. Every existing product assumes you already want to buy a stock and
  optimizes the transaction. Formation assumes you want to win at football and makes buying the
  stock the move that does it. That is a demand-generation product in a category of 193 supply-side
  products.

> **Related Builder:** **Crypto Fantasy League** (`crypto-fantasy-league-(cfl)`, Breakout Apr 2025,
> 1st Place Gaming $25k, accelerator) built fantasy squads on real-time market data for Solana
> Mobile with MagicBlock. Study their demo. **To differentiate, lead on the two things they don't
> have: real custody (their squads are drafted, Formation's are owned) and equities rather than
> tokens (an asset class with 700+ instruments, institutional backing and a non-degen narrative).**
> Also study **deStreet** (`destreet`, Renaissance, 2nd Place $20k) — non-custodial mobile social
> copy-trading via Jupiter is precisely "Adopt their wallet," and it won.

## The Problem

- **Concrete friction:** a 24-year-old in Lagos or Manila can name every Arsenal player and has never
  owned a share. Local exchanges offer a thin menu; buying US equities through traditional channels
  is slow, expensive or blocked outright. Superteam names Nigeria, the Philippines, Vietnam,
  Pakistan, Indonesia and Ukraine specifically. The tokens that fix this have existed since June
  2025 and 190,000 people hold them.
- **Who feels it:** not the DeFi native. The football fan with a Solana wallet, a stablecoin balance
  from freelancing or remittances, and no brokerage relationship. He has the money and the rail; he
  lacks a reason and a vocabulary.
- **How they solve it today:** they don't invest, or they buy memecoins. The Alliance essay documents
  where that attention goes instead — parlays and sportsbooks, where expected value is negative by
  design.
- **Quantified:** ~800K tokenized-equity addresses versus 28.4M Robinhood customers and 12.9M Groww
  investors — roughly a 50x gap on a supply base that is no longer the bottleneck ($684M supply ATH,
  700+ instruments). 63% of volume already happens outside US market hours, i.e. it is already a
  non-US, after-hours audience.

## Revenue Model

- **Fee structure:** basis points on every swap via Jupiter's `platformFee`, taken inside the
  transaction the player already signs. Jupiter keeps 2.5% of the platform fee; **Formation retains
  ~97.5%.** No referral program needed since January 2025 — pass any token account as `feeAccount`.
  No billing, no custody, no extra infrastructure. The cleanest part of the design, and already
  correct.
- **Unit economics:** at 50 bps, a user who drafts an XI with three inline buys averaging $20
  generates ~$0.30 on draft, then recurring revenue on every transfer. The game creates swap volume
  as a *byproduct of play* — the squad-rebuild moment is a trade cluster, and copy-trading via
  "Adopt their wallet" is a single budget split across a whole lineup, i.e. 9–11 swaps in one tap.
- **TAM math:** if emerging-market tokenized-equity holders grow from 800K toward even 1% of the
  Robinhood + Groww base (~410K incremental), at $500 annual swap volume per user and 50 bps, that
  is ~$1M ARR per 400K users. The honest version: this is a volume-multiplier business, not a
  per-user-margin business, and it only works if the game drives repeat trading.
- **Comparables:** Jupiter-integrated wallets and terminals monetize identically. Robinhood's
  analogue is payment for order flow; this is more transparent and the user signs it.

**Design constraint to hold:** mechanics must never discourage swapping, because swap fees are the
revenue. The README gets this right — "buying and selling is unlimited and free," with friction
placed on *substitutions* instead. It is also consistent with having no maximum squad size: the
bench absorbs everything a player owns rather than capping it. Keep both. If a judge suggests
transfer limits "for game balance," the answer is that transfers are the revenue and subs are the
balancing lever.

## Go-to-Market Friction

- **Not a two-sided marketplace** — say this explicitly in the pitch, because judges assume fantasy
  sports implies matchmaking. There is no prize pool, no entry fee and no opponent required: a solo
  player scores alpha against SPYx on day one. Jupiter supplies liquidity. **There is no cold-start
  problem,** which is a rare and pitchable strength.
- **The real cold start is social proof, not liquidity.** Leaderboards and "Adopt their wallet" need
  managers worth copying. Bootstrap: seed 20–50 public wallets of real local traders or
  crypto-football personalities, with permission, as the opening leaderboard. Because every lineup
  is on-chain and public, the social layer can be populated before there are users — the README
  already notes "no profile needs their permission," which makes this cheap.
- **Anchor strategy:** one country, one fandom, one fixture. Pick a league with a large
  wallet-holding audience and run matchday-synced sessions. Football XI in Lagos or Manila is
  culturally native in a way no US fintech can copy.
- **Network effects:** real after bootstrap. Each public lineup is both content and a copy-trade
  target, and copying produces swaps. Follower notifications on lineup changes turn one manager's
  rebuild into N trades.

## Founder-Market Fit

- **What the ideal founder brings:** emerging-market locality plus mobile-native shipping. Formation
  has a Flutter Android app with `solana_mobile_client` already wired, a NestJS scoring backend, 16
  feature modules, a deployed landing page, and a shipped APK release. That is execution evidence
  most submissions lack six days out.
- **Red flag to avoid:** presenting as a generic global consumer app. The weakest possible framing is
  "fantasy sports for stocks, for everyone." The strongest is "the mobile, geo-specific consumer
  wedge for tokenized equities that the Solana Foundation asked for." If the team is building from a
  market Superteam named, that is founder-market fit and it belongs on a slide.
- **Team gap:** the scoring engine is the hardest correctness surface (alpha vs SPYx, per-tick
  banking, session roll-up of role events). If anyone on the team has markets experience, foreground
  them.

## Why Crypto / Solana?

- **Could not be built without crypto:** scoring from *actual custody* requires reading balances the
  user controls. A brokerage API gives neither public lineups nor permissionless copy-trading. "Every
  manager's lineup is public on chain, so no profile needs their permission" is impossible on any
  brokerage rail.
- **Why Solana specifically:** xStocks trade continuously, so per-tick scoring exists only here — and
  63% of tokenized-equity volume already occurs outside US exchange hours, so the always-on audience
  is empirically there. Solana holds 82% of global tokenized-equity market share. Fee-taking is a
  Jupiter parameter, not infrastructure. And **no custom smart contract ships** — balances from
  chain, prices and routing from Jupiter, user signs everything. For a six-day window that is a
  decisive advantage; say it as a feature, not an omission.

## Risk Assessment

- **Technical:** low on rails, concentrated in scoring. No custom program, proven dependencies. The
  risk is alpha computation correctness and SPYx price-feed reliability during the demo. Pre-record
  a fallback.
- **Regulatory:** xStocks are non-US-persons only. Geofencing is mandatory, and the Solana dApp Store
  publication requirement (needed to claim prize money) makes this real rather than theoretical.
  Frame the restriction as the GTM thesis — the market was always ex-US.
- **Market:** honestly, a **vitamin dressed as a painkiller.** Nobody needs a fantasy stock game. But
  the ecosystem needs a consumer wedge for tokenized equities, and that *is* a painkiller for the
  Foundation, for xStocks and for Jupiter. Pitch the need served, not the need created.
- **Execution — the hardest part:** judging criterion #1 is stickiness, and per-tick accrual gives no
  reason to open the app at any particular moment. This is the gap to close first.

---

## The six-day plan: what actually buys the edge

Ranked by prize-points per hour, given that the app already exists.

1. **Re-frame the pitch deck around Ramzy's quote.** Slide 2 should be the Solana Foundation's own
   ask — "a consumer audience for tokenized equities, mobile-first and geo-specific GTM" — then
   "Formation is that app." Judges reward products that answer a question the ecosystem has already
   posed. Costs an afternoon and is worth more than any feature.
2. **Add the missing geography.** Name one country and one fandom. Ramzy asked for geo-specific GTM;
   a global pitch forfeits half the ask. Add a slide on why football XI + a thin local exchange + a
   wallet-holding young male population is the wedge.
3. **Make SKR structural, not accepted.** There is a separate, uncontested $10,000 for creative SKR
   integration — the best per-dollar prize in the hackathon. SKR should *pay the substitution cost*
   beyond the three free daily subs, and gate captain changes. That keeps friction on subs where the
   design already puts it, and never on swaps, so it does not touch revenue.
4. **Give stickiness a clock.** Roll role events up into one **matchday session** per day with a push
   notification, and notify on rank change and on followed-manager lineup changes. Judging criterion
   #1 is stickiness; continuous scoring reads as *no* reason to return. A daily appointment is the
   cheapest fix, and role events already roll up "once per session."
5. **Lead the demo with "Adopt their wallet," not the draft.** It is the most novel feature, the
   densest revenue moment (one budget → 9–11 swaps), and it descends from a mechanic that won
   $20,000 at Renaissance (`destreet`). Draft flows are what every losing fantasy submission
   demoed.
6. **Show Seeker hardware signing on camera.** Mobile Wallet Adapter and Solana Mobile Stack
   integration are pass/fail requirements; `solana_mobile_client` is already in `pubspec.yaml`, so
   film the Seed Vault prompt. Don't let a reviewer wonder.
7. **Pre-empt the casino read in one line.** "No prize pool, no entry fee, you keep every share — you
   score for beating the market, not for going up." The a16z two-cultures distinction is how
   sophisticated judges sort these apps, and Formation is on the right side of it by design. Make
   them hear it rather than deduce it.

**Two things to leave alone:** the swap-fee revenue model is correct as specified, and the
alpha-not-return scoring is the genuine innovation — no project in a 5,400-project corpus does it.

---

## Research caveats

- `/analyze` returned empty tag buckets for both cohorts attempted, so the crowding analysis rests on
  `/filters` track counts (1,090 Cypherpunk Consumer Apps submissions vs. 1,576 total projects) and
  Grid saturation rather than tag distributions.
- Hackathon projects surfaced here may no longer be active; verify current status before drawing
  conclusions about the competitive landscape.
- Copilot's knowledge is bounded by its data sources — absence of evidence is not evidence of
  absence.

## Sources

- [Superteam: What to Build in Solana DeFi — 10 Ideas for 2026](https://blog.superteam.fun/p/what-to-build-in-solana-defi-10-ideas)
- [CLOCK IN: The Solana Mobile Hackathon](https://solanamobile.com/blog/clock-in-the-solana-mobile-hackathon)
- [Stocklana hackathon](https://hackathons.solana.com/hackathons/stocklana)
- [Jupiter: Add fees to swap](https://developers.jup.ag/docs/swap/add-fees-to-swap)
- [Solana tokenized equity holders surpass 800,000](https://solanacompass.com/news/solana-tokenized-equity-holders-surpass-800000-in-new-all-time-high)
- [Raydium xStocks volume tripled in Q2 2026](https://solanacompass.com/news/raydium-reports-xstocks-trading-volume-tripled-in-q2-2026-reaching-163-billion)
- [Solana tokenized equities capture 82% global market share](https://solanacompass.com/news/solana-tokenized-equities-hit-145b-in-july-volume-capturing-82-global-market-share)
- [Alliance: Gen Z's American Dream](https://alliance.xyz/essays/gen-zs-american-dream)
- Crypto archives via Colosseum Copilot: `a16z_crypto` ("Blockchain's two cultures: The computer vs.
  the casino"), `paradigm_research` ("The Casino on Mars"), `multicoin_capital` ("RWAs Are Just Built
  Different"), `superteam_blog` ("Deep Dive of the State of RWAs on Solana")
