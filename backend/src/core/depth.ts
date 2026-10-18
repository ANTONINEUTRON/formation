import { Inject, Injectable } from '@nestjs/common';
import { CONFIG } from './config.js';
import type { AppConfig } from './config.js';
import type { DepthSource } from './sources.js';

const USDC_MINT = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
const USDC_DECIMALS = 6;
const RETRIES = 3;

/** A Jupiter quote, reduced to what's read from it. Null [outAmount] means no route. */
async function jupiterQuote(
  config: AppConfig,
  inputMint: string,
  outputMint: string,
  amount: bigint,
): Promise<bigint | null> {
  const params = new URLSearchParams({
    inputMint,
    outputMint,
    amount: amount.toString(),
    slippageBps: '100',
  });
  for (let attempt = 0; ; attempt++) {
    const res = await fetch(`${config.jupiterApiUrl}/swap/v1/quote?${params}`, {
      headers: config.jupiterHeaders,
    });
    if (res.ok) {
      const body = (await res.json()) as { outAmount?: string };
      return body.outAmount ? BigInt(body.outAmount) : null;
    }
    // Rate limited or down: wait and retry, then give up loudly. Only a
    // definite "no route" (4xx other than 429) counts as a thin market.
    if (res.status === 429 || res.status >= 500) {
      if (attempt >= RETRIES) throw new Error(`Jupiter quote failed: ${res.status}`);
      await new Promise((r) => setTimeout(r, 2_000 * (attempt + 1)));
      continue;
    }
    return null;
  }
}

/**
 * Measures depth from Jupiter quotes: what buying [usd] of a stock with USDC,
 * then selling all of it straight back, would lose. Nothing is traded.
 */
@Injectable()
export class JupiterDepthSource implements DepthSource {
  constructor(@Inject(CONFIG) private readonly config: AppConfig) {}

  async roundTripLossPct(mint: string, usd: number): Promise<number | null> {
    const spend = BigInt(Math.round(usd * 10 ** USDC_DECIMALS));
    const shares = await jupiterQuote(this.config, USDC_MINT, mint, spend);
    if (!shares || shares <= 0n) return null;
    await new Promise((r) => setTimeout(r, this.config.quoteSpacingMs));
    const back = await jupiterQuote(this.config, mint, USDC_MINT, shares);
    if (back === null) return null;
    const lost = (Number(spend - back) / Number(spend)) * 100;
    return Math.max(0, Math.round(lost * 100) / 100);
  }
}
