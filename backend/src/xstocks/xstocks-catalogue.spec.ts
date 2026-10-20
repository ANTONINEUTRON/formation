import { afterEach, describe, expect, it, vi } from 'vitest';
import { uniqueSymbols, XStocksCatalogueService } from './xstocks-catalogue.service.js';
import type { Listing } from './xstocks-catalogue.service.js';
import { RISK_TIERS } from '../domain/sport.js';
import type { RiskTier } from '../domain/sport.js';

const BACKED = '7pt9tkctJPK7PPNQJ77GKg8ZffSF6QxoMiCFYHxrtaCj';

interface Token {
  id: string;
  name: string;
  symbol: string;
  decimals: number;
  mintAuthority?: string;
  isVerified?: boolean;
  liquidity?: number;
  mcap?: number;
}

const token = (over: Partial<Token> & { symbol: string }): Token => ({
  id: `mint-${over.symbol}`,
  name: `${over.symbol.replace(/x$/, '')} xStock`,
  decimals: 8,
  mintAuthority: BACKED,
  isVerified: true,
  liquidity: 100_000,
  mcap: 1_000_000,
  ...over,
});

/** A Token as the table wants it, for the tier and de-duplication steps. */
const listing = (t: Token, over: Partial<Listing> = {}): Listing => ({
  mint: t.id,
  symbol: t.symbol,
  companyName: t.name.replace(/\s*xStock$/i, ''),
  decimals: t.decimals,
  logoUrl: null,
  liquidity: t.liquidity ?? 0,
  issuer: 'xstocks',
  ...over,
});

/**
 * `accept`, `assignTiers` and `backpack` are private because nothing outside
 * the service should call them, but they are the parts that decide what
 * players can buy and where it can be played, so they are worth testing
 * directly. [existing] stands in for the rows already listed.
 */
const build = (minLiquidity = 0, existing: { symbol: string; tier: RiskTier }[] = []) => {
  const db = { selectFrom: () => ({ select: () => ({ execute: async () => existing }) }) };
  const service = new XStocksCatalogueService(
    db as never,
    {
      catalogueMinLiquidityUsd: minLiquidity,
      backpackApiUrl: 'https://bp.test',
      jupiterApiUrl: 'https://jup.test',
      jupiterHeaders: { 'x-api-key': 'k' },
    } as never,
    null as never,
    null as never,
  );
  const inner = service as unknown as {
    accept(tokens: Token[]): Token[];
    assignTiers(listings: Listing[]): Promise<Map<string, RiskTier>>;
    backpack(): Promise<{ candidates: number; listings: Listing[] }>;
  };
  return {
    accept: (tokens: Token[]) => inner.accept(tokens).map((t) => t.symbol),
    tiers: (tokens: Token[]) => inner.assignTiers(tokens.map((t) => listing(t))),
    tiersOf: (listings: Listing[]) => inner.assignTiers(listings),
    backpack: () => inner.backpack(),
  };
};

describe('xStocks catalogue filtering', () => {
  it('rejects a token that is not minted by Backed, however convincing', () => {
    // The whole attack: mint your own AAPLx against a pool you control and let
    // the catalogue present it as Apple. The name and symbol are free to copy;
    // the mint authority is not.
    const { accept } = build();
    expect(
      accept([
        token({ symbol: 'AAPLx' }),
        token({ symbol: 'FAKEx', mintAuthority: 'ImPoStoR1111111111111111111111111111111111' }),
        token({ symbol: 'NOAUTHx', mintAuthority: undefined }),
      ]),
    ).toEqual(['AAPLx']);
  });

  it('rejects a token Jupiter has explicitly not verified', () => {
    const { accept } = build();
    expect(accept([token({ symbol: 'OKx' }), token({ symbol: 'BADx', isVerified: false })])).toEqual(
      ['OKx'],
    );
  });

  it('rejects nonsense decimals rather than mis-scaling a purchase', () => {
    const { accept } = build();
    expect(
      accept([
        token({ symbol: 'GOODx' }),
        token({ symbol: 'FRACTIONALx', decimals: 8.5 }),
        token({ symbol: 'NEGATIVEx', decimals: -1 }),
      ]),
    ).toEqual(['GOODx']);
  });

  it('lists everything by default, and applies a floor when one is set', () => {
    const thin = token({ symbol: 'THINx', liquidity: 4 });
    const deep = token({ symbol: 'DEEPx', liquidity: 500_000 });
    expect(build(0).accept([thin, deep]).sort()).toEqual(['DEEPx', 'THINx']);
    expect(build(1_000).accept([thin, deep])).toEqual(['DEEPx']);
  });

  it('keeps the deeper pool when two mints claim the same ticker', () => {
    // `symbol` is unique in the table, so a duplicate would fail the whole
    // upsert and leave the catalogue unchanged.
    const shallow = listing({ ...token({ symbol: 'DUPx' }), id: 'mint-shallow', liquidity: 10 });
    const deep = listing({ ...token({ symbol: 'DUPx' }), id: 'mint-deep', liquidity: 900 });
    expect(uniqueSymbols([shallow, deep]).map((l) => l.mint)).toEqual(['mint-deep']);
  });
});

