
export interface AppConfig {
  /** Postgres connection string. PORT is read directly by main.ts. */
  databaseUrl: string;
  rpcUrl: string;
  jupiterApiUrl: string;
  /** Platform fee charged on every draft swap, in basis points. */
  platformFeeBps: number;
  /** Token account that receives the platform fee. Fees are off when empty. */
  jupiterFeeAccount: string;
  adminKey: string;
  authSecret: string;

  // ── Scoring (docs/formation-scoring.md) ────────────────────────────────────
  /** Minutes between price snapshots, and therefore between banked points. */
  priceTickMinutes: number;
  /** Session ("day") length: the window role events are rolled up over. */
  sessionMinutes: number;
  /** Epoch every session boundary is aligned to. */
  sessionAnchor: Date;
  /** Benchmark every pick is scored against (SPYx). */
  benchmarkMint: string;
}

export const CONFIG = Symbol('CONFIG');

const DAY_MINUTES = 24 * 60;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const number = (value: string | undefined, fallback: number) =>
    value === undefined || value === '' ? fallback : Number(value);

  return {
    databaseUrl: env.DATABASE_URL ?? '',
    rpcUrl: env.SOLANA_RPC_URL ?? 'https://api.mainnet-beta.solana.com',
    jupiterApiUrl: env.JUPITER_API_URL ?? 'https://lite-api.jup.ag',
    platformFeeBps: number(env.PLATFORM_FEE_BPS, 30),
    jupiterFeeAccount: env.JUPITER_FEE_ACCOUNT ?? '',
    adminKey: env.ADMIN_KEY ?? '',
    authSecret: env.AUTH_SECRET ?? '',

    priceTickMinutes: number(env.PRICE_TICK_MINUTES, 60),
    sessionMinutes: number(env.SESSION_MINUTES, DAY_MINUTES),
    sessionAnchor: new Date(env.SESSION_ANCHOR ?? '2026-01-05T00:00:00.000Z'),
    // SPYx
    benchmarkMint: env.BENCHMARK_MINT ?? 'XsoCS1TfEyfFhfvj8EtZ528L3CaKBDBRqRapnBbDF2W',
  };
}
