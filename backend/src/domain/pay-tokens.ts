/**
 * The tokens a player can spend to buy an xStock.
 *
 * Two things here are easy to get wrong and expensive when you do:
 *
 *   Decimals differ. USDC has 6, SOL has 9. Sending an amount scaled by the
 *   wrong power of ten is a 1000x error in a real transaction, so the scale
 *   always comes from the token rather than from a constant.
 *
 *   Jupiter's platform fee needs a fee account whose mint is the input or the
 *   output mint. One USDC account cannot collect a fee on a SOL swap, so each
 *   payable token carries its own, and a token without one simply charges no
 *   fee rather than failing the swap.
 */
export const PAY_SYMBOLS = ['USDC', 'SOL', 'SKR'] as const;
export type PaySymbol = (typeof PAY_SYMBOLS)[number];

export interface PayToken {
  symbol: PaySymbol;
  mint: string;
  decimals: number;
  /** Token account that collects the platform fee, or '' for no fee. */
  feeAccount: string;
}

/** Wrapped SOL. Jupiter unwraps native SOL into this automatically. */
export const SOL_MINT = 'So11111111111111111111111111111111111111112';
export const USDC_MINT = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';

export function parsePaySymbol(value: string | undefined): PaySymbol {
  const symbol = (value ?? 'USDC').toUpperCase();
  if (!(PAY_SYMBOLS as readonly string[]).includes(symbol)) {
    throw new Error(`payWith must be one of ${PAY_SYMBOLS.join(', ')}`);
  }
  return symbol as PaySymbol;
}

/**
 * Builds the payable list from the environment.
 *
 * USDC and SOL are always available because their mints are fixed. SKR only
 * appears once `SKR_MINT` is set — until then the app never offers it, which
 * is safer than shipping a placeholder address people could swap into.
 */
export function loadPayTokens(env: NodeJS.ProcessEnv): PayToken[] {
  const tokens: PayToken[] = [
    {
      symbol: 'USDC',
      mint: USDC_MINT,
      decimals: 6,
      feeAccount: env.JUPITER_FEE_ACCOUNT_USDC ?? env.JUPITER_FEE_ACCOUNT ?? '',
    },
    {
      symbol: 'SOL',
      mint: SOL_MINT,
      decimals: 9,
      feeAccount: env.JUPITER_FEE_ACCOUNT_SOL ?? '',
    },
  ];

  // Decimals are never guessed. They scale the amount a player types, so a
  // default that happens to be wrong overspends their wallet by a power of ten
  // — the mint's real value has to be stated, or SKR is simply not offered.
  // Note the trim: Number('') is 0, so a blank value would otherwise sail
  // through the integer check as a legitimate "zero decimals".
  const rawDecimals = env.SKR_DECIMALS?.trim();
  const skrDecimals = Number(rawDecimals);
  if (env.SKR_MINT && rawDecimals && Number.isInteger(skrDecimals) && skrDecimals >= 0) {
    tokens.push({
      symbol: 'SKR',
      mint: env.SKR_MINT,
      decimals: skrDecimals,
      feeAccount: env.JUPITER_FEE_ACCOUNT_SKR ?? '',
    });
  }
  return tokens;
}
