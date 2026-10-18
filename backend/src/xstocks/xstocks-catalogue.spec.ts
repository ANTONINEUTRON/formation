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

describe('xStocks catalogue starting tiers', () => {
  it('starts a seeded stock in its seed tier', () => {
    const { tiers } = build();
    const tsla = token({ symbol: 'TSLAx' });
    const ko = token({ symbol: 'KOx' });
    const assigned = tiers([tsla, ko]);
    expect(assigned.get(tsla.id)).toBe('momentum');
    expect(assigned.get(ko.id)).toBe('blue_chip');
  });

  it('places leveraged and T-bill funds by what they are', () => {
    const { tiers } = build();
    const lev = token({ symbol: 'TQQQx' });
    const bills = token({ symbol: 'SGOVx' });
    const assigned = tiers([lev, bills]);
    expect(assigned.get(lev.id)).toBe('momentum');
    expect(assigned.get(bills.id)).toBe('blue_chip');
  });

  it('starts anything else as balanced, whatever its pool, until the formula measures it', () => {
    // Pool depth says how easy a stock is to trade, not how risky it is.
    const { tiers } = build();
    const deep = token({ symbol: 'DEEPx', liquidity: 5_000_000 });
    const thin = token({ symbol: 'THINx', liquidity: 4 });
    const assigned = tiers([deep, thin]);
    expect(assigned.get(deep.id)).toBe('balanced');
    expect(assigned.get(thin.id)).toBe('balanced');
    expect(RISK_TIERS).toContain(assigned.get(deep.id));
  });
});
