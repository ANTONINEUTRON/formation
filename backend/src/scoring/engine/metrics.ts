import type { PriceTick, ScoreWindow, SessionReturn } from './types.js';

/** Rounds to one decimal, half away from zero (points are numeric(10,1)). */
export const round1 = (n: number): number =>
  Math.sign(n) * Math.round(Math.abs(n) * 10) / 10;

/**
 * Price at a moment: the last tick at or before [at], or [fallback] when
 * history doesn't reach back that far. Callers pass the price the window
 * opened at, so gaps in history never crash a scoring run.
 */
export function priceAt(ticks: PriceTick[], at: number, fallback: number): number {
  let price = fallback;
  for (const tick of ticks) {
    if (tick.at > at) break;
    price = tick.price;
  }
  return price;
}

/** Fraction change between two prices; 0 when the start price is unusable. */
export const changeBetween = (from: number, to: number): number =>
  from > 0 ? (to - from) / from : 0;

/**
 * Splits a window into session ("day") buckets. The last bucket is truncated
 * at the window end, so a part-day still counts.
 */
export function sessionWindows(window: ScoreWindow): { start: number; end: number }[] {
  const length = Math.max(1, window.sessionMinutes) * 60_000;
  const buckets: { start: number; end: number }[] = [];
  for (let start = window.start; start < window.end; start += length) {
    buckets.push({ start, end: Math.min(start + length, window.end) });
  }
  return buckets.length > 0 ? buckets : [{ start: window.start, end: window.end }];
}

/** Open, close and change for each session bucket. */
export function sessionReturns(
  ticks: PriceTick[],
  window: ScoreWindow,
  openingPrice: number,
): SessionReturn[] {
  return sessionWindows(window).map(({ start, end }) => {
    const open = priceAt(ticks, start, openingPrice);
    const close = priceAt(ticks, end, open);
    return { start, end, open, close, change: changeBetween(open, close) };
  });
}

/** Lowest price in the window relative to [openingPrice] (1 = never dropped). */
export function lowestRelative(
  ticks: PriceTick[],
  window: ScoreWindow,
  openingPrice: number,
): number {
  if (openingPrice <= 0) return 1;
  let lowest = openingPrice;
  for (const tick of ticks) {
    if (tick.at < window.start || tick.at > window.end) continue;
    if (tick.price < lowest) lowest = tick.price;
  }
  return lowest / openingPrice;
}

/** Longest run of consecutive rises in a series (the "hot hand"). */
export function longestGreenRun(series: number[]): number {
  let best = 0;
  let run = 0;
  for (let i = 1; i < series.length; i++) {
    if (series[i] > series[i - 1]) {
      run++;
      best = Math.max(best, run);
    } else {
      run = 0;
    }
  }
  return best;
}
