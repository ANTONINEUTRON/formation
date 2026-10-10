import { rosterShape } from '../domain/sport.js';
import type { RiskTier } from '../domain/sport.js';
import { validateSuggestions } from './suggestions.js';
import type { RosterFacts } from './suggestions.js';

const stock = (symbol: string, tier: RiskTier) => [
  symbol.toUpperCase(),
  { mint: `mint-${symbol}`, symbol, tier },
] as const;

/** Basketball: PG growth, SG growth, SF balanced, PF balanced, C blue_chip. */
function facts(over: Partial<RosterFacts> = {}): RosterFacts {
  return {
    mode: 'basketball',
    formation: null,
    shape: rosterShape('basketball'),
    slots: new Map([
      [0, 'mint-NVDAx'],
      [4, 'mint-AAPLx'],
    ]),
    captainSlot: 0,
    viceCaptainSlot: null,
    held: new Map([
      ['mint-NVDAx', 2],
      ['mint-AAPLx', 1],
      ['mint-METAx', 1],
    ]),
    catalogue: new Map([
      stock('NVDAx', 'growth'),
      stock('METAx', 'growth'),
      stock('AAPLx', 'blue_chip'),
      stock('MSFTx', 'blue_chip'),
      stock('JPMx', 'balanced'),
    ]),
    substitutionsToday: 0,
    ...over,
  };
}

describe('validateSuggestions', () => {
  it('keeps a legal fill and marks whether it must be bought first', () => {
    const out = validateSuggestions(
      [
        { kind: 'fillSlot', slotIndex: 1, symbol: 'metax', reason: 'held, fits SG' },
        { kind: 'fillSlot', slotIndex: 2, symbol: 'JPMx', reason: 'fits SF' },
      ],
      facts(),
    );
    expect(out).toEqual([
      expect.objectContaining({ slotIndex: 1, mint: 'mint-METAx', needsPurchase: false, substitutionCost: 0 }),
      expect.objectContaining({ slotIndex: 2, mint: 'mint-JPMx', needsPurchase: true, substitutionCost: 0 }),
    ]);
  });

  it('drops a stock in the wrong tier, an unknown symbol, or one already on the team', () => {
    expect(
      validateSuggestions(
        [
          { kind: 'fillSlot', slotIndex: 2, symbol: 'MSFTx', reason: 'blue chip in SF' },
          { kind: 'fillSlot', slotIndex: 1, symbol: 'DOGEx', reason: 'not listed' },
          { kind: 'fillSlot', slotIndex: 1, symbol: 'NVDAx', reason: 'already in PG' },
          { kind: 'fillSlot', slotIndex: 9, symbol: 'METAx', reason: 'no such slot' },
        ],
        facts(),
      ),
    ).toEqual([]);
  });

  it('prices substitutions against the free daily allowance, in order', () => {
    const out = validateSuggestions(
      [
        { kind: 'fillSlot', slotIndex: 0, symbol: 'METAx', reason: 'swap PG' },
        { kind: 'fillSlot', slotIndex: 4, symbol: 'MSFTx', reason: 'swap C' },
      ],
      facts({ substitutionsToday: 2 }),
    );
    // The third substitution of the day is free; the fourth costs 4 points.
    expect(out.map((s) => s.kind === 'fillSlot' && s.substitutionCost)).toEqual([0, -4]);
  });

  it('only suggests captaincy the sport has, on a filled slot', () => {
    expect(
      validateSuggestions(
        [
          { kind: 'setCaptain', slotIndex: 4, reason: 'steadier' },
          { kind: 'setCaptain', slotIndex: 4, vice: true, reason: 'basketball has no vice' },
          { kind: 'setCaptain', slotIndex: 2, reason: 'empty slot' },
        ],
        facts(),
      ),
    ).toEqual([{ kind: 'setCaptain', slotIndex: 4, vice: false, reason: 'steadier' }]);
  });

  it('allows formation changes in football only', () => {
    const raw = [{ kind: 'setFormation', formation: '4-3-3', reason: 'more forwards' }];
    expect(validateSuggestions(raw, facts())).toEqual([]);
    expect(
      validateSuggestions(
        raw,
        facts({ mode: 'football', formation: '4-4-2', shape: rosterShape('football', '4-4-2') }),
      ),
    ).toEqual([{ kind: 'setFormation', formation: '4-3-3', reason: 'more forwards' }]);
  });

  it('ignores junk and caps the list at three', () => {
    const many = Array.from({ length: 6 }, () => ({ kind: 'setCaptain', slotIndex: 4, reason: 'x' }));
    expect(validateSuggestions('nope', facts())).toEqual([]);
    expect(validateSuggestions([null, 42, { kind: 'teleport' }], facts())).toEqual([]);
    expect(validateSuggestions(many, facts())).toHaveLength(1);
  });
});
