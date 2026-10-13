import { round1 } from './metrics.js';
import type { ScoreEvent } from './types.js';

/**
 * Skill, made visible (SCORING_PLAN.md §3.2). Everything here is worked out
 * from what the ledger already records; there is no new data source.
 */

/** Must match score-entry.ts: 1 point per 0.1% of alpha. */
const POINTS_PER_ALPHA = 1_000;

/** Weeks of history before a rating stands on its own. */
export const SKILL_PRIOR_WEEKS = 6;
/** Weeks needed to appear on the Skill board. */
export const SKILL_MIN_WEEKS = 3;
/**
 * A floor under weekly volatility, so a manager with two identical weeks
 * doesn't divide by nearly nothing and top the board.
 */
const VOLATILITY_FLOOR = 0.005;

/** Event codes that read as a "goal", whatever the sport. */
export const GOAL_CODES = new Set(['goal', 'bucket', 'touchdown', 'block', 'double_double', 'field_goal']);

export interface Rating {
  /** 0–100; 50 is a manager who matches the market. */
  rating: number;
  meanAlpha: number;
  volatility: number;
}

/**
 * Risk-adjusted alpha: mean weekly alpha over its volatility, scaled to
 * 0–100, and shrunk toward the middle until [SKILL_PRIOR_WEEKS] exist. It
 * rewards steady market-beating over one lucky spike.
 */
export function skillRating(weeklyAlpha: number[]): Rating {
  const n = weeklyAlpha.length;
  if (n === 0) return { rating: 50, meanAlpha: 0, volatility: 0 };
  const mean = weeklyAlpha.reduce((s, a) => s + a, 0) / n;
  const variance =
    n > 1 ? weeklyAlpha.reduce((s, a) => s + (a - mean) ** 2, 0) / (n - 1) : 0;
  const volatility = Math.sqrt(variance);
  const ratio = mean / Math.max(volatility, VOLATILITY_FLOOR);
  const confidence = Math.min(1, n / SKILL_PRIOR_WEEKS);
  return {
    rating: round1(50 + 50 * Math.tanh(confidence * ratio)),
    meanAlpha: mean,
    volatility,
  };
}

/** One ledger row as the weekly roll-up reads it. */
export interface LedgerRow {
  kind: string;
  points: number;
  detail: unknown;
}

export interface WeekStats {
  points: number;
  /** The average pick's return against its benchmark (0.021 = +2.1%). */
  alpha: number;
  picks: number;
  picksBeating: number;
  goals: number;
  cleanSheets: number;
  /** The captain's points before the multiplier; null with no captain. */
  captainPoints: number | null;
  averagePickPoints: number | null;
}

/**
 * A player's match week from their ledger rows. Alpha rows carry each pick's
 * points and who wore the armband, so the multiplier can be taken back out.
 */
export function weekStats(rows: LedgerRow[]): WeekStats {
  const raw = new Map<string, number>();
  let captainPoints: number | null = null;
  let points = 0;
  let goals = 0;
  let cleanSheets = 0;

  for (const row of rows) {
    points += row.points;
    if (row.kind === 'alpha') {
      const detail = (row.detail ?? {}) as {
        slots?: Record<string, number>;
        captain?: string | null;
        multiplier?: number;
      };
      for (const [mint, total] of Object.entries(detail.slots ?? {})) {
        const isCaptain = detail.captain === mint;
        const unmultiplied = isCaptain ? total / (detail.multiplier ?? 1) : total;
        raw.set(mint, (raw.get(mint) ?? 0) + unmultiplied);
        if (isCaptain) captainPoints = (captainPoints ?? 0) + unmultiplied;
      }
    } else if (row.kind === 'events') {
      const detail = (row.detail ?? {}) as { slots?: { events: ScoreEvent[] }[] };
      for (const slot of detail.slots ?? []) {
        for (const event of slot.events) {
          if (event.code === 'clean_sheet') cleanSheets++;
          if (GOAL_CODES.has(event.code) && event.points > 0) goals += goalCount(event);
        }
      }
    }
  }

  const picks = raw.size;
  const totalRaw = [...raw.values()].reduce((s, p) => s + p, 0);
  return {
    points: round1(points),
    alpha: picks > 0 ? totalRaw / picks / POINTS_PER_ALPHA : 0,
    picks,
    picksBeating: [...raw.values()].filter((p) => p > 0).length,
    goals,
    cleanSheets,
    captainPoints: captainPoints === null ? null : round1(captainPoints),
    averagePickPoints: picks > 0 ? round1(totalRaw / picks) : null,
  };
}

/** "3 goals" is three; anything else is one. */
function goalCount(event: ScoreEvent): number {
  const match = /^(\d+)\s/.exec(event.label);
  return match ? Number(match[1]) : 1;
}

/** W when the team beat the market that week, L when it lagged, D near zero. */
export function weekForm(points: number): 'W' | 'D' | 'L' {
  if (Math.abs(points) < 0.5) return 'D';
  return points > 0 ? 'W' : 'L';
}
