import { scoreSnapshots, scoreWindow, SlotWindow } from './score-window.js';

const slot = (overrides: Partial<SlotWindow> = {}): SlotWindow => ({
  startBalance: 1,
  endBalance: 1,
  startPrice: 100,
  endPrice: 100,
  ...overrides,
});

describe('scoreWindow', () => {
  it('averages slot returns and converts to basis points', () => {
    const s = scoreWindow([slot({ endPrice: 102 }), slot({ endPrice: 99 })]);
    expect(s.returnPct).toBeCloseTo(0.005, 9);
    expect(s.points).toBe(50);
  });

  it('scores negative returns as negative points', () => {
    expect(scoreWindow([slot({ endPrice: 97 })]).points).toBe(-300);
  });

  it('excludes a slot sold to zero', () => {
    const s = scoreWindow([
      slot({ endPrice: 110, endBalance: 0 }),
      slot({ endPrice: 101 }),
    ]);
    expect(s.points).toBe(100);
  });

  it('gives no credit for a balance bought mid-window', () => {
    expect(
      scoreWindow([slot({ startBalance: 0, endBalance: 50, endPrice: 150 })])
        .points,
    ).toBe(0);
  });

  it('scores an empty roster as zero', () => {
    expect(scoreWindow([])).toEqual({ returnPct: 0, points: 0 });
  });

  it('keeps magnitude independent of roster size', () => {
    const five = scoreWindow(Array.from({ length: 5 }, () => slot({ endPrice: 101 })));
    const eleven = scoreWindow(Array.from({ length: 11 }, () => slot({ endPrice: 101 })));
    expect(five.points).toBe(eleven.points);
  });

  it('rounds gains and losses symmetrically', () => {
    expect(scoreWindow([slot({ endPrice: 100.03 })]).points).toBe(3);
    expect(scoreWindow([slot({ endPrice: 99.97 })]).points).toBe(-3);
  });
});

describe('scoreWindow with captaincy and bench', () => {
  it('counts the captain double', () => {
    // (2 × 2% + 0%) / 3
    expect(scoreWindow([slot({ endPrice: 102, weight: 2 }), slot()]).points).toBe(133);
  });

  it('gives the vice-captain the double when the captain is sold', () => {
    const s = scoreWindow([
      slot({ endPrice: 110, weight: 2, endBalance: 0 }),
      slot({ endPrice: 103, isViceCaptain: true }),
      slot(),
    ]);
    expect(s.points).toBe(200);
  });

  it('auto-subs like-for-like in bench order and ignores other substitutes', () => {
    const s = scoreWindow([
      slot({ endPrice: 90, endBalance: 0, role: 'DEF' }),
      slot({ role: 'MID' }),
      slot({ endPrice: 150, weight: 0, role: 'MID', benchOrder: 1 }),
      slot({ endPrice: 101, weight: 0, role: 'DEF', benchOrder: 2 }),
      slot({ endPrice: 120, weight: 0, role: 'DEF', benchOrder: 3 }),
    ]);
    expect(s.points).toBe(50);
  });
});

describe('scoreSnapshots', () => {
  it('treats a mint missing from the end snapshot as sold', () => {
    const s = scoreSnapshots(
      [
        { token_mint: 'A', balance: 1, price_usd: 10 },
        { token_mint: 'B', balance: 1, price_usd: 10 },
      ],
      [{ token_mint: 'A', balance: 1, price_usd: 11 }],
    );
    expect(s.points).toBe(1000);
  });

  it('ignores mints added after the start snapshot', () => {
    const s = scoreSnapshots(
      [{ token_mint: 'A', balance: 1, price_usd: 10 }],
      [
        { token_mint: 'A', balance: 1, price_usd: 10 },
        { token_mint: 'C', balance: 5, price_usd: 20 },
      ],
    );
    expect(s.points).toBe(0);
  });
});
