import { tickerOf } from './sectors.js';
import { RISK_TIERS } from './sport.js';
import type { RiskTier } from './sport.js';

/**
 * The tier formula. Once a season, every stock is measured against the
 * benchmark over the trailing window:
 *
 * - beta: how much it moves with the market (1 = like the S&P 500);
 * - volatility: how much it swings, annualised.
 *
 * Its risk score is the average of its percentile rank on each, so neither
 * number dominates and one extreme reading can't. Stocks are then split into
 * thirds by risk: blue chip, balanced, momentum. Thirds rather than fixed
 * thresholds keep every tier stocked however calm or wild the market is.
 *
 * A few kinds of fund always land in the same tier (FIXED_TIERS). Stocks
 * without enough clean history keep their tier, and no stock moves more than
 * one tier in a run, so a season's change is never a lurch.
 */

/** Trailing window measured, in calendar days. */
export const TIER_WINDOW_DAYS = 90;
/** Fewer trading days with a real price change than this and a stock isn't measured. */
export const MIN_TRADING_DAYS = 40;
/** Share of trading days a price must actually change on; a frozen pool fails it. */
const MIN_MOVING_SHARE = 0.8;
/** The tier a newly listed stock starts in, before it has history. */
export const NEW_LISTING_TIER: RiskTier = 'balanced';

const TRADING_DAYS_PER_YEAR = 252;
const DAY_MS = 86_400_000;

/**
 * Funds whose tier is fixed by what they are, not by a short price history:
 * leveraged and inverse funds always swing hardest, T-bill and bond funds
 * barely move.
 */
const ATTACK_NAME = /\b(2x|3x|leveraged|ultra\w*|inverse|bear|bull)\b/i;
/** By ticker, so they hold whoever issues the token (TQQQx, TQQQ). */
const ATTACK_TICKERS = new Set(['TQQQ', 'SQQQ', 'SOXL', 'UPRO', 'SPXL', 'TSLL', 'NVDL', 'MSTU', 'UVXY']);
const DEFENCE_TICKERS = new Set(['SGOV', 'TBLL', 'BIL', 'SHV', 'SHY', 'IEF', 'TLT', 'BND', 'AGG']);

export function fixedTier(symbol: string, companyName = ''): RiskTier | null {
  const ticker = tickerOf(symbol);
  if (DEFENCE_TICKERS.has(ticker)) return 'blue_chip';
  if (ATTACK_TICKERS.has(ticker) || ATTACK_NAME.test(companyName)) return 'momentum';
  return null;
}

/** One day's last price. [day] is the UTC midnight of that day, in ms. */
export interface DailyClose {
  day: number;
  price: number;
}

export interface Measurement {
  beta: number;
  /** Annualised, as a fraction: 0.25 is 25%. */
  volatility: number;
  /** Trading days both the stock and the benchmark had a return. */
  days: number;
}

const isWeekday = (day: number) => {
  const weekday = new Date(day).getUTCDay();
  return weekday !== 0 && weekday !== 6;
};

/** Day → return, from consecutive weekday closes. Weekends are skipped: xStocks trade, the shares don't. */
function returnsByDay(closes: DailyClose[]): Map<number, number> {
  const weekdays = closes.filter((c) => c.price > 0 && isWeekday(c.day)).sort((a, b) => a.day - b.day);
  const out = new Map<number, number>();
  for (let i = 1; i < weekdays.length; i++) {
    out.set(weekdays[i].day, weekdays[i].price / weekdays[i - 1].price - 1);
  }
  return out;
}

const mean = (xs: number[]) => xs.reduce((s, x) => s + x, 0) / xs.length;

/**
 * Beta and volatility against [benchmark], or null when the history is too
 * short or too frozen to trust. A thin pool's price sits still for days, and a
 * still price would otherwise measure as the calmest stock in the game.
 */
export function measure(closes: DailyClose[], benchmark: DailyClose[]): Measurement | null {
  const own = returnsByDay(closes);
  const market = returnsByDay(benchmark);
  const days = [...own.keys()].filter((d) => market.has(d));
  if (days.length < MIN_TRADING_DAYS) return null;

  const r = days.map((d) => own.get(d)!);
  const m = days.map((d) => market.get(d)!);
  const moving = r.filter((x) => x !== 0).length;
  if (moving < MIN_TRADING_DAYS || moving / r.length < MIN_MOVING_SHARE) return null;

  const rMean = mean(r);
  const mMean = mean(m);
  let cov = 0;
  let varM = 0;
  let varR = 0;
  for (let i = 0; i < r.length; i++) {
    cov += (r[i] - rMean) * (m[i] - mMean);
    varM += (m[i] - mMean) ** 2;
    varR += (r[i] - rMean) ** 2;
  }
  const n = r.length - 1;
  return {
    beta: varM > 0 ? cov / varM : 0,
    volatility: Math.sqrt(varR / n) * Math.sqrt(TRADING_DAYS_PER_YEAR),
    days: r.length,
  };
}

