import type { AuthUser } from '../../src/domain/dto.js';
import { createHarness } from './harness.js';
import type { Harness } from './harness.js';

describe('league', () => {
  let h: Harness;
  let me: AuthUser;

  beforeAll(async () => {
    h = await createHarness();
  });
  afterAll(async () => {
    await h.close();
  });
  beforeEach(async () => {
    await h.reset();
    me = await h.createPlayer('me');
  });

  const giveSeason = async (userId: string, points: number) => {
    await h.db
      .insertInto('classic_scores')
      .values({ user_id: userId, sport_mode: 'football', total_points: points })
      .onConflict((oc) =>
        oc.columns(['user_id', 'sport_mode']).doUpdateSet({ total_points: points }),
      )
      .execute();
  };

  it('ranks players by season points and marks the current user', async () => {
    const rival = await h.createPlayer('rival');
    await giveSeason(rival.id, 500);
    await giveSeason(me.id, 300);

    const board = await h.league.leaderboard('football', me.id);
    expect(board.map((e) => e.username)).toEqual(['rival', 'me']);
    expect(board[0].rank).toBe(1);
    expect(board[1]).toMatchObject({ rank: 2, isCurrentUser: true, points: 300 });
  });

  it('adds live gameweek points to the season total', async () => {
    await h.draft(me, 'football');
    await giveSeason(me.id, 100);
    await h.priceTicks.tick();

    h.clock.advance(30);
    h.prices.move('mint-TSLA', 1.05);
    await h.priceTicks.tick();

    const standing = (await h.league.standing(me.id, 'football'))!;
    expect(standing.gameweekPoints).toBeGreaterThan(0);
    expect(standing.points).toBe(100 + standing.gameweekPoints);

    const board = await h.league.leaderboard('football', me.id);
    expect(board[0].points).toBe(standing.points);
  });

  it('banks a finished gameweek into the season total exactly once', async () => {
    await h.draft(me, 'football');
    await h.priceTicks.tick();
    const first = (await h.gameweeks.current('football'))!;
    h.clock.advance(30);
    h.prices.move('mint-TSLA', 1.05);
    await h.priceTicks.tick();
    const live = (await h.league.standing(me.id, 'football'))!;

    h.clock.advance(40); // past the end: the gameweek closes and the next one opens
    await h.gameweeks.process();

    const season = await h.db
      .selectFrom('classic_scores')
      .select(['total_points', 'last_gameweek_points'])
      .where('user_id', '=', me.id)
      .where('sport_mode', '=', 'football')
      .executeTakeFirstOrThrow();
    // Prices didn't move after the live read, so the banked score equals it.
    expect(season.total_points).toBeCloseTo(live.gameweekPoints, 1);
    expect(season.last_gameweek_points).toBeCloseTo(live.gameweekPoints, 1);

    // Only the new gameweek's live points sit on top of the banked total.
    const next = (await h.gameweeks.current('football'))!;
    expect(next.id).not.toBe(first.id);
    const nextLive = (await h.gameweeks.livePointsByUser(next.id)).get(me.id) ?? 0;
    const standing = (await h.league.standing(me.id, 'football'))!;
    expect(standing.points).toBeCloseTo(season.total_points + nextLive, 1);
  });

  it('returns nothing for a player who has not drafted', async () => {
    expect(await h.league.standing(me.id, 'basketball')).toBeNull();
    expect(await h.league.leaderboard('basketball', me.id)).toEqual([]);
  });
});
