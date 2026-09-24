import type { AuthUser } from '../../src/domain/dto.js';
import { createHarness } from './harness.js';
import type { Harness } from './harness.js';

describe('gameweeks', () => {
  let h: Harness;
  let player: AuthUser;

  beforeAll(async () => {
    h = await createHarness();
  });
  afterAll(async () => {
    await h.close();
  });
  beforeEach(async () => {
    await h.reset();
    player = await h.createPlayer('scorer');
  });

  const entryOf = (userId: string, gameweekId: string) =>
    h.db
      .selectFrom('score_entries')
      .selectAll()
      .where('context', '=', 'gameweek')
      .where('context_id', '=', gameweekId)
      .where('user_id', '=', userId)
      .executeTakeFirst();

  it('opens the window covering now, aligned to the anchor', async () => {
    const gameweek = await h.gameweeks.ensureCurrent('football');
    expect(new Date(gameweek.starts_at).toISOString()).toBe('2026-01-05T12:00:00.000Z');
    expect(new Date(gameweek.ends_at).toISOString()).toBe('2026-01-05T13:00:00.000Z');
    expect(gameweek.number).toBe(13); // 12 hours after the anchor, hourly windows
    expect(gameweek.status).toBe('live');
  });

  it('locks only complete rosters', async () => {
    const halfDrafted = await h.createPlayer('half');
    await h.rosters.fillSlot(halfDrafted, 'football', 0, 'mint-AAPL');
    await h.draft(player, 'football');

    const gameweek = await h.gameweeks.ensureCurrent('football');
    expect(await h.gameweeks.enterRosters(gameweek)).toBe(1);
    expect(await entryOf(player.id, gameweek.id)).toBeDefined();
    expect(await entryOf(halfDrafted.id, gameweek.id)).toBeUndefined();
  });

  it('scores live points as prices move, beating the benchmark', async () => {
    await h.draft(player, 'football');
    await h.priceTicks.tick(); // opens the gameweek and records the starting prices

    const gameweek = (await h.gameweeks.current('football'))!;
    h.clock.advance(20);
    h.prices.move('mint-TSLA', 1.05); // a forward runs
    await h.priceTicks.tick();

    const entry = await entryOf(player.id, gameweek.id);
    expect(Number(entry!.live_points)).toBeGreaterThan(0);

    const dto = await h.gameweeks.dtoFor(gameweek, player.id);
    const tsla = dto.slots.find((s) => s.mint === 'mint-TSLA')!;
    expect(tsla.ownReturn).toBeCloseTo(0.05, 6);
    expect(tsla.events.some((e) => e.code === 'goal')).toBe(true);
    expect(dto.entered).toBe(true);
  });

  it('doubles the captain and lets a sold pick score nothing', async () => {
    await h.draft(player, 'football');
    await h.rosters.setCaptaincy(player, 'football', { captainSlot: 9 }); // first forward
    await h.priceTicks.tick();

    h.clock.advance(20);
    h.prices.move('mint-TSLA', 1.04);
    h.prices.move('mint-HOOD', 1.10);
    h.balances.set(player.walletAddress, 'mint-HOOD', 0); // sold mid-window
    await h.priceTicks.tick();

    const gameweek = (await h.gameweeks.current('football'))!;
    const dto = await h.gameweeks.dtoFor(gameweek, player.id);
    expect(dto.slots.find((s) => s.mint === 'mint-TSLA')!.multiplier).toBe(2);
    expect(dto.slots.find((s) => s.mint === 'mint-HOOD')).toMatchObject({
      counted: false,
      total: 0,
    });
  });

  it('finalises once, adding the score to the season total', async () => {
    await h.draft(player, 'football');
    await h.priceTicks.tick();
    const gameweek = (await h.gameweeks.current('football'))!;

    h.clock.advance(30);
    h.prices.move('mint-TSLA', 1.06);
    await h.priceTicks.tick();

    h.clock.advance(40); // past the end of the window
    await h.gameweeks.process();

    const closed = await h.db
      .selectFrom('gameweeks')
      .selectAll()
      .where('id', '=', gameweek.id)
      .executeTakeFirstOrThrow();
    expect(closed.status).toBe('final');

    const entry = await entryOf(player.id, gameweek.id);
    const finalPoints = Number(entry!.final_points);
    expect(finalPoints).toBeGreaterThan(0);

    const total = async () =>
      Number(
        (
          await h.db
            .selectFrom('classic_scores')
            .select('total_points')
            .where('user_id', '=', player.id)
            .where('sport_mode', '=', 'football')
            .executeTakeFirstOrThrow()
        ).total_points,
      );
    expect(await total()).toBe(finalPoints);

    // Closing again must not double-count.
    await h.gameweeks.close(closed);
    await h.gameweeks.process();
    expect(await total()).toBe(finalPoints);
  });

  it('locks the lineup: mid-gameweek changes wait for the next window', async () => {
    await h.draft(player, 'football');
    await h.priceTicks.tick();
    const gameweek = (await h.gameweeks.current('football'))!;

    await h.rosters.setFormation(player, 'football', '3-5-2');
    const locked = await h.gameweeks.lockedSnapshot(gameweek.id, player.id);
    expect(locked!.formation).toBe('4-4-2');
    expect(
      await h.gameweeks.hasPendingChanges(
        gameweek.id,
        player.id,
        player.walletAddress,
        'football',
      ),
    ).toBe(true);
  });

  it('enters a team finished mid-gameweek into the next one', async () => {
    const latecomer = await h.createPlayer('late');
    await h.priceTicks.tick();
    const first = (await h.gameweeks.current('football'))!;
    expect(await entryOf(latecomer.id, first.id)).toBeUndefined();

    await h.draft(latecomer, 'football');
    const next = await h.gameweeks.advance('football');
    expect(next.id).not.toBe(first.id);
    expect(await entryOf(latecomer.id, next.id)).toBeDefined();
  });
});