/** Each value's percentile rank among [values], 0 (lowest) to 1 (highest). Ties share a rank. */
function percentiles(values: number[]): number[] {
  if (values.length === 1) return [0.5];
  const sorted = [...values].sort((a, b) => a - b);
  return values.map((v) => {
    const first = sorted.indexOf(v);
    const last = sorted.lastIndexOf(v);
    return (first + last) / 2 / (values.length - 1);
  });
}

/** Thirds by risk score, calmest third first. Keyed by whatever id the caller uses. */
export function tiersByRisk(measured: { id: string; beta: number; volatility: number }[]): Map<string, { tier: RiskTier; risk: number }> {
  const betaRank = percentiles(measured.map((s) => s.beta));
  const volRank = percentiles(measured.map((s) => s.volatility));
  const scored = measured
    .map((s, i) => ({ id: s.id, risk: (betaRank[i] + volRank[i]) / 2 }))
    .sort((a, b) => a.risk - b.risk || a.id.localeCompare(b.id));
  const out = new Map<string, { tier: RiskTier; risk: number }>();
  scored.forEach((s, i) => {
    const third = Math.min(2, Math.floor((i * 3) / scored.length));
    out.set(s.id, { tier: RISK_TIERS[third], risk: Math.round(s.risk * 100) });
  });
  return out;
}

/** At most one tier from [current] toward [target]. */
export function oneStep(current: RiskTier, target: RiskTier): RiskTier {
  const from = RISK_TIERS.indexOf(current);
  const to = RISK_TIERS.indexOf(target);
  return RISK_TIERS[from + Math.sign(to - from)];
}

export interface TierCandidate {
  mint: string;
  symbol: string;
  companyName: string;
  tier: RiskTier;
  source: 'formula' | 'manual';
  closes: DailyClose[];
}

export type TierReason = 'manual' | 'fixed' | 'formula' | 'not_enough_data';

export interface TierDecision {
  mint: string;
  symbol: string;
  current: RiskTier;
  /** What the formula alone would give; null when it couldn't measure the stock. */
  proposed: RiskTier | null;
  /** What the stock will be: [proposed], limited to one step, or unchanged. */
  next: RiskTier;
  reason: TierReason;
  beta: number | null;
  volatility: number | null;
  /** 0 (calmest) to 100 (wildest); null when not measured. */
  risk: number | null;
}

/** Decides every stock's tier for the coming season. Pure: the caller loads and saves. */
export function planTiers(candidates: TierCandidate[], benchmark: DailyClose[]): TierDecision[] {
  const measurements = new Map<string, Measurement>();
  for (const c of candidates) {
    if (c.source === 'manual' || fixedTier(c.symbol, c.companyName)) continue;
    const m = measure(c.closes, benchmark);
    if (m) measurements.set(c.mint, m);
  }
  const ranked = tiersByRisk([...measurements].map(([id, m]) => ({ id, beta: m.beta, volatility: m.volatility })));

  return candidates.map((c) => {
    const m = measurements.get(c.mint);
    const base = {
      mint: c.mint,
      symbol: c.symbol,
      current: c.tier,
      beta: m ? round2(m.beta) : null,
      volatility: m ? round2(m.volatility) : null,
      risk: ranked.get(c.mint)?.risk ?? null,
    };
    if (c.source === 'manual') return { ...base, proposed: null, next: c.tier, reason: 'manual' as const };
    const fixed = fixedTier(c.symbol, c.companyName);
    if (fixed) return { ...base, proposed: fixed, next: fixed, reason: 'fixed' as const };
    const proposed = ranked.get(c.mint)?.tier;
    if (!proposed) return { ...base, proposed: null, next: c.tier, reason: 'not_enough_data' as const };
    return { ...base, proposed, next: oneStep(c.tier, proposed), reason: 'formula' as const };
  });
}

const round2 = (x: number) => Math.round(x * 100) / 100;

/** UTC midnight of [at]. */
export const dayOf = (at: number) => Math.floor(at / DAY_MS) * DAY_MS;
