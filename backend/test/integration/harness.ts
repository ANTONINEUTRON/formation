import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import { sql } from 'kysely';
import { AppModule } from '../../src/app.module.js';
import { CLOCK } from '../../src/core/clock.js';
import { DB } from '../../src/core/db.js';
import type { Db } from '../../src/core/db.js';
import { BALANCE_SOURCE, PRICE_SOURCE } from '../../src/core/sources.js';
import type { AuthUser } from '../../src/domain/dto.js';
import { rosterShape } from '../../src/domain/sport.js';
import type { SportMode } from '../../src/domain/sport.js';
import { LeagueService } from '../../src/league/league.service.js';
import { LeaguesService } from '../../src/leagues/leagues.service.js';
import { GeneralScoringService } from '../../src/scoring/general-scoring.service.js';
import { RosterService } from '../../src/roster/roster.service.js';
import { PriceTickService } from '../../src/scoring/price-tick.service.js';
import { UsersService } from '../../src/users/users.service.js';
import { XStocksService } from '../../src/xstocks/xstocks.service.js';
import { migrate } from '../../src/scripts/migrate.js';
import { FakeBalanceSource, FakeClock, FakePriceSource } from '../fakes/fakes.js';

export const BENCHMARK_MINT = 'SPYx-test-mint';

/** A small, tier-complete stock pool: enough for every roster shape. */
export const TEST_STOCKS = [
  { mint: BENCHMARK_MINT, symbol: 'SPYx', company_name: 'S&P 500', tier: 'blue_chip' as const },
  { mint: 'mint-AAPL', symbol: 'AAPLx', company_name: 'Apple', tier: 'blue_chip' as const },
  { mint: 'mint-MSFT', symbol: 'MSFTx', company_name: 'Microsoft', tier: 'blue_chip' as const },
  { mint: 'mint-KO', symbol: 'KOx', company_name: 'Coca-Cola', tier: 'stable' as const },
  { mint: 'mint-PG', symbol: 'PGx', company_name: 'P&G', tier: 'stable' as const },
  { mint: 'mint-JNJ', symbol: 'JNJx', company_name: 'J&J', tier: 'stable' as const },
  { mint: 'mint-WMT', symbol: 'WMTx', company_name: 'Walmart', tier: 'stable' as const },
  { mint: 'mint-MCD', symbol: 'MCDx', company_name: "McDonald's", tier: 'stable' as const },
  { mint: 'mint-JPM', symbol: 'JPMx', company_name: 'JPMorgan', tier: 'balanced' as const },
  { mint: 'mint-V', symbol: 'Vx', company_name: 'Visa', tier: 'balanced' as const },
  { mint: 'mint-MA', symbol: 'MAx', company_name: 'Mastercard', tier: 'balanced' as const },
  { mint: 'mint-ORCL', symbol: 'ORCLx', company_name: 'Oracle', tier: 'balanced' as const },
  { mint: 'mint-UNH', symbol: 'UNHx', company_name: 'UnitedHealth', tier: 'balanced' as const },
  { mint: 'mint-NVDA', symbol: 'NVDAx', company_name: 'NVIDIA', tier: 'growth' as const },
  { mint: 'mint-META', symbol: 'METAx', company_name: 'Meta', tier: 'growth' as const },
  { mint: 'mint-AMD', symbol: 'AMDx', company_name: 'AMD', tier: 'growth' as const },
  { mint: 'mint-TSLA', symbol: 'TSLAx', company_name: 'Tesla', tier: 'momentum' as const },
  { mint: 'mint-HOOD', symbol: 'HOODx', company_name: 'Robinhood', tier: 'momentum' as const },
  { mint: 'mint-PLTR', symbol: 'PLTRx', company_name: 'Palantir', tier: 'momentum' as const },
];

/** Wiped between tests. Order is irrelevant — the truncate cascades. */
const TABLES = [
  'score_entries',
  'general_entries',
  'points_ledger',
  'daily_substitutions',
  'price_ticks',
  'roster_slots',
  'rosters',
  'classic_scores',
  'league_members',
  'leagues',
  'notifications',
  'follows',
  'users',
  'xstocks',
];

