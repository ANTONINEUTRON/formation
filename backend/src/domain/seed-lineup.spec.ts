import type { ManagerHoldingDto } from './dto.js';
import { lineupFromHoldings } from './seed-lineup.js';
import { rosterShape, slotAccepts } from './sport.js';
import type { RiskTier } from './sport.js';

const holding = (symbol: string, tier: RiskTier, valueUsd: number): ManagerHoldingDto => ({
  stock: {
    symbol,
    companyName: symbol,
    mint: `mint-${symbol}`,
    tier,
    priceUsd: 1,
    change24hPct: 0,
    logoUrl: null,
    notScoring: null,
  },
  balance: valueUsd,
  valueUsd,
  starting: false,
});

describe('lineupFromHoldings', () => {
  const wallet = [
    holding('AAPLx', 'blue_chip', 900),
    holding('MSFTx', 'blue_chip', 400),
    holding('KOx', 'stable', 300),
    holding('JPMx', 'balanced', 250),
    holding('NVDAx', 'growth', 1200),
    holding('TSLAx', 'momentum', 50),
  ];

  it('fills every slot it can with a stock that fits, never the same one twice', () => {
    const { lineup, formation } = lineupFromHoldings('football', wallet);
    const shape = rosterShape('football', formation);
    expect(formation).toBe('4-4-2');
    for (const slot of lineup) expect(slotAccepts(shape[slot.slotIndex], slot.stock!.tier)).toBe(true);
    expect(new Set(lineup.map((s) => s.stock!.mint)).size).toBe(lineup.length);
    // GK, one DEF, two MIDs (balanced or growth) and one FWD.
    expect(lineup.map((s) => s.stock!.symbol).sort()).toEqual(['AAPLx', 'JPMx', 'KOx', 'NVDAx', 'TSLAx']);
  });

  it('covers a scarce tier before spending a flexible stock elsewhere', () => {
    // American football's FLEX takes anything; the only stable stock must go
    // to TE or K, not FLEX.
    const { lineup } = lineupFromHoldings('american_football', wallet);
    const ko = lineup.find((s) => s.stock!.symbol === 'KOx')!;
    expect(['TE', 'K']).toContain(ko.positionLabel);
  });

  it('gives the armbands to the most valuable picks', () => {
    const football = lineupFromHoldings('football', wallet);
    const symbolAt = (slot: number | null) => football.lineup.find((s) => s.slotIndex === slot)?.stock?.symbol;
    expect(symbolAt(football.captainSlot)).toBe('NVDAx');
    expect(symbolAt(football.viceCaptainSlot)).toBe('AAPLx');
    expect(lineupFromHoldings('american_football', wallet).captainSlot).toBeNull();
  });

  it('is empty for an empty wallet', () => {
    expect(lineupFromHoldings('basketball', []).lineup).toEqual([]);
  });
});
