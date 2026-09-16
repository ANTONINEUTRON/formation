export interface AppConfig {
  port: number;
  supabaseUrl: string;
  supabaseServiceKey: string;
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
}

export const CONFIG = Symbol('CONFIG');

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  return {
    port: Number(env.PORT ?? 3000),
    supabaseUrl: env.SUPABASE_URL ?? '',
    supabaseServiceKey: env.SUPABASE_SERVICE_KEY ?? '',
    rpcUrl: env.SOLANA_RPC_URL ?? 'https://api.mainnet-beta.solana.com',
    jupiterApiUrl: env.JUPITER_API_URL ?? 'https://lite-api.jup.ag',
    platformFeeBps: Number(env.PLATFORM_FEE_BPS ?? 30),
    jupiterFeeAccount: env.JUPITER_FEE_ACCOUNT ?? '',
    trophySecretKey: env.TROPHY_SECRET_KEY ?? '',
    adminKey: env.ADMIN_KEY ?? '',
    authSecret: env.AUTH_SECRET ?? '',
  };
}
