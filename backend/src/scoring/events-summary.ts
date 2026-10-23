import type { EntryBreakdown } from './engine/types.js';

/** Most moments named in one notification; the rest become "and 2 more". */
const MAX_NAMED = 3;

/**
 * The day's in-game moments in words a player recognises, biggest first:
 * "2 goals from NVDAx, a clean sheet from KOx and 1 more". The daily cap
 * isn't a moment, so it's left out (the total already includes it).
 */
export function summariseEvents(breakdown: EntryBreakdown): string {
  const moments = [
    ...breakdown.slots.flatMap((slot) =>
      slot.events
        .filter((e) => e.code !== 'cap' && e.points !== 0)
        .map((e) => ({ text: `${moment(e.label)} from ${slot.symbol}`, size: Math.abs(e.points) })),
    ),
    ...breakdown.teamEvents
      .filter((e) => e.code !== 'cap' && e.points !== 0)
      .map((e) => ({ text: moment(e.label), size: Math.abs(e.points) })),
  ].sort((a, b) => b.size - a.size);

  if (moments.length === 0) return '';
  const named = moments.slice(0, MAX_NAMED).map((m) => m.text);
  const rest = moments.length - named.length;
  if (rest > 0) named.push(`${rest} more`);
  return named.length === 1 ? named[0] : `${named.slice(0, -1).join(', ')} and ${named.at(-1)}`;
}

/** "Goal" reads as "a goal", "Clean sheet" as "a clean sheet"; "2 goals" stays as it is. */
function moment(label: string): string {
  const text = label.trim();
  if (/^\d/.test(text)) return text;
  const lower = text.charAt(0).toLowerCase() + text.slice(1);
  return `${/^[aeiou]/i.test(lower) ? 'an' : 'a'} ${lower}`;
}

/** The daily points notification's body. */
export function dailyPointsBody(sport: string, breakdown: EntryBreakdown): string {
  const sign = breakdown.total > 0 ? '+' : '';
  const points = `${sign}${breakdown.total} ${Math.abs(breakdown.total) === 1 ? 'point' : 'points'}`;
  const what = summariseEvents(breakdown);
  return what
    ? `Your ${sport} team scored ${points} yesterday: ${what}.`
    : `Your ${sport} team scored ${points} yesterday.`;
}
