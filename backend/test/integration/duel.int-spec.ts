import type { AuthUser } from '../../src/domain/dto.js';
import { createHarness } from './harness.js';
import type { Harness } from './harness.js';

describe('duels', () => {
  let h: Harness;
  let alice: AuthUser;
  let bob: AuthUser;

  beforeAll(async () => {
    h = await createHarness();
  });
  afterAll(async () => {
    await h.close();
  });
  beforeEach(async () => {
    await h.reset();
    alice = await h.createPlayer('alice');
    bob = await h.createPlayer('bob');
  });

  const challenge = async (mode: 'football' | 'basketball') => {
    await h.draft(alice, mode);
    await h.draft(bob, mode);
    await h.priceTicks.tick();
    const duel = await h.duels.create(alice, mode, 'bob', 1);
    return h.duels.respond(bob, duel.id, true);
  };

  it('needs a finished team, a real opponent, and not yourself', async () => {
    await expect(h.duels.create(alice, 'football', 'bob', 1)).rejects.toThrow(
      'Finish your team',
    );
    await h.draft(alice, 'football');
    await expect(h.duels.create(alice, 'football', 'nobody', 1)).rejects.toThrow(
      'No Formation player found',
    );
    await expect(h.duels.create(alice, 'football', 'alice', 1)).rejects.toThrow(
      "can't duel yourself",
    );
    await expect(h.duels.create(alice, 'football', 'bob', 5)).rejects.toThrow('durationHours');
  });

  it('locks both lineups on accept and sets the window', async () => {
    const duel = await challenge('football');
    expect(duel.status).toBe('active');
    expect(duel.startTime).not.toBeNull();
    expect(new Date(duel.endTime!).getTime() - new Date(duel.startTime!).getTime()).toBe(3_600_000);

    const entries = await h.db
      .selectFrom('score_entries')
      .select('user_id')
      .where('context', '=', 'duel')
      .where('context_id', '=', duel.id)
      .execute();
    expect(entries.map((e) => e.user_id).sort()).toEqual([alice.id, bob.id].sort());
  });

  it('lets the challenged player decline', async () => {
    await h.draft(alice, 'football');
    await h.draft(bob, 'football');
    const duel = await h.duels.create(alice, 'football', 'bob', 1);
    expect((await h.duels.respond(bob, duel.id, false)).status).toBe('declined');
    await expect(h.duels.respond(bob, duel.id, true)).rejects.toThrow('no longer pending');
  });

  it('only the challenged player can respond', async () => {
    await h.draft(alice, 'football');
    await h.draft(bob, 'football');
    const duel = await h.duels.create(alice, 'football', 'bob', 1);
    await expect(h.duels.respond(alice, duel.id, true)).rejects.toThrow(
      'Only the challenged player',
    );
  });

  it('settles on points, records a trophy and a streak', async () => {
    const duel = await challenge('football');

    h.clock.advance(30);
    h.prices.move('mint-TSLA', 1.08); // both hold TSLAx, but Alice captains it
    await h.rosters.setCaptaincy(alice, 'football', { captainSlot: 9 });
    await h.priceTicks.tick();

    // The armband applies from the next window, so give Alice a real edge:
    // sell Bob's best forward so it stops counting.
    h.balances.set(bob.walletAddress, 'mint-TSLA', 0);
    h.clock.advance(31);
    const settled = await h.duels.settle(duel.id, alice.id);

    expect(settled.status).toBe('settled');
    expect(settled.challengerPoints).toBeGreaterThan(settled.opponentPoints!);
    expect(settled.winnerId).toBe(alice.id);

    const trophies = await h.trophies.list(alice.id);
    expect(trophies).toHaveLength(1);
    expect(trophies[0].title).toContain('bob');

    const streak = await h.db
      .selectFrom('classic_scores')
      .select('streak')
      .where('user_id', '=', alice.id)
      .where('sport_mode', '=', 'football')
      .executeTakeFirstOrThrow();
    expect(streak.streak).toBe(1);
  });

  it('settles a basketball duel on categories', async () => {
    const duel = await challenge('basketball');

    h.clock.advance(30);
    h.prices.move('mint-NVDA', 1.05);
    await h.priceTicks.tick();
    h.balances.set(bob.walletAddress, 'mint-NVDA', 0);

    h.clock.advance(31);
    const settled = await h.duels.settle(duel.id, alice.id);
    expect(settled.categories).toHaveLength(5);
    expect(settled.categories!.map((c) => c.name)).toContain('Best pick');
    expect(settled.winnerId).toBe(alice.id);
  });

  it('settles once, even when the cron and an admin race', async () => {
    const duel = await challenge('football');
    h.clock.advance(61);

    const racing = await Promise.allSettled([h.duels.settle(duel.id), h.duels.settle(duel.id)]);
    expect(racing.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    expect(racing.find((r) => r.status === 'rejected')).toMatchObject({
      reason: expect.objectContaining({ message: expect.stringContaining('already settled') }),
    });

    // A later attempt is turned away by the status guard.
    await expect(h.duels.settle(duel.id)).rejects.toThrow('not active');

    const settled = (await h.duels.list(alice, 'football'))[0];
    const trophies = settled.winnerId ? await h.trophies.list(settled.winnerId) : [];
    expect(trophies).toHaveLength(settled.winnerId ? 1 : 0);
  });

  it('settles duels whose window has ended', async () => {
    const duel = await challenge('football');
    h.clock.advance(61);
    await h.duels.settleDue();
    expect((await h.duels.list(alice, 'football'))[0].status).toBe('settled');
    expect(duel.status).toBe('active'); // the DTO returned at accept time
  });
});
