import {
  changeBetween,
  longestGreenRun,
  lowestRelative,
  priceAt,
  round1,
  sessionReturns,
  sessionWindows,
} from './metrics.js';
import type { PriceTick, ScoreWindow } from './types.js';

const MINUTE = 60_000;
const ticks = (...pairs: [number, number][]): PriceTick[] =>
  pairs.map(([at, price]) => ({ at, price }));

const window: ScoreWindow = { start: 0, end: 60 * MINUTE, sessionMinutes: 20 };

describe('round1', () => {
  it('rounds half away from zero', () => {
    expect(round1(1.25)).toBe(1.3);
    expect(round1(-1.25)).toBe(-1.3);
    expect(round1(0)).toBe(0);
  });
});

describe('priceAt', () => {
  const series = ticks([0, 100], [10 * MINUTE, 110], [30 * MINUTE, 90]);

  it('uses the last tick at or before the moment', () => {
    expect(priceAt(series, 20 * MINUTE, 1)).toBe(110);
    expect(priceAt(series, 30 * MINUTE, 1)).toBe(90);
  });

  it('falls back to the given price before history starts', () => {
    expect(priceAt(ticks([50 * MINUTE, 120]), 0, 5)).toBe(5);
  });

  it('falls back to the given price with no history', () => {
    expect(priceAt([], 0, 42)).toBe(42);
  });
});

describe('changeBetween', () => {
  it('is a fraction, and zero when the start price is unusable', () => {
    expect(changeBetween(100, 103)).toBeCloseTo(0.03, 9);
    expect(changeBetween(0, 103)).toBe(0);
  });
});

describe('sessionWindows', () => {
  it('splits the window and truncates the last bucket', () => {
    const buckets = sessionWindows({ start: 0, end: 50 * MINUTE, sessionMinutes: 20 });
    expect(buckets).toEqual([
      { start: 0, end: 20 * MINUTE },
      { start: 20 * MINUTE, end: 40 * MINUTE },
      { start: 40 * MINUTE, end: 50 * MINUTE },
    ]);
  });

  it('always returns at least one bucket', () => {
    expect(sessionWindows({ start: 0, end: 0, sessionMinutes: 20 })).toHaveLength(1);
  });
});

describe('sessionReturns', () => {
  it('opens each session at the previous price and closes at its end', () => {
    const series = ticks([0, 100], [25 * MINUTE, 110], [45 * MINUTE, 99]);
    const sessions = sessionReturns(series, window, 100);
    expect(sessions).toHaveLength(3);
    expect(sessions[0].change).toBeCloseTo(0, 9); // no tick before 20m other than the open
    expect(sessions[1].change).toBeCloseTo(0.1, 9); // 100 → 110
    expect(sessions[2].change).toBeCloseTo(-0.1, 9); // 110 → 99
  });
});

describe('lowestRelative', () => {
  it('reports the deepest dip against the opening price', () => {
    const series = ticks([10 * MINUTE, 95], [20 * MINUTE, 105]);
    expect(lowestRelative(series, window, 100)).toBeCloseTo(0.95, 9);
  });

  it('ignores ticks outside the window and never exceeds 1', () => {
    expect(lowestRelative(ticks([120 * MINUTE, 50]), window, 100)).toBe(1);
  });
});

describe('longestGreenRun', () => {
  it('counts the longest run of rises', () => {
    expect(longestGreenRun([1, 2, 3, 2, 3, 4, 5])).toBe(3);
    expect(longestGreenRun([3, 2, 1])).toBe(0);
    expect(longestGreenRun([])).toBe(0);
  });
});
