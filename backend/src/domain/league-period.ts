import { BadRequestException } from '@nestjs/common';

export const LEAGUE_PERIODS = ['all_time', 'monthly', 'weekly', 'custom'] as const;
export type LeaguePeriodKind = (typeof LEAGUE_PERIODS)[number];

/**
 * A slice of league history. `from`/`to` bound which gameweeks count: a
 * gameweek is included when it *ended* inside the range, so a window that
 * straddles a boundary lands in the period it finished in rather than being
 * split or counted twice. Both null means all time.
 */
export interface LeaguePeriod {
  kind: LeaguePeriodKind;
  from: Date | null;
  /** Null means "up to now", which is what keeps live points in scope. */
  to: Date | null;
}

export const ALL_TIME: LeaguePeriod = { kind: 'all_time', from: null, to: null };

/** True when the live gameweek's points belong in this period. */
export function includesNow(period: LeaguePeriod, now = Date.now()): boolean {
  return period.to === null || period.to.getTime() >= now;
}

/** Midnight UTC on the Monday of the week containing [at]. */
function startOfWeek(at: Date): Date {
  const start = new Date(
    Date.UTC(at.getUTCFullYear(), at.getUTCMonth(), at.getUTCDate()),
  );
  // getUTCDay: 0 = Sunday, so Monday is 1 and Sunday sits at the week's end.
  const daysSinceMonday = (start.getUTCDay() + 6) % 7;
  start.setUTCDate(start.getUTCDate() - daysSinceMonday);
  return start;
}

function startOfMonth(at: Date): Date {
  return new Date(Date.UTC(at.getUTCFullYear(), at.getUTCMonth(), 1));
}

function parseDate(value: string | undefined, field: string): Date {
  const date = new Date(value ?? '');
  if (Number.isNaN(date.getTime())) {
    throw new BadRequestException(`${field} must be an ISO date`);
  }
  return date;
}

/**
 * Builds a period from query parameters. `custom` requires `from`; `to` is
 * optional and defaults to open-ended so a custom range can run to now.
 */
export function parseLeaguePeriod(
  kind: string | undefined,
  from: string | undefined,
  to: string | undefined,
  now = new Date(),
): LeaguePeriod {
  if (kind === undefined || kind === '') return ALL_TIME;
  if (!(LEAGUE_PERIODS as readonly string[]).includes(kind)) {
    throw new BadRequestException(`period must be one of ${LEAGUE_PERIODS.join(', ')}`);
  }

  switch (kind as LeaguePeriodKind) {
    case 'all_time':
      return ALL_TIME;
    case 'weekly':
      return { kind: 'weekly', from: startOfWeek(now), to: null };
    case 'monthly':
      return { kind: 'monthly', from: startOfMonth(now), to: null };
    case 'custom': {
      if (!from) throw new BadRequestException('custom periods need a from date');
      const start = parseDate(from, 'from');
      const end = to ? parseDate(to, 'to') : null;
      if (end && end.getTime() <= start.getTime()) {
        throw new BadRequestException('to must be after from');
      }
      return { kind: 'custom', from: start, to: end };
    }
  }
}
