/**
 * Head-to-head fixtures for private leagues (SCORING_PLAN.md §2.2): each match
 * week every member plays one other, round robin, and the table counts 3 for a
 * win and 1 for a draw.
 */

export interface Pairing {
  home: string;
  /** Null is a bye: the member sits the week out. */
  away: string | null;
}

/**
 * Round [round] (0-based) of a round robin between [members], by the circle
 * method: one member stays put while the rest rotate, so over n-1 rounds (n
 * rounded up to even) everyone meets everyone exactly once. Rounds past the
 * end start the cycle again. Home and away alternate so neither side always
 * hosts.
 */
export function roundRobin(members: string[], round: number): Pairing[] {
  const players: (string | null)[] = [...members].sort((a, b) => a.localeCompare(b));
  if (players.length < 2) return [];
  if (players.length % 2 === 1) players.push(null);

  const n = players.length;
  const rounds = n - 1;
  const r = ((round % rounds) + rounds) % rounds;
  // Rotate everyone but the first player r places.
  const rest = players.slice(1);
  const rotated = [...rest.slice(rest.length - r), ...rest.slice(0, rest.length - r)];
  const order = [players[0], ...rotated];

  const pairings: Pairing[] = [];
  for (let i = 0; i < n / 2; i++) {
    let home = order[i];
    let away = order[n - 1 - i];
    if ((r + i) % 2 === 1) [home, away] = [away, home];
    if (home === null) [home, away] = [away, null];
    if (home === null) continue;
    pairings.push({ home, away });
  }
  return pairings;
}

export type FixtureOutcome = 'W' | 'D' | 'L';

/** Scores within half a point of each other are a draw. */
export const DRAW_MARGIN = 0.5;

export function outcome(points: number, against: number): FixtureOutcome {
  if (Math.abs(points - against) < DRAW_MARGIN) return 'D';
  return points > against ? 'W' : 'L';
}

export interface FinishedFixture {
  week: number;
  home: string;
  away: string | null;
  homePoints: number;
  awayPoints: number;
}

export interface TableRow {
  userId: string;
  played: number;
  won: number;
  drawn: number;
  lost: number;
  /** Fantasy points scored and conceded across fixtures. */
  pointsFor: number;
  pointsAgainst: number;
  /** League points: 3 a win, 1 a draw. */
  tablePoints: number;
  /** Last five results, oldest first. */
  form: FixtureOutcome[];
}

/** The league table from finished fixtures, best first. */
export function leagueTable(members: string[], fixtures: FinishedFixture[]): TableRow[] {
  const rows = new Map<string, TableRow & { results: { week: number; o: FixtureOutcome }[] }>(
    members.map((userId) => [
      userId,
      {
        userId,
        played: 0,
        won: 0,
        drawn: 0,
        lost: 0,
        pointsFor: 0,
        pointsAgainst: 0,
        tablePoints: 0,
        form: [],
        results: [],
      },
    ]),
  );

  const record = (userId: string, scored: number, conceded: number, week: number) => {
    const row = rows.get(userId);
    if (!row) return;
    const o = outcome(scored, conceded);
    row.played++;
    row.pointsFor += scored;
    row.pointsAgainst += conceded;
    if (o === 'W') row.won++;
    else if (o === 'D') row.drawn++;
    else row.lost++;
    row.tablePoints += o === 'W' ? 3 : o === 'D' ? 1 : 0;
    row.results.push({ week, o });
  };

  for (const f of fixtures) {
    if (f.away === null) continue; // A bye isn't played.
    record(f.home, f.homePoints, f.awayPoints, f.week);
    record(f.away, f.awayPoints, f.homePoints, f.week);
  }

  return [...rows.values()]
    .map(({ results, ...row }) => ({
      ...row,
      pointsFor: Math.round(row.pointsFor * 10) / 10,
      pointsAgainst: Math.round(row.pointsAgainst * 10) / 10,
      form: results
        .sort((a, b) => a.week - b.week)
        .slice(-5)
        .map((r) => r.o),
    }))
    .sort(
      (a, b) =>
        b.tablePoints - a.tablePoints ||
        b.pointsFor - b.pointsAgainst - (a.pointsFor - a.pointsAgainst) ||
        b.pointsFor - a.pointsFor,
    );
}
