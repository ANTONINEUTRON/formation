import request from 'supertest';
import { signToken } from '../../src/auth/token.js';
import type { AuthUser } from '../../src/domain/dto.js';
import { StreakService } from '../../src/users/streak.service.js';
import { createHarness } from './harness.js';
import type { Harness } from './harness.js';

const DAY = 86_400_000;
/** FakeClock.advance takes minutes. */
const DAY_MIN = 24 * 60;
const HOUR_MIN = 60;

describe('daily check-in streak', () => {
  let h: Harness;
  let me: AuthUser;

  const token = (user: AuthUser) =>
    signToken({ sub: user.id, wallet: user.walletAddress, exp: Date.now() + DAY }, process.env.AUTH_SECRET!);
  /** Any signed-in request counts as a visit. */
  const visit = (user = me) =>
    request(h.app.getHttpServer()).get('/roster/football').set('Authorization', `Bearer ${token(user)}`).expect(200);
  const streakOf = async (user = me) =>
    (await h.db.selectFrom('users').select(['visit_streak', 'best_visit_streak']).where('id', '=', user.id).executeTakeFirstOrThrow());
  const streakNotes = (user = me) =>
    h.db.selectFrom('notifications').selectAll().where('kind', '=', 'streak').where('user_id', '=', user.id).execute();

  beforeAll(async () => {
    h = await createHarness();
  });
  afterAll(async () => {
    await h.close();
  });
  beforeEach(async () => {
    await h.reset();
    me = await h.createPlayer('regular');
  });

  it('counts one a day, holds within a day, and restarts after a missed day', async () => {
    await visit();
    await visit();
    expect(await streakOf()).toMatchObject({ visit_streak: 1 });

    h.clock.advance(DAY_MIN);
    await visit();
    h.clock.advance(DAY_MIN);
    await visit();
    expect(await streakOf()).toMatchObject({ visit_streak: 3, best_visit_streak: 3 });

    h.clock.advance(2 * DAY_MIN);
    await visit();
    expect(await streakOf()).toMatchObject({ visit_streak: 1, best_visit_streak: 3 });
  });

  it('announces a milestone once, and shows the streak on the leaderboard', async () => {
    await h.draft(me, 'football');
    for (let day = 0; day < 3; day++) {
      await visit();
      await visit();
      h.clock.advance(DAY_MIN);
    }
    const notes = await streakNotes();
    expect(notes).toHaveLength(1);
    expect(notes[0].title).toBe('3-day streak');

    // Still showing the day after the last visit; gone once a day is missed.
    const board = async () => (await h.league.leaderboard('football', me.id)).find((e) => e.userId === me.id)?.streak;
    expect(await board()).toBe(3);
    h.clock.advance(DAY_MIN);
    expect(await board()).toBe(0);
  });

  it('reminds an evening streak that has not been kept today, once', async () => {
    const streaks = h.app.get(StreakService);
    await h.db
      .insertInto('push_preferences')
      .values({ user_id: me.id, time_zone: 'UTC' })
      .execute();
    for (let day = 0; day < 4; day++) {
      await visit();
      h.clock.advance(DAY_MIN);
    }
    // The next day, before the evening: nothing yet.
    const now = new Date(h.clock.now());
    h.clock.set(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 12));
    expect(await streaks.remindAtRisk()).toBe(0);

    h.clock.advance(8 * HOUR_MIN); // 20:00 UTC
    expect(await streaks.remindAtRisk()).toBe(1);
    expect(await streaks.remindAtRisk()).toBe(0);
    const reminder = (await streakNotes()).find((n) => (n.data as { type?: string }).type === 'at_risk');
    expect(reminder?.title).toBe('Your 4-day streak ends at midnight');
  });
});
