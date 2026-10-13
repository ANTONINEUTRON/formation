import { guardSeries, MAX_TICK_MOVE } from './guard.js';
import { priceAt } from './metrics.js';
import type { PriceTick } from './types.js';

const HOUR = 3_600_000;

/** Trailing period every requirement is measured over. */
export const ELIGIBILITY_WINDOW_MS = 24 * HOUR;
/** How long an asset must pass every requirement before it scores again. */
export const ELIGIBILITY_HYSTERESIS_MS = 24 * HOUR;
/** Share of ticks a priced asset must move on while its benchmark moved. */
export const MIN_PRICE_UPDATE_RATIO = 0.5;
/** Below this many benchmark moves the update check can't tell, so it passes. */
const MIN_BENCHMARK_MOVES = 6;
/** Confirmed jumps tolerated in the window; more means the price is unreliable. */
const MAX_JUMPS = 1;

/** Why an asset isn't scoring. Shown to Managers as "Not scoring: <label>". */
export type NotScoringReason =
  | 'no_price'
  | 'stale_price'
  | 'price_not_updating'
  | 'thin_liquidity'
  | 'erratic_price'
  | 'recovering';

export const NOT_SCORING_LABELS: Record<NotScoringReason, string> = {
  no_price: 'no price',
  stale_price: 'stale price',
  price_not_updating: 'price not updating',
  thin_liquidity: 'thin liquidity',
  erratic_price: 'erratic price',
  recovering: 'price recovering',
};

export interface AssessInput {
  /** The asset's ticks over the trailing window, oldest first. */
  ticks: PriceTick[];
  /** Its benchmark's ticks over the same window. */
  benchmark: PriceTick[];
  now: number;
  tickMinutes: number;
  /** Pool depth in USD; null when unknown, which doesn't count against it. */
  liquidityUsd: number | null;
  minLiquidityUsd: number;
  maxMove?: number;
}

export interface Assessment {
  /** The first requirement that failed, or null when all pass. */
  failure: NotScoringReason | null;
  metrics: {
    ticks: number;
    lastTickAt: number | null;
    benchmarkMoves: number;
    updateRatio: number | null;
    liquidityUsd: number | null;
    jumps: number;
  };
  /** When each confirmed jump in the window happened. */
  jumpTimes: number[];
}

/**
 * Checks one asset against the requirements to score. They are the same for
 * every asset, whatever its class, so a newly listed asset starts scoring as
 * soon as its price is reliable, with no code change.
 */
export function assessAsset(input: AssessInput): Assessment {
  const { ticks, benchmark, now, liquidityUsd } = input;
  const last = ticks.at(-1);

  // How often the price changed on ticks where the benchmark did. A pool that
  // nobody trades keeps its last price for hours while the market moves.
  let benchmarkMoves = 0;
  let updates = 0;
  for (let i = 1; i < ticks.length; i++) {
    const before = priceAt(benchmark, ticks[i - 1].at, 0);
    const after = priceAt(benchmark, ticks[i].at, 0);
    if (before <= 0 || after === before) continue;
    benchmarkMoves++;
    if (ticks[i].price !== ticks[i - 1].price) updates++;
  }
  const updateRatio = benchmarkMoves > 0 ? updates / benchmarkMoves : null;

  const first = ticks[0];
  const jumpTimes = first
    ? guardSeries(
        ticks.slice(1),
        benchmark,
        { price: first.price, benchmark: priceAt(benchmark, first.at, 0), pending: 0 },
        input.maxMove ?? MAX_TICK_MOVE,
      ).jumps
    : [];
  const jumps = jumpTimes.length;

  const metrics = {
    ticks: ticks.length,
    lastTickAt: last?.at ?? null,
    benchmarkMoves,
    updateRatio,
    liquidityUsd,
    jumps,
  };

  const failure: NotScoringReason | null = !last
    ? 'no_price'
    : now - last.at > 2 * Math.max(1, input.tickMinutes) * 60_000
      ? 'stale_price'
      : benchmarkMoves >= MIN_BENCHMARK_MOVES && updates / benchmarkMoves < MIN_PRICE_UPDATE_RATIO
        ? 'price_not_updating'
        : liquidityUsd !== null && liquidityUsd < input.minLiquidityUsd
          ? 'thin_liquidity'
          : jumps > MAX_JUMPS
            ? 'erratic_price'
            : null;

  return { failure, metrics, jumpTimes };
}

export interface ScoringStatus {
  eligible: boolean;
  reason: NotScoringReason | null;
  /** When [eligible] last changed. */
  since: number;
  /** When the asset started passing every requirement; null while failing. */
  passingSince: number | null;
}

/**
 * Applies hysteresis: an asset stops scoring the moment a requirement fails,
 * but only scores again after passing for [ELIGIBILITY_HYSTERESIS_MS], so a
 * flaky price can't flicker in and out. A newly seen asset that passes scores
 * straight away.
 */
export function nextStatus(
  previous: ScoringStatus | undefined,
  failure: NotScoringReason | null,
  now: number,
  hysteresisMs = ELIGIBILITY_HYSTERESIS_MS,
): ScoringStatus {
  if (failure) {
    return {
      eligible: false,
      reason: failure,
      since: previous && !previous.eligible ? previous.since : now,
      passingSince: null,
    };
  }
  if (!previous) return { eligible: true, reason: null, since: now, passingSince: now };
  if (previous.eligible) return { ...previous, reason: null, passingSince: previous.passingSince ?? now };

  const passingSince = previous.passingSince ?? now;
  return now - passingSince >= hysteresisMs
    ? { eligible: true, reason: null, since: now, passingSince }
    : { eligible: false, reason: 'recovering', since: previous.since, passingSince };
}
