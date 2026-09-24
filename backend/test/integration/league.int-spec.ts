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

  it('banks points on every tick without waiting for a window to close', async () => {
    await h.draft(me, 'football');
    await giveSeason(me.id, 100);
    // The first tick only takes the baseline; nothing is owed yet.
    await h.priceTicks.tick();
    expect((await h.league.standing(me.id, 'football'))!.points).toBe(100);

    h.clock.advance(30);
    h.prices.move('mint-TSLA', 1.05);
    await h.priceTicks.tick();

    const standing = (await h.league.standing(me.id, 'football'))!;
    expect(standing.points).toBeGreaterThan(100);
    expect(standing.todayPoints).toBeGreaterThan(0);

    const board = await h.league.leaderboard('football', me.id);
    expect(board[0].points).toBe(standing.points);
  });

  it('accumulates across ticks instead of recomputing from the start', async () => {
    await h.draft(me, 'football');
    await h.priceTicks.tick();

    h.clock.advance(30);
    h.prices.move('mint-TSLA', 1.05);
    await h.priceTicks.tick();
    const afterFirst = (await h.league.standing(me.id, 'football'))!.points;

    h.clock.advance(30);
    h.prices.move('mint-TSLA', 1.05);
    await h.priceTicks.tick();
    const afterSecond = (await h.league.standing(me.id, 'football'))!.points;

    expect(afterFirst).toBeGreaterThan(0);
    expect(afterSecond).toBeGreaterThan(afterFirst);

    // Every movement is on the ledger, and the two must agree.
    const ledger = await h.db
      .selectFrom('points_ledger')
      .select((eb) => eb.fn.sum<string>('points').as('total'))
      .where('user_id', '=', me.id)
      .where('sport_mode', '=', 'football')
      .executeTakeFirstOrThrow();
    expect(Number(ledger.total)).toBeCloseTo(afterSecond, 1);
  });

  it('ticking again with no time elapsed banks nothing extra', async () => {
    await h.draft(me, 'football');
    await h.priceTicks.tick();
    h.clock.advance(30);
    h.prices.move('mint-TSLA', 1.05);
    await h.priceTicks.tick();

    const before = (await h.league.standing(me.id, 'football'))!.points;
    await h.priceTicks.tick();
    expect((await h.league.standing(me.id, 'football'))!.points).toBeCloseTo(before, 1);
  });

  it('returns nothing for a player who has not drafted', async () => {
    expect(await h.league.standing(me.id, 'basketball')).toBeNull();
    expect(await h.league.leaderboard('basketball', me.id)).toEqual([]);
  });
});