describe('xStocks catalogue starting tiers', () => {
  it('starts a seeded stock in its seed tier', async () => {
    const { tiers } = build();
    const tsla = token({ symbol: 'TSLAx' });
    const ko = token({ symbol: 'KOx' });
    const assigned = await tiers([tsla, ko]);
    expect(assigned.get(tsla.id)).toBe('momentum');
    expect(assigned.get(ko.id)).toBe('blue_chip');
  });

  it('places leveraged and T-bill funds by what they are', async () => {
    const { tiers } = build();
    const lev = token({ symbol: 'TQQQx' });
    const bills = token({ symbol: 'SGOVx' });
    const assigned = await tiers([lev, bills]);
    expect(assigned.get(lev.id)).toBe('momentum');
    expect(assigned.get(bills.id)).toBe('blue_chip');
  });

  it('starts anything else as balanced, whatever its pool, until the formula measures it', async () => {
    // Pool depth says how easy a stock is to trade, not how risky it is.
    const { tiers } = build();
    const deep = token({ symbol: 'DEEPx', liquidity: 5_000_000 });
    const thin = token({ symbol: 'THINx', liquidity: 4 });
    const assigned = await tiers([deep, thin]);
    expect(assigned.get(deep.id)).toBe('balanced');
    expect(assigned.get(thin.id)).toBe('balanced');
    expect(RISK_TIERS).toContain(assigned.get(deep.id));
  });

  it("starts a Backpack stock where the same company's xStock already plays", async () => {
    const { tiersOf } = build(0, [{ symbol: 'NVDAx', tier: 'momentum' }]);
    const nvda = listing(token({ symbol: 'NVDA' }), { mint: 'bp-NVDA', issuer: 'backpack' });
    const fresh = listing(token({ symbol: 'ZZZZ' }), { mint: 'bp-ZZZZ', issuer: 'backpack' });
    const assigned = await tiersOf([nvda, fresh]);
    expect(assigned.get('bp-NVDA')).toBe('momentum');
    expect(assigned.get('bp-ZZZZ')).toBe('balanced');
  });
});

describe('Backpack listings', () => {
  afterEach(() => vi.unstubAllGlobals());

  /** Backpack's asset list, Jupiter's prices, and Jupiter's search for icons. */
  function stub(assets: unknown[], prices: Record<string, unknown>, icons: unknown[] = []) {
    vi.stubGlobal(
      'fetch',
      vi.fn(async (url: string) => {
        if (url.startsWith('https://bp.test/api/v1/assets')) return new Response(JSON.stringify(assets));
        if (url.startsWith('https://jup.test/price/v3')) return new Response(JSON.stringify(prices));
        if (url.startsWith('https://jup.test/tokens/v2/search')) return new Response(JSON.stringify(icons));
        return new Response('not found', { status: 404 });
      }),
    );
  }
  const asset = (symbol: string, mint: string | null, decimals: number | undefined = 6, blockchain = 'Solana') => ({
    symbol,
    displayName: `${symbol} Inc.`,
    tokens: [{ blockchain, contractAddress: mint, nativeDecimals: decimals }],
  });
  const MINT = (n: number) => `Mint${String(n).padStart(40, '1')}`;

  it("lists Backpack's US stocks that Jupiter can price, by their plain ticker", async () => {
    stub(
      [
        asset('AMD.US', MINT(1)),
        asset('BLK.US', MINT(2)),
        asset('UNPRICED.US', MINT(3)), // no Jupiter price: can't be bought, so not listed
        asset('BTC', MINT(4)), // not a stock
        asset('ETHONLY.US', MINT(5), 6, 'Ethereum'), // no Solana token
        asset('NOMINT.US', null),
        asset('BADDEC.US', MINT(6), 6.5),
      ],
      {
        [MINT(1)]: { usdPrice: 527, liquidity: 170_000 },
        [MINT(2)]: { usdPrice: 950, liquidity: 130_000 },
        [MINT(4)]: { usdPrice: 60_000, liquidity: 1e9 },
        [MINT(6)]: { usdPrice: 10, liquidity: 1e6 },
      },
      [{ id: MINT(1), icon: 'https://icons/amd.png' }],
    );
    const { candidates, listings } = await build().backpack();
    expect(candidates).toBe(3); // AMD, BLK and UNPRICED: a US stock with a Solana mint and sane decimals
    expect(listings).toEqual([
      {
        mint: MINT(1),
        symbol: 'AMD',
        companyName: 'AMD.US Inc.',
        decimals: 6,
        logoUrl: 'https://icons/amd.png',
        liquidity: 170_000,
        issuer: 'backpack',
      },
      {
        mint: MINT(2),
        symbol: 'BLK',
        companyName: 'BLK.US Inc.',
        decimals: 6,
        logoUrl: null,
        liquidity: 130_000,
        issuer: 'backpack',
      },
    ]);
  });

  it('applies the same liquidity floor as xStocks', async () => {
    stub([asset('THIN.US', MINT(1)), asset('DEEP.US', MINT(2))], {
      [MINT(1)]: { usdPrice: 5, liquidity: 50 },
      [MINT(2)]: { usdPrice: 5, liquidity: 50_000 },
    });
    const { listings } = await build(1_000).backpack();
    expect(listings.map((l) => l.symbol)).toEqual(['DEEP']);
  });
});
