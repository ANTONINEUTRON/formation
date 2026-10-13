import { priceAt } from './metrics.js';
import type { PriceTick } from './types.js';

/**
 * Largest move, relative to the benchmark, one tick may bank. Beyond it the
 * price is held for a tick; a move that persists is then banked clamped to it.
 */
export const MAX_TICK_MOVE = 0.1;

/** Where a guarded series stands after its last tick. */
export interface GuardState {
  /** Last accepted real price. */
  price: number;
  /** The benchmark's price when [price] was accepted. */
  benchmark: number;
  /** Direction of a jump held on the last tick, waiting to be confirmed. 0 if none. */
  pending: -1 | 0 | 1;
}

export interface GuardedSeries {
  /** The series as scoring should see it. */
  ticks: PriceTick[];
  state: GuardState;
  /** True when the last tick was a held jump: it banks nothing for now. */
  held: boolean;
  /** When a jump was confirmed and banked clamped. */
  jumps: number[];
}

/**
 * Filters one pick's price series so a broken price can't decide a score.
 *
 * Each tick is compared with where the pick would be had it simply tracked the
 * benchmark since the last accepted price:
 * - within [maxMove]: accepted as is;
 * - beyond it, the first time: held. The tick is shown as tracking the
 *   benchmark, so it banks no alpha, and the baseline stays put. A spike that
 *   reverts on the next tick never banks anything;
 * - beyond it again in the same direction: confirmed. The move banks clamped to
 *   [maxMove], and the baseline moves to the real price.
 *
 * Clamping makes the returned series drift from the real one, so it carries a
 * scale factor from then on; returns from it are what matters, not levels.
 */
export function guardSeries(
  ticks: PriceTick[],
  benchmark: PriceTick[],
  seed: GuardState,
  maxMove = MAX_TICK_MOVE,
): GuardedSeries {
  let { price, benchmark: bench, pending } = seed;
  let scale = 1;
  let held = false;
  const out: PriceTick[] = [];
  const jumps: number[] = [];

  for (const tick of ticks) {
    const benchNow = priceAt(benchmark, tick.at, bench);
    if (price <= 0 || bench <= 0 || benchNow <= 0) {
      // Nothing to judge against yet: take the tick as the baseline.
      price = tick.price;
      bench = benchNow;
      pending = 0;
      held = false;
      out.push({ at: tick.at, price: tick.price * scale });
      continue;
    }

    const expected = price * (benchNow / bench);
    const move = tick.price / expected - 1;
    const direction = Math.sign(move) as -1 | 1;

    if (Math.abs(move) <= maxMove) {
      price = tick.price;
      bench = benchNow;
      pending = 0;
      held = false;
      out.push({ at: tick.at, price: price * scale });
    } else if (pending === direction) {
      const clamped = expected * (1 + direction * maxMove);
      scale *= clamped / tick.price;
      price = tick.price;
      bench = benchNow;
      pending = 0;
      held = false;
      jumps.push(tick.at);
      out.push({ at: tick.at, price: price * scale });
    } else {
      pending = direction;
      held = true;
      out.push({ at: tick.at, price: expected * scale });
    }
  }

  return { ticks: out, state: { price, benchmark: bench, pending }, held, jumps };
}
