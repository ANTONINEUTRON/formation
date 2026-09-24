import type { SportMode } from '../domain/sport.js';

export interface AppConfig {
  port: number;
  /** Postgres connection string (local Postgres or Supabase's Postgres). */
  databaseUrl: string;
  /** Separate database used by integration and e2e tests. */
  testDatabaseUrl: string;
  rpcUrl: string;
  jupiterApiUrl: string;
  /** Platform fee charged on every draft swap, in basis points. */
  platformFeeBps: number;
  /** Token account that receives the platform fee. Fees are off when empty. */
  jupiterFeeAccount: string;
  /** Base58 secret key of the wallet that writes trophy memos. */
  trophySecretKey: string;
  adminKey: string;
  authSecret: string;

  // ── Scoring (docs/formation-scoring.md) ────────────────────────────────────
  /** Minutes between price snapshots. */
  priceTickMinutes: number;
  /** Gameweek length per sport, in minutes. */
  gameweekMinutes: Record<SportMode, number>;
  /** Session ("day") bucket length used by role events, in minutes. */
  sessionMinutes: number;
  /** Epoch all gameweek windows are aligned to. */
  gameweekAnchor: Date;
  /** Benchmark every pick is scored against (SPYx). */
  benchmarkMint: string;
}

export const CONFIG = Symbol('CONFIG');

const WEEK_MINUTES = 7 * 24 * 60;
const DAY_MINUTES = 24 * 60;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const number = (value: string | undefined, fallback: number) =>
    value === undefined || value === '' ? fallback : Number(value);

  return {
    port: number(env.PORT, 3000),
    databaseUrl: env.DATABASE_URL ?? '',
    testDatabaseUrl: env.TEST_DATABASE_URL ?? '',
    rpcUrl: env.SOLANA_RPC_URL ?? 'https://api.mainnet-beta.solana.com',
    jupiterApiUrl: env.JUPITER_API_URL ?? 'https://lite-api.jup.ag',
    platformFeeBps: number(env.PLATFORM_FEE_BPS, 30),
    jupiterFeeAccount: env.JUPITER_FEE_ACCOUNT ?? '',
    trophySecretKey: env.TROPHY_SECRET_KEY ?? '',
    adminKey: env.ADMIN_KEY ?? '',
    authSecret: env.AUTH_SECRET ?? '',

    priceTickMinutes: number(env.PRICE_TICK_MINUTES, 60),
    gameweekMinutes: {
      football: number(env.GAMEWEEK_MINUTES_FOOTBALL, WEEK_MINUTES),
      basketball: number(env.GAMEWEEK_MINUTES_BASKETBALL, DAY_MINUTES),
      american_football: number(env.GAMEWEEK_MINUTES_AMERICAN_FOOTBALL, WEEK_MINUTES),
    },
    sessionMinutes: number(env.SESSION_MINUTES, DAY_MINUTES),
    gameweekAnchor: new Date(env.GAMEWEEK_ANCHOR ?? '2026-01-05T00:00:00.000Z'),
    // SPYx
    benchmarkMint: env.BENCHMARK_MINT ?? 'XsoCS1TfEyfFhfvj8EtZ528L3CaKBDBRqRapnBbDF2W',
  };
}
