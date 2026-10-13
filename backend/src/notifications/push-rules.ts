import type { NotificationKind } from '../core/db-types.js';

/**
 * What a player can switch off, and which notifications each switch covers.
 * Every kind belongs to exactly one category.
 */
export const PUSH_CATEGORIES = {
  match_week: ['match_week', 'transfer_window'],
  goals: ['goal'],
  not_scoring: ['not_scoring'],
  season: ['season_final'],
  points: ['points'],
  leagues: ['league_started', 'league_settled', 'league_joined'],
  social: ['new_follower', 'manager_move'],
} as const satisfies Record<string, readonly NotificationKind[]>;

export type PushCategory = keyof typeof PUSH_CATEGORIES;

export const PUSH_CATEGORY_NAMES = Object.keys(PUSH_CATEGORIES) as PushCategory[];

/** Most pushes a player gets in any 24 hours. The in-app inbox still gets all. */
export const DAILY_PUSH_BUDGET = 10;

export function categoryOf(kind: NotificationKind): PushCategory {
  for (const name of PUSH_CATEGORY_NAMES) {
    if ((PUSH_CATEGORIES[name] as readonly string[]).includes(kind)) return name;
  }
  return 'points';
}

/** Minutes after local midnight at [at] in [timeZone]; UTC if the zone is unknown. */
export function localMinutes(at: number, timeZone: string): number {
  let parts: Intl.DateTimeFormatPart[];
  try {
    parts = new Intl.DateTimeFormat('en-GB', {
      timeZone,
      hour: '2-digit',
      minute: '2-digit',
      hourCycle: 'h23',
    }).formatToParts(at);
  } catch {
    const d = new Date(at);
    return d.getUTCHours() * 60 + d.getUTCMinutes();
  }
  const hour = Number(parts.find((p) => p.type === 'hour')?.value ?? 0);
  const minute = Number(parts.find((p) => p.type === 'minute')?.value ?? 0);
  return hour * 60 + minute;
}

/** True inside [start, end), which may wrap past midnight (22:00–08:00). */
export function isQuiet(minutes: number, start: number, end: number): boolean {
  if (start === end) return false;
  return start < end ? minutes >= start && minutes < end : minutes >= start || minutes < end;
}

export function isValidTimeZone(zone: string): boolean {
  try {
    new Intl.DateTimeFormat('en-GB', { timeZone: zone });
    return true;
  } catch {
    return false;
  }
}
