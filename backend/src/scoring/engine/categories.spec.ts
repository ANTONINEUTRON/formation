import { basketballCategories, sideStats, teamIndex } from './categories.js';
import type { EntryBreakdown, PriceBook, ScoreWindow, SideStats, SnapshotSlot } from './types.js';
import type { SideStats as Stats } from './categories.js';

const HOUR = 3_600_000;
const window: ScoreWindow = { start: 0, end: 5 * HOUR, sessionMinutes: 60 };

const stats = (overrides: Partial<Stats> = {}): Stats => ({
  alpha: 0,
  hitRate: 0.5,
  bestPick: 0.01,
  defense: -0.01,
  hotHand: 2,
  points: 10,
  ...overrides,
});

describe('sideStats', () => {
  it('summarises a breakdown, ignoring picks that did not count', () => {
    const breakdown = {
      total: 42,
      teamEvents: [],
      slots: [
        { counted: true, ownReturn: 0.03, alpha: 0.02 },
        { counted: true, ownReturn: -0.01, alpha: -0.02 },
        { counted: false, ownReturn: 0.5, alpha: 0.5 },
      ],
    } as unknown as EntryBreakdown;

    expect(sideStats(breakdown, [1, 1.01, 1.02])).toEqual({
      alpha: 0,
      hitRate: 0.5,
      bestPick: 0.03,
      defense: -0.01,
      hotHand: 2,
      points: 42,
    });
  });
});

describe('teamIndex', () => {
  it('averages each pick against its own start price', () => {
    const slots = [
      { mint: 'A', startPrice: 100 },
      { mint: 'B', startPrice: 50 },
    ] as SnapshotSlot[];
    const prices: PriceBook = new Map([
      ['A', [{ at: HOUR, price: 110 }]],
      ['B', [{ at: 2 * HOUR, price: 45 }]],
    ]);
    // At 1h: A 1.10, B 1.00 → 1.05. At 2h: A 1.10, B 0.90 → 1.00.
    expect(teamIndex(slots, prices, window)).toEqual([1.05, 1]);
  });
});

describe('basketballCategories', () => {
  it('gives the duel to whoever wins more categories', () => {
    // Challenger takes alpha and hit rate; opponent takes best pick,
    // defense and hot hand, so the opponent wins 3-2.
    const result = basketballCategories(
      stats({ alpha: 0.02, hitRate: 0.8, bestPick: 0.05, defense: -0.05, hotHand: 1 }),
      stats({ alpha: 0.01, hitRate: 0.6, bestPick: 0.09, defense: -0.01, hotHand: 4 }),
    );
    expect(result.categories.filter((c) => c.winner === 'challenger')).toHaveLength(2);
    expect(result.categories.filter((c) => c.winner === 'opponent')).toHaveLength(3);
    expect(result.winner).toBe('opponent');
  });

  it('names the category winners', () => {
    const result = basketballCategories(
      stats({ alpha: 0.03, hitRate: 1, bestPick: 0.1, defense: 0, hotHand: 5 }),
      stats(),
    );
    expect(result.winner).toBe('challenger');
    expect(result.categories.map((c) => c.name)).toEqual([
      'Alpha',
      'Hit rate',
      'Best pick',
      'Defense',
      'Hot hand',
    ]);
  });

  it('falls back to points when categories are level', () => {
    const level = stats();
    expect(basketballCategories(stats({ ...level, points: 30 }), level).winner).toBe('challenger');
    expect(basketballCategories(level, level).winner).toBe('tie');
  });
});
