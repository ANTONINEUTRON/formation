/**
 * The thresholds behind the admin health page, kept as pure functions so
 * they can be tested without a database.
 */

export type HealthLevel = 'green' | 'amber' | 'red' | 'unknown';

export interface HealthCheck {
  key: string;
  label: string;
  level: HealthLevel;
  /** What was measured, in words: "4 min ago", "61 of 98 scoring". */
  value: string;
  /** When it turns amber and red, in words. */
  threshold: string;
}

/** Higher is worse: green below [amber], amber below [red], red from there. */
export function gradeAbove(value: number | null, amber: number, red: number): HealthLevel {
  if (value === null || Number.isNaN(value)) return 'unknown';
  if (value > red) return 'red';
  if (value > amber) return 'amber';
  return 'green';
}

/** Lower is worse: the scoring share, for instance. */
export function gradeBelow(value: number | null, amber: number, red: number): HealthLevel {
  if (value === null || Number.isNaN(value)) return 'unknown';
  if (value < red) return 'red';
  if (value < amber) return 'amber';
  return 'green';
}

/** The worst of several levels; unknown only when nothing is known. */
export function worst(levels: HealthLevel[]): HealthLevel {
  for (const level of ['red', 'amber', 'green'] as const) {
    if (levels.includes(level)) return level;
  }
  return 'unknown';
}

const MINUTE = 60_000;

/** "just now", "12 min", "3 h", "2 d". */
export function duration(ms: number): string {
  if (ms < MINUTE) return 'under a minute';
  if (ms < 60 * MINUTE) return `${Math.floor(ms / MINUTE)} min`;
  if (ms < 48 * 60 * MINUTE) return `${Math.floor(ms / (60 * MINUTE))} h`;
  return `${Math.floor(ms / (24 * 60 * MINUTE))} d`;
}

/**
 * How stale each heartbeat may get. Prices are recorded and points banked
 * every PRICE_TICK_MINUTES, so the limits follow that interval rather than
 * fixed minutes: a server ticking hourly isn't late at 20 minutes.
 */
export function staleness(tickMinutes: number) {
  const tick = Math.max(1, tickMinutes) * MINUTE;
  return {
    priceTick: { amber: 2 * tick, red: 4 * tick },
    bank: { amber: 2 * tick + 5 * MINUTE, red: 6 * tick },
    // Points only move when someone has a team, so the ledger can be quieter.
    ledger: { amber: Math.max(30 * MINUTE, 3 * tick), red: Math.max(120 * MINUTE, 12 * tick) },
  };
}

/** Share of the catalogue with a fresh price: amber under 90%, red under half. */
export const PRICED_SHARE = { amber: 0.9, red: 0.5 };
/** Failed Assistant Manager requests today. */
export const AI_FAILURES = { amber: 0.1, red: 0.25 };
/** Database size against the plan. */
export const DB_SIZE = { amber: 0.8, red: 0.95 };
/** A match-week step overdue by this long. */
export const MATCH_WEEK_STEP = { amber: 60 * MINUTE, red: 6 * 60 * MINUTE };
/** A league still live this long past its end. */
export const LEAGUE_OVERDUE = { amber: 0, red: 6 * 60 * MINUTE };
