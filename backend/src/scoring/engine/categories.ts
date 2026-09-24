import { longestGreenRun, priceAt } from './metrics.js';
import type { EntryBreakdown, PriceBook, ScoreWindow, SnapshotSlot } from './types.js';

/** One head-to-head category in a basketball duel. Higher always wins. */
export interface CategoryResult {
  code: string;
  name: string;
  challenger: number;
  opponent: number;
  winner: 'challenger' | 'opponent' | 'tie';
}

export interface SideStats {
  /** Average alpha across counted picks. */
  alpha: number;
  /** Share of counted picks that finished green. */
  hitRate: number;
  bestPick: number;
  /** Worst pick's return: the higher (less bad) team wins. */
  defense: number;
  /** Longest run of rising ticks for the team as a whole. */
  hotHand: number;
  points: number;
}

/**
 * Team price index: the average of each pick's price relative to its start,
 * sampled at every tick time in the window.
 */
export function teamIndex(
  slots: SnapshotSlot[],
  prices: PriceBook,
  window: ScoreWindow,
): number[] {
  const times = new Set<number>();
  for (const slot of slots) {
    for (const tick of prices.get(slot.mint) ?? []) {
      if (tick.at >= window.start && tick.at <= window.end) times.add(tick.at);
    }
  }
  const counted = slots.filter((s) => s.startPrice > 0);
  if (counted.length === 0) return [];

  return [...times]
    .sort((a, b) => a - b)
    .map((at) =>
      counted.reduce(
        (sum, slot) =>
          sum + priceAt(prices.get(slot.mint) ?? [], at, slot.startPrice) / slot.startPrice,
        0,
      ) / counted.length,
    );
}

export function sideStats(breakdown: EntryBreakdown, index: number[]): SideStats {
  const counted = breakdown.slots.filter((s) => s.counted);
  const returns = counted.map((s) => s.ownReturn);
  const average = (values: number[]) =>
    values.length === 0 ? 0 : values.reduce((a, b) => a + b, 0) / values.length;

  return {
    alpha: average(counted.map((s) => s.alpha)),
    hitRate: counted.length === 0 ? 0 : returns.filter((r) => r > 0).length / counted.length,
    bestPick: returns.length === 0 ? 0 : Math.max(...returns),
    defense: returns.length === 0 ? 0 : Math.min(...returns),
    hotHand: longestGreenRun(index),
    points: breakdown.total,
  };
}

const CATEGORIES: { code: keyof SideStats; name: string }[] = [
  { code: 'alpha', name: 'Alpha' },
  { code: 'hitRate', name: 'Hit rate' },
  { code: 'bestPick', name: 'Best pick' },
  { code: 'defense', name: 'Defense' },
  { code: 'hotHand', name: 'Hot hand' },
];

/**
 * Basketball duels are won on categories, like fantasy basketball's 9-cat
 * (docs/formation-scoring.md §5.3). A category tie falls back to points.
 */
export function basketballCategories(
  challenger: SideStats,
  opponent: SideStats,
): { categories: CategoryResult[]; winner: 'challenger' | 'opponent' | 'tie' } {
  const round4 = (n: number) => Math.round(n * 10_000) / 10_000;
  const categories = CATEGORIES.map(({ code, name }) => {
    const a = challenger[code];
    const b = opponent[code];
    return {
      code,
      name,
      challenger: round4(a),
      opponent: round4(b),
      winner: a > b ? ('challenger' as const) : b > a ? ('opponent' as const) : ('tie' as const),
    };
  });

  const won = (side: 'challenger' | 'opponent') =>
    categories.filter((c) => c.winner === side).length;
  const challengerWins = won('challenger');
  const opponentWins = won('opponent');

  if (challengerWins !== opponentWins) {
    return { categories, winner: challengerWins > opponentWins ? 'challenger' : 'opponent' };
  }
  if (challenger.points !== opponent.points) {
    return { categories, winner: challenger.points > opponent.points ? 'challenger' : 'opponent' };
  }
  return { categories, winner: 'tie' };
}
