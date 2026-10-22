/**
 * The daily check-in streak: how many days in a row a Manager has opened the
 * app. A day is a calendar day in their own time zone, so checking in late
 * evening and again next morning counts as two days, as they'd expect.
 */

/** Streaks worth a notification. */
export const STREAK_MILESTONES = [3, 7, 14, 30, 50, 100] as const;

const formats = new Map<string, Intl.DateTimeFormat>();

function formatFor(zone: string): Intl.DateTimeFormat {
  let format = formats.get(zone);
  if (!format) {
    try {
      format = new Intl.DateTimeFormat('en-CA', { timeZone: zone, year: 'numeric', month: '2-digit', day: '2-digit' });
    } catch {
      // An unknown zone counts in UTC rather than failing the request.
      format = new Intl.DateTimeFormat('en-CA', { timeZone: 'UTC', year: 'numeric', month: '2-digit', day: '2-digit' });
    }
    formats.set(zone, format);
  }
  return format;
}

/** The calendar day [at] falls on in [zone], as YYYY-MM-DD. */
export function localDay(at: number, zone = 'UTC'): string {
  return formatFor(zone).format(new Date(at));
}

/** The day before [day] (YYYY-MM-DD). */
export function dayBefore(day: string): string {
  const d = new Date(`${day}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() - 1);
  return d.toISOString().slice(0, 10);
}

/**
 * The streak after a visit on [today]: unchanged on a repeat visit the same
 * day, one more if the last visit was yesterday, otherwise back to 1.
 */
export function nextStreak(lastDay: string | null, streak: number, today: string): number {
  if (lastDay === today) return Math.max(1, streak);
  if (lastDay !== null && lastDay === dayBefore(today)) return streak + 1;
  return 1;
}

/**
 * The streak to show today. One that ended (no visit yesterday or today) is
 * 0, even though the stored number only resets on the next visit.
 */
export function liveStreak(lastDay: string | null, streak: number, today: string): number {
  return lastDay === today || lastDay === dayBefore(today) ? streak : 0;
}

export function isMilestone(streak: number): boolean {
  return (STREAK_MILESTONES as readonly number[]).includes(streak);
}
