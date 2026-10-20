import { parsePacks } from '../assistant/packs.js';
import type { CreditPack } from '../assistant/packs.js';
import { DEFAULT_SEASON_ANCHOR } from '../domain/calendar.js';
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
  /**
   * Origins the web app is served from, from CORS_ORIGINS. Sign In With
   * Solana messages must name one of these as their domain.
   */
  webOrigins: string[];

  // ── Scoring (docs/formation-scoring.md) ────────────────────────────────────
  /** Minutes between price snapshots, and therefore between banked points. */
  priceTickMinutes: number;
  /** Session ("day") length: the window role events are rolled up over. */
  sessionMinutes: number;
  /** Epoch every session boundary is aligned to. */
  sessionAnchor: Date;
  /** Benchmark every pick is scored against (SPYx). */
  benchmarkMint: string;
  /**
   * Largest move against the benchmark one tick can bank (0.1 = 10%). A bigger
   * one is held for a tick, then banked clamped to this if it persists.
   */
  maxTickMove: number;
  /**
   * The least a holding must be worth, in USD, to count as held: to be placed
   * in a team, sit on the bench, or score. Points don't depend on how much is
   * held, so without it a few cents of a stock would score like a full one.
   */
  minHoldingUsd: number;
  /** Credits for an Assistant Manager squad draft. */
  squadDraftCredits: number;
  /** ET date in the week season 1 kicks off; seasons run 12 match weeks from it. */
  seasonAnchor: string;
  /** Points at full time for a team spanning [teamBalanceSectors]+ sectors. 0 turns it off. */
  teamBalanceBonus: number;
  teamBalanceSectors: number;

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
  /**
   * Backpack's public API, whose asset list is the allow-list for Backpack
   * Securities' tokenized stocks. Empty turns Backpack listings off.
   */
  backpackApiUrl: string;

  // ── Assistant Manager ──────────────────────────────────────────────────────
  /** Gemini API key. Empty disables the assistant: its replies fail with 503. */
  geminiApiKey: string;
  /** Gemini model used for replies. */
  geminiModel: string;
  /** Gemini model that draws custom Assistant Managers from a photo. */
  geminiImageModel: string;
  /** Credits for each custom avatar after the first, which is free. */
  assistantAvatarCredits: number;
  /**
   * Credits a Manager is given once, the first time their account is seen:
   * by default two squad drafts and five replies. It's the only free
   * allowance; everything after is bought.
   */
  assistantTrialCredits: number;
  /** Credit packs for sale, from ASSISTANT_PACKS. */
  assistantPacks: CreditPack[];
  /**
   * SKR token account that credit purchases are paid into. Defaults to the SKR
   * fee account; empty disables buying credits.
   */
  assistantTreasury: string;

  // ── Push ───────────────────────────────────────────────────────────────────
  /**
   * Firebase service account key (raw or base64 JSON) for FCM. Empty turns
   * pushes off; the in-app inbox works either way.
   */
  fcmServiceAccount: string;

  // ── Admin (ADMIN_PLAN.md) ──────────────────────────────────────────────────
  /** Wallet addresses allowed into /admin with a normal session. */
  adminWallets: string[];
  /** Points a single correction may move before it needs a second confirmation. */
  adminCorrectionLimit: number;
  /** Gemini USD price per million tokens in and out, for the spend estimate. */
  assistantCostPerMtokIn: number;
  assistantCostPerMtokOut: number;
  /** Database size the health page measures against, in MB; 0 means unknown. */
  dbSizeLimitMb: number;
  /** Wallet snapshot job: wallets per batch, minutes between runs (0 turns it off). */
  walletSnapshotBatch: number;
  walletSnapshotEveryMin: number;
  /** Never re-read a wallet sooner than this, in minutes. */
  walletMinRereadMin: number;
  /** RPC calls the wallet reads may spend per UTC day, job and manual together. */
  rpcDailyBudget: number;
}

export const CONFIG = Symbol('CONFIG');

const DAY_MINUTES = 24 * 60;

/** Squad drafts the welcome credits cover, on top of five replies. */
export const WELCOME_DRAFTS = 2;

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
    webOrigins: (env.CORS_ORIGINS ?? '')
      .split(',')
      .map((origin) => origin.trim())
      .filter((origin) => origin.length > 0),

    priceTickMinutes: number(env.PRICE_TICK_MINUTES, 60),
    sessionMinutes: number(env.SESSION_MINUTES, DAY_MINUTES),
    sessionAnchor: new Date(env.SESSION_ANCHOR ?? '2026-01-05T00:00:00.000Z'),
    // SPYx
    benchmarkMint: env.BENCHMARK_MINT ?? 'XsoCS1TfEyfFhfvj8EtZ528L3CaKBDBRqRapnBbDF2W',
    maxTickMove: number(env.MAX_TICK_MOVE, 0.1),
    minHoldingUsd: number(env.MIN_HOLDING_USD, 1),
    squadDraftCredits: number(env.SQUAD_DRAFT_CREDITS, 3),
    seasonAnchor: env.SEASON_ANCHOR?.trim() || DEFAULT_SEASON_ANCHOR,
    teamBalanceBonus: number(env.TEAM_BALANCE_BONUS, 5),
    teamBalanceSectors: number(env.TEAM_BALANCE_SECTORS, 4),

    catalogueRefreshHours: number(env.CATALOGUE_REFRESH_HOURS, 12),
    catalogueMinLiquidityUsd: number(env.CATALOGUE_MIN_LIQUIDITY_USD, 0),
    backpackApiUrl: (env.BACKPACK_API_URL ?? 'https://api.backpack.exchange').trim(),

    geminiApiKey: env.GEMINI_API_KEY?.trim() ?? '',
    geminiModel: env.GEMINI_MODEL?.trim() || 'gemini-2.5-flash',
    geminiImageModel: env.GEMINI_IMAGE_MODEL?.trim() || 'gemini-2.5-flash-image',
    assistantAvatarCredits: number(env.ASSISTANT_AVATAR_CREDITS, 20),
    assistantTrialCredits: number(
      env.ASSISTANT_TRIAL_CREDITS,
      5 + WELCOME_DRAFTS * number(env.SQUAD_DRAFT_CREDITS, 3),
    ),
    assistantPacks: parsePacks(env.ASSISTANT_PACKS),
    assistantTreasury: (env.ASSISTANT_TREASURY ?? env.JUPITER_FEE_ACCOUNT_SKR ?? '').trim(),

    fcmServiceAccount: env.FCM_SERVICE_ACCOUNT?.trim() ?? '',

    adminWallets: (env.ADMIN_WALLETS ?? '')
      .split(',')
      .map((wallet) => wallet.trim())
      .filter((wallet) => wallet.length > 0),
    adminCorrectionLimit: number(env.ADMIN_CORRECTION_LIMIT, 500),
    // Gemini 2.5 Flash list prices.
    assistantCostPerMtokIn: number(env.ASSISTANT_COST_PER_MTOK_IN, 0.3),
    assistantCostPerMtokOut: number(env.ASSISTANT_COST_PER_MTOK_OUT, 2.5),
    dbSizeLimitMb: number(env.DB_SIZE_LIMIT_MB, 0),
    walletSnapshotBatch: number(env.WALLET_SNAPSHOT_BATCH, 20),
    walletSnapshotEveryMin: number(env.WALLET_SNAPSHOT_EVERY_MIN, 30),
    walletMinRereadMin: number(env.WALLET_MIN_REREAD_MIN, 30),
    rpcDailyBudget: number(env.RPC_DAILY_BUDGET, 5000),
  };
}
