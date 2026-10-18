import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { SwapService } from './swap.service.js';

const USDC = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
const TSLA = 'mint-TSLA';
const user = { id: 'u1', walletAddress: 'wallet-1' } as never;

/** Jupiter's quote endpoint, answering from a table keyed by input→output. */
function stubJupiter(rates: Record<string, (amount: bigint) => bigint | null>) {
  const calls: URLSearchParams[] = [];
  vi.stubGlobal(
    'fetch',
    vi.fn(async (url: string) => {
      const params = new URL(url).searchParams;
      calls.push(params);
      const rate = rates[`${params.get('inputMint')}>${params.get('outputMint')}`];
      const out = rate?.(BigInt(params.get('amount')!));
      if (out === null || out === undefined) return new Response('{"error":"no route"}', { status: 400 });
      return new Response(JSON.stringify({ outAmount: out.toString(), priceImpactPct: '0.01' }), { status: 200 });
    }),
  );
  return calls;
}

function service(held = 2) {
  return new SwapService(
    {
      jupiterApiUrl: 'https://jup.test',
      jupiterHeaders: {},
      platformFeeBps: 30,
      payTokens: [{ symbol: 'USDC', mint: USDC, decimals: 6, feeAccount: 'fee-usdc', minAmount: 1 }],
    } as never,
    { byMint: async () => new Map([[TSLA, { mint: TSLA, symbol: 'TSLAx', decimals: 8 }]]) } as never,
    { getBalances: async () => new Map([[TSLA, held]]) } as never,
  );
}

describe('SwapService', () => {
  beforeEach(() => vi.restoreAllMocks());
  afterEach(() => vi.unstubAllGlobals());

  it('quotes a sale for USDC with the fee taken from what is received', async () => {
    // 1 TSLAx (8 decimals) sells for $200 before the fee; Jupiter returns the net.
    const calls = stubJupiter({
      [`${TSLA}>${USDC}`]: (shares) => (shares * 200_000_000n * 9_970n) / 10_000n / 100_000_000n,
      [`${USDC}>${TSLA}`]: (usdc) => (usdc * 100_000_000n) / 200_000_000n,
    });
    const quote = await service().quoteSell(user, TSLA, 1);

    expect(quote.shares).toBe(1);
    expect(quote.estimatedUsdc).toBeCloseTo(199.4, 6);
    expect(quote.platformFeeBps).toBe(30);
    expect(quote.platformFee).toBeCloseTo(0.6, 6);
    // Buying back with what was received gets almost all of it back: a deep market.
    expect(quote.buyBackShares).toBeCloseTo(0.997, 6);
    const sell = calls[0];
    expect(sell.get('platformFeeBps')).toBe('30');
    expect(sell.get('instructionVersion')).toBe('V2');
    // The buy-back is a plain quote, with no fee.
    expect(calls[1].get('platformFeeBps')).toBeNull();
  });

  it("won't sell more than the wallet holds", async () => {
    stubJupiter({});
    await expect(service(0.5).quoteSell(user, TSLA, 1)).rejects.toThrow('You hold 0.5 TSLAx');
    await expect(service().quoteSell(user, TSLA, 0)).rejects.toThrow('greater than zero');
  });

  it('shows what a buy would fetch if sold straight back, revealing a thin market', async () => {
    // A thin pool: $100 buys a share "worth" $100, but selling it back fetches $48.
    stubJupiter({
      [`${USDC}>${TSLA}`]: () => 100_000_000n,
      [`${TSLA}>${USDC}`]: () => 48_000_000n,
    });
    const quote = await service().quote(user, TSLA, 100, 'USDC');
    expect(quote.estimatedShares).toBe(1);
    expect(quote.sellBackAmount).toBe(48);
  });

  it('still quotes a buy when the sell-back check finds no route', async () => {
    stubJupiter({ [`${USDC}>${TSLA}`]: () => 100_000_000n });
    const quote = await service().quote(user, TSLA, 100, 'USDC');
    expect(quote.estimatedShares).toBe(1);
    expect(quote.sellBackAmount).toBeNull();
  });
});
