import { XStocksCatalogueService } from './xstocks-catalogue.service.js';
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

/**
 * `accept` and `assignTiers` are private because nothing outside the service
 * should call them, but they are the parts that decide what players can buy and
 * where it can be played, so they are worth testing directly.
 */
const build = (minLiquidity = 0) => {
  const service = new XStocksCatalogueService(
    null as never,
    { catalogueMinLiquidityUsd: minLiquidity } as never,
    null as never,
    null as never,
  );
  const inner = service as unknown as {
    accept(tokens: Token[]): Token[];
    assignTiers(tokens: Token[]): Map<string, RiskTier>;
  };
  return {
    accept: (tokens: Token[]) => inner.accept(tokens).map((t) => t.symbol),
    tiers: (tokens: Token[]) => inner.assignTiers(tokens),
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
    const { accept } = build();
    const shallow = { ...token({ symbol: 'DUPx' }), id: 'mint-shallow', liquidity: 10 };
    const deep = { ...token({ symbol: 'DUPx' }), id: 'mint-deep', liquidity: 900 };
    expect(accept([shallow, deep])).toEqual(['DUPx']);
  });
});

describe('xStocks catalogue tiering', () => {
  it('keeps the hand-assigned tier for a curated stock', () => {
    // Tesla is a mega-cap that plays as momentum; market cap cannot derive that,
    // so the curated placement has to win.
    const { tiers } = build();
    const tsla = token({ symbol: 'TSLAx', mcap: 9e12 });
    const aapl = token({ symbol: 'AAPLx', mcap: 9e12 });
    const assigned = tiers([tsla, aapl]);
    expect(assigned.get(tsla.id)).toBe('momentum');
    expect(assigned.get(aapl.id)).toBe('blue_chip');
  });

  it('bands uncurated stocks by liquidity, deepest into blue_chip', () => {
    const { tiers } = build();
    const tokens = Array.from({ length: 10 }, (_, i) =>
      token({ symbol: `NEW${String(i)}x`, liquidity: (10 - i) * 1_000 }),
    );
    const assigned = tiers(tokens);
    expect(assigned.get(tokens[0].id)).toBe('blue_chip');
    expect(assigned.get(tokens[9].id)).toBe('momentum');
    // Two per band across five tiers, and every stock placed.
    expect(assigned.size).toBe(10);
    expect(new Set(assigned.values())).toEqual(new Set(RISK_TIERS));
  });

  it('does not let a distorted market cap buy a blue_chip slot', () => {
    // A near-empty pool makes the price, and therefore the market cap,
    // meaningless. Ranking on market cap would put this junk in the anchor
    // slots; ranking on liquidity puts it where its risk belongs.
    const { tiers } = build();
    const junk = token({ symbol: 'JUNKx', liquidity: 4, mcap: 9e15 });
    const real = token({ symbol: 'REALx', liquidity: 2_000_000, mcap: 1e9 });
    const assigned = tiers([junk, real]);
    expect(assigned.get(real.id)).toBe('blue_chip');
    expect(assigned.get(junk.id)).not.toBe('blue_chip');
  });

  it('gives every stock a tier even when there are fewer than one per band', () => {
    const { tiers } = build();
    const tokens = [token({ symbol: 'ONLYx' })];
    const assigned = tiers(tokens);
    expect(RISK_TIERS).toContain(assigned.get(tokens[0].id));
  });
});
