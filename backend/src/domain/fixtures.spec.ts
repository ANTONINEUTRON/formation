import { leagueTable, outcome, roundRobin } from './fixtures.js';

describe('roundRobin', () => {
  it('pairs everyone with everyone exactly once over n-1 rounds', () => {
    const members = ['a', 'b', 'c', 'd'];
    const met = new Set<string>();
    for (let round = 0; round < 3; round++) {
      const pairings = roundRobin(members, round);
      expect(pairings).toHaveLength(2);
      const playing = pairings.flatMap((p) => [p.home, p.away]);
      expect(new Set(playing).size).toBe(4); // nobody plays twice in a week
      for (const p of pairings) met.add([p.home, p.away ?? ''].sort((x, y) => x.localeCompare(y)).join('-'));
    }
    expect(met.size).toBe(6);
  });

  it('gives one member a bye each week when the count is odd', () => {
    const byes = [0, 1, 2].map(
      (round) => roundRobin(['a', 'b', 'c'], round).find((p) => p.away === null)?.home,
    );
    expect(new Set(byes)).toEqual(new Set(['a', 'b', 'c']));
  });

  it('starts the cycle again after the last round', () => {
    expect(roundRobin(['a', 'b', 'c', 'd'], 3)).toEqual(roundRobin(['a', 'b', 'c', 'd'], 0));
  });

  it('has nothing to pair for fewer than two members', () => {
    expect(roundRobin(['a'], 0)).toEqual([]);
  });
});

describe('leagueTable', () => {
  it('counts 3 for a win and 1 for a draw, with form and points for/against', () => {
    const table = leagueTable(
      ['a', 'b', 'c'],
      [
        { week: 1, home: 'a', away: 'b', homePoints: 120, awayPoints: 80 },
        { week: 2, home: 'b', away: 'c', homePoints: 50.2, awayPoints: 50 },
        { week: 3, home: 'c', away: 'a', homePoints: 90, awayPoints: 30 },
        { week: 3, home: 'b', away: null, homePoints: 0, awayPoints: 0 },
      ],
    );
    expect(table.map((r) => r.userId)).toEqual(['c', 'a', 'b']);
    expect(table[0]).toMatchObject({ played: 2, won: 1, drawn: 1, tablePoints: 4, form: ['D', 'W'] });
    expect(table[1]).toMatchObject({ won: 1, lost: 1, tablePoints: 3, pointsFor: 150, pointsAgainst: 170 });
    // The bye isn't a game played.
    expect(table[2]).toMatchObject({ played: 2, tablePoints: 1 });
  });

  it('calls scores within half a point a draw', () => {
    expect(outcome(10.4, 10)).toBe('D');
    expect(outcome(10.5, 10)).toBe('W');
  });
});
