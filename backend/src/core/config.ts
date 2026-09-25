import { loadPayTokens } from '../domain/pay-tokens.js';
import type { PayToken } from '../domain/pay-tokens.js';

export interface AppConfig {
  /** Postgres connection string. PORT is read directly by main.ts. */
  databaseUrl: string;
  rpcUrl: string;
  jupiterApiUrl: string;
  /**
   * Headers for every Jupiter request: the API key, when there is one.
   *
   * Derived once here so the header name lives in a single place — a typo in it
   * does not fail loudly, it just silently drops you back to the keyless rate
   * limit, which only shows up later as intermittent 429s under load.
   */
  jupiterHeaders: Record<string, string>;
  /** Platform fee charged on every swap, in basis points. */
  platformFeeBps: number;
  /** Tokens a player can spend, each with its own fee account. */
  payTokens: PayToken[];
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

  // ── Catalogue ──────────────────────────────────────────────────────────────
  /** Hours between refreshes of the xStocks catalogue. 0 disables it. */
  catalogueRefreshHours: number;
  /**
   * Minimum pool liquidity, in USD, for a stock to be listed. 0 lists every
   * xStock Jupiter returns.
   *
   * Worth understanding before changing: a stock's points come from its price
   * move against the benchmark, multiplied by POINTS_PER_ALPHA. A pool of a few
   * dollars can be moved a long way for a few dollars more, so a thin stock is
   * a cheap way to manufacture a large score. Raising this is the lever that
   * closes that off.
   */
  catalogueMinLiquidityUsd: number;
}

export const CONFIG = Symbol('CONFIG');

const DAY_MINUTES = 24 * 60;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const number = (value: string | undefined, fallback: number) =>
    value === undefined || value === '' ? fallback : Number(value);

  // A key is only honoured on api.jup.ag; lite-api.jup.ag is the keyless host
  // and would ignore it, leaving you paying for headroom you never get. So the
  // default host follows the key rather than being set independently of it.
  const jupiterApiKey = env.JUPITER_API_KEY?.trim() ?? '';
  const defaultJupiterUrl = jupiterApiKey ? 'https://api.jup.ag' : 'https://lite-api.jup.ag';

  return {
    databaseUrl: env.DATABASE_URL ?? '',
    rpcUrl: env.SOLANA_RPC_URL ?? 'https://api.mainnet-beta.solana.com',
    jupiterApiUrl: env.JUPITER_API_URL ?? defaultJupiterUrl,
    jupiterHeaders: jupiterApiKey ? { 'x-api-key': jupiterApiKey } : {},
    platformFeeBps: number(env.PLATFORM_FEE_BPS, 30),
    payTokens: loadPayTokens(env),
    adminKey: env.ADMIN_KEY ?? '',
    authSecret: env.AUTH_SECRET ?? '',

    priceTickMinutes: number(env.PRICE_TICK_MINUTES, 60),
    sessionMinutes: number(env.SESSION_MINUTES, DAY_MINUTES),
    sessionAnchor: new Date(env.SESSION_ANCHOR ?? '2026-01-05T00:00:00.000Z'),
    // SPYx
    benchmarkMint: env.BENCHMARK_MINT ?? 'XsoCS1TfEyfFhfvj8EtZ528L3CaKBDBRqRapnBbDF2W',

    catalogueRefreshHours: number(env.CATALOGUE_REFRESH_HOURS, 12),
    catalogueMinLiquidityUsd: number(env.CATALOGUE_MIN_LIQUIDITY_USD, 0),
  };
}