export interface Harness {
  app: INestApplication;
  db: Db;
  clock: FakeClock;
  prices: FakePriceSource;
  balances: FakeBalanceSource;
  rosters: RosterService;
  general: GeneralScoringService;
  leagues: LeaguesService;
  league: LeagueService;
  users: UsersService;
  priceTicks: PriceTickService;
  reset(): Promise<void>;
  close(): Promise<void>;
  /** Creates a player holding 10 shares of every test stock. */
  createPlayer(username: string): Promise<AuthUser>;
  /** Fills every slot of a roster from the tier-matching pool. */
  draft(user: AuthUser, mode: SportMode): Promise<string[]>;
}

/**
 * Boots the real app against TEST_DATABASE_URL with a fake clock, prices and
 * balances. Gameweeks are one hour with ten-minute sessions, as in the demo
 * profile, so tests can open and close them quickly.
 */
export async function createHarness(): Promise<Harness> {
  try {
    process.loadEnvFile();
  } catch {
    // No .env file; use the real environment.
  }
  const url = process.env.TEST_DATABASE_URL;
  if (!url) throw new Error('TEST_DATABASE_URL is required to run integration tests');

  process.env.DATABASE_URL = url;
  process.env.GAMEWEEK_MINUTES_BASKETBALL = '60';
  process.env.GAMEWEEK_MINUTES_AMERICAN_FOOTBALL = '60';
  process.env.SESSION_MINUTES = '10';
  // Long enough that the background interval never fires during a test.
  process.env.PRICE_TICK_MINUTES = '1000';
  process.env.BENCHMARK_MINT = BENCHMARK_MINT;
  process.env.AUTH_SECRET ||= 'test-secret';
  process.env.ADMIN_KEY ||= 'test-admin-key';

  await migrate(url);

  const clock = new FakeClock();
  const prices = new FakePriceSource();
  const balances = new FakeBalanceSource();

  const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
    .overrideProvider(CLOCK)
    .useValue(clock)
    .overrideProvider(PRICE_SOURCE)
    .useValue(prices)
    .overrideProvider(BALANCE_SOURCE)
    .useValue(balances)
    .compile();

  const app = moduleRef.createNestApplication();
  await app.init();

  const db = app.get<Db>(DB);
  const xstocks = app.get(XStocksService);
  const users = app.get(UsersService);
  const rosters = app.get(RosterService);

  const harness: Harness = {
    app,
    db,
    clock,
    prices,
    balances,
    rosters,
    general: app.get(GeneralScoringService),
    leagues: app.get(LeaguesService),
    league: app.get(LeagueService),
    users,
    priceTicks: app.get(PriceTickService),

    async reset() {
      await sql.raw(`truncate table ${TABLES.join(', ')} restart identity cascade`).execute(db);
      await db
        .insertInto('xstocks')
        .values(TEST_STOCKS.map((s) => ({ ...s, decimals: 8 })))
        .execute();
      // Drop the 5-minute stock cache between tests.
      (xstocks as unknown as { cache?: unknown }).cache = undefined;
      for (const stock of TEST_STOCKS) prices.set(stock.mint, 100);
      clock.set(Date.UTC(2026, 0, 5, 12, 0, 0));
    },

    async close() {
      await app.close();
    },

    async createPlayer(username: string) {
      const wallet = `wallet-${username}`;
      const user = await users.upsertByWallet(wallet);
      await db.updateTable('users').set({ username }).where('id', '=', user.id).execute();
      balances.setAll(
        wallet,
        TEST_STOCKS.map((s) => s.mint),
        10,
      );
      return { id: user.id, walletAddress: wallet };
    },

    async draft(user: AuthUser, mode: SportMode) {
      const roster = await rosters.getRoster(user, mode);
      const used = new Set<string>();
      const picked: string[] = [];
      for (const slot of roster.slots) {
        const tier = rosterShape(mode, roster.formation)[slot.slotIndex].tier;
        const stock = TEST_STOCKS.find(
          (s) =>
            s.mint !== BENCHMARK_MINT && !used.has(s.mint) && (tier === null || s.tier === tier),
        );
        if (!stock) throw new Error(`No test stock left for slot ${slot.slotIndex} in ${mode}`);
        used.add(stock.mint);
        picked.push(stock.mint);
        await rosters.fillSlot(user, mode, slot.slotIndex, stock.mint);
      }
      return picked;
    },
  };

  await harness.reset();
  return harness;
}
