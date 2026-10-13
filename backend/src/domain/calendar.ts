/**
 * The game's calendar (SCORING_PLAN.md Phase 2), in US market time.
 *
 * - A match week kicks off Monday 9:30am ET and reaches full time Friday 4pm
 *   ET. It's a window over the points ledger, not a separate engine: ticks and
 *   banking keep running all week.
 * - From full time to the next kick-off is the transfer window, when
 *   substitutions are free.
 * - A season is 12 match weeks, roughly one per earnings season.
 *
 * Times are computed in America/New_York, so daylight saving moves the UTC
 * kick-off between 13:30 and 14:30 on its own.
 */

/** Injection token for the app's GameCalendar. */
export const CALENDAR = Symbol('CALENDAR');

const ZONE = 'America/New_York';
const DAY = 86_400_000;
export const WEEKS_PER_SEASON = 12;

/** Monday of match week 1 of season 1, as an ET calendar date. */
export const DEFAULT_SEASON_ANCHOR = '2026-10-12';

const KICK_OFF = { hour: 9, minute: 30 };
const FULL_TIME = { hour: 16, minute: 0 };

export interface MatchWeek {
  /** 1-based, counted from the anchor across seasons. */
  number: number;
  season: number;
  /** 1–12 within the season. */
  weekOfSeason: number;
  kickOff: Date;
  fullTime: Date;
  /** Kick-off of the following week, which ends this week's transfer window. */
  nextKickOff: Date;
}

export interface Season {
  number: number;
  startsAt: Date;
  /** Kick-off of the next season's first week. */
  endsAt: Date;
}

const offsetFormat = new Intl.DateTimeFormat('en-US', {
  timeZone: ZONE,
  timeZoneName: 'longOffset',
});
const dateFormat = new Intl.DateTimeFormat('en-CA', {
  timeZone: ZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

/** ET's offset from UTC at [at], in minutes (e.g. -240 in summer). */
function offsetMinutes(at: number): number {
  const name = offsetFormat.formatToParts(at).find((p) => p.type === 'timeZoneName')?.value ?? '';
  const match = /GMT([+-])(\d{2}):(\d{2})/.exec(name);
  if (!match) return 0;
  const minutes = Number(match[2]) * 60 + Number(match[3]);
  return match[1] === '-' ? -minutes : minutes;
}

/** The UTC instant of an ET wall-clock time on the ET date [day] (days since epoch). */
function etTime(day: number, { hour, minute }: { hour: number; minute: number }): Date {
  const wall = day * DAY + (hour * 60 + minute) * 60_000;
  // Two passes settle the offset even on the day it changes.
  let utc = wall - offsetMinutes(wall) * 60_000;
  utc = wall - offsetMinutes(utc) * 60_000;
  return new Date(utc);
}

/** The ET calendar date of [at], as days since the epoch. */
function etDay(at: number): number {
  const [y, m, d] = dateFormat.format(at).split('-').map(Number);
  return Math.floor(Date.UTC(y, m - 1, d) / DAY);
}

function parseAnchor(anchor: string): number {
  const [y, m, d] = anchor.split('-').map(Number);
  const day = Math.floor(Date.UTC(y, m - 1, d) / DAY);
  // Snap to that week's Monday (the epoch, day 0, was a Thursday).
  return day - ((day + 3) % 7);
}

export class GameCalendar {
  private readonly anchorDay: number;

  constructor(anchor = DEFAULT_SEASON_ANCHOR) {
    this.anchorDay = parseAnchor(anchor);
  }

  /** Match week [number] (1-based). */
  week(number: number): MatchWeek {
    const monday = this.anchorDay + (number - 1) * 7;
    return {
      number,
      season: Math.floor((number - 1) / WEEKS_PER_SEASON) + 1,
      weekOfSeason: ((number - 1) % WEEKS_PER_SEASON) + 1,
      kickOff: etTime(monday, KICK_OFF),
      fullTime: etTime(monday + 4, FULL_TIME),
      nextKickOff: etTime(monday + 7, KICK_OFF),
    };
  }

  /**
   * The match week [at] belongs to: the one that kicked off most recently. Its
   * weekend transfer window counts as part of it. Before the anchor this is
   * week 1, which hasn't kicked off yet.
   */
  weekAt(at: number | Date): MatchWeek {
    const t = typeof at === 'number' ? at : at.getTime();
    const sinceAnchor = etDay(t) - this.anchorDay;
    let number = Math.max(1, Math.floor(sinceAnchor / 7) + 1);
    // Monday before 9:30 still belongs to last week's transfer window.
    if (number > 1 && t < this.week(number).kickOff.getTime()) number--;
    return this.week(number);
  }

  /** True between Friday full time and Monday kick-off: substitutions are free. */
  inTransferWindow(at: number | Date): boolean {
    const t = typeof at === 'number' ? at : at.getTime();
    const week = this.weekAt(t);
    return t < week.kickOff.getTime() || t >= week.fullTime.getTime();
  }

  /** True while a match week is being played (kick-off to full time). */
  inPlay(at: number | Date): boolean {
    return !this.inTransferWindow(at);
  }

  season(number: number): Season {
    const first = this.week((number - 1) * WEEKS_PER_SEASON + 1);
    const next = this.week(number * WEEKS_PER_SEASON + 1);
    return { number, startsAt: first.kickOff, endsAt: next.kickOff };
  }

  seasonAt(at: number | Date): Season {
    return this.season(this.weekAt(at).season);
  }
}
