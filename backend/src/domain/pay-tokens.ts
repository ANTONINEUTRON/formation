/**
 * The tokens a player can spend to buy an xStock.
 *
 * Two things here are easy to get wrong and expensive when you do:
 *
 *   Decimals differ between mints. Sending an amount scaled by the wrong
 *   power of ten is a 1000x error in a real transaction, so the scale always
 *   comes from the token rather than from a constant.
 *
 *   Jupiter's platform fee needs a fee account whose mint is the input or the
 *   output mint. One USDC account cannot collect a fee on an SKR swap, so each
 *   payable token carries its own, and a token without one simply charges no
 *   fee rather than failing the swap.
 *
 * SOL is deliberately not payable. Paying with it means wrapping SOL inside
 * the swap and a separate wrapped-SOL fee account, and it competes with the
 * network fees every swap needs SOL for anyway — a player who spends their
 * last SOL on a stock cannot afford to sign the next transaction. USDC covers
 * the same need without either problem.
 */
export const PAY_SYMBOLS = ['USDC', 'SKR'] as const;
export type PaySymbol = (typeof PAY_SYMBOLS)[number];

export interface PayToken {
  symbol: PaySymbol;
  mint: string;
  decimals: number;
  /** Token account that collects the platform fee, or '' for no fee. */
  feeAccount: string;
  /**
   * Smallest buy this token will quote, in whole units of the token itself.
   *
   * Roughly a dollar, and per token because token prices differ. Below about a
   * dollar a swap stops making sense — the network fee and the rent for a
   * first-time token account both exceed the trade, so the player pays more to
   * place it than it is worth, and a slot filled with 30 cents of stock scores
   * nothing anyone can see.
   */
  minAmount: number;
}

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
 * USDC is always available because its mint is fixed. SKR only
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
      minAmount: 1,
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
      // SKR has no established price here yet, so 1 is a placeholder rather
      // than a dollar. Revisit alongside SKR_MINT.
      minAmount: 1,
    });
  }
  return tokens;
}
