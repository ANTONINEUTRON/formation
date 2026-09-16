import { defaultLineup, parseLineup, slotMeta } from './lineup.js';

describe('parseLineup', () => {
  const valid = () => ({ ...defaultLineup('football')!, captain: 12, viceCaptain: 0 });

  it('accepts the default 4-4-2 with armbands', () => {
    expect(parseLineup('football', valid())).toEqual(valid());
  });

  it('accepts a 5-4-1', () => {
    const lineup = { ...valid(), starters: [0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12], bench: [1, 11, 13, 14] };
    expect(parseLineup('football', lineup).starters).toContain(6);
  });

  it('rejects an invalid formation', () => {
    // 2 defenders, 5 midfielders, 3 forwards
    const lineup = { ...valid(), starters: [0, 2, 3, 7, 8, 9, 10, 11, 12, 13, 14], bench: [1, 4, 5, 6] };
    expect(() => parseLineup('football', lineup)).toThrow('2-5-3');
  });

  it('rejects a captain on the bench', () => {
    expect(() => parseLineup('football', { ...valid(), captain: 14 })).toThrow('captain');
  });

  it('rejects lineups outside football', () => {
    expect(() => parseLineup('basketball', valid())).toThrow('Only football');
  });
});

describe('slotMeta', () => {
  it('weights captain, starters and bench for football', () => {
    const lineup = { ...defaultLineup('football')!, captain: 12, viceCaptain: 0 };
    const meta = slotMeta(
      'football',
      [
        { slot_index: 12, token_mint: 'TSLA' },
        { slot_index: 0, token_mint: 'AAPL' },
        { slot_index: 14, token_mint: 'PLTR' },
      ],
      lineup,
    );
    expect(meta).toEqual([
      { token_mint: 'TSLA', weight: 2, role: 'FWD', bench_order: null, is_vice: false },
      { token_mint: 'AAPL', weight: 1, role: 'GK', bench_order: null, is_vice: true },
      { token_mint: 'PLTR', weight: 0, role: 'FWD', bench_order: 3, is_vice: false },
    ]);
  });

  it('weights every slot equally in other sports', () => {
    expect(slotMeta('basketball', [{ slot_index: 0, token_mint: 'NVDA' }], null)).toEqual([
      { token_mint: 'NVDA', weight: 1, role: null, bench_order: null, is_vice: false },
    ]);
  });
});
