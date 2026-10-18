import type { AuthUser } from '../../src/domain/dto.js';
import type { LineupSnapshot } from '../../src/scoring/engine/types.js';
import { MarketDepthService } from '../../src/scoring/market-depth.service.js';
import { createHarness } from './harness.js';
import type { Harness } from './harness.js';

const TSLA = 'mint-TSLA';

/** SCORING_PLAN.md Phase 1, through real ticks of the general league. */
describe('scoring integrity', () => {
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
    await h.draft(me, 'football');
  });

  /** Base alpha banked. Flat prices also earn clean sheets, which aren't the point here. */
  const points = async () => {
    const row = await h.db
      .selectFrom('points_ledger')
      .select((eb) => eb.fn.sum<string>('points').as('total'))
      .where('user_id', '=', me.id)
      .where('kind', '=', 'alpha')
      .executeTakeFirst();
    return Number(row?.total ?? 0);
  };
  const tickAfter = async (minutes: number) => {
    h.clock.advance(minutes);
    await h.priceTicks.tick();
  };
  const entry = () =>
    h.db
      .selectFrom('general_entries')
      .selectAll()
      .where('user_id', '=', me.id)
      .where('sport_mode', '=', 'football')
      .executeTakeFirstOrThrow();

  it('opens a session on the first tick after the boundary, even at :03', async () => {
    // Sessions are ten minutes here; ticks land three minutes past.
    await tickAfter(3); // 12:03, baseline
    h.prices.move(TSLA, 1.05);
    await tickAfter(10); // 12:13, the first tick of the 12:10 session

    const opened = (await entry()).session_snapshot as LineupSnapshot;
    expect(opened.slots.find((s) => s.mint === TSLA)!.startPrice).toBeCloseTo(105);

    // TSLA doesn't move again, so its 12:10 session has no goal: events are
    // measured from the session's opening price, not the first price ever seen.
    await tickAfter(10); // 12:23 closes the 12:10 session
    const events = await h.db
      .selectFrom('points_ledger')
      .select('detail')
      .where('user_id', '=', me.id)
      .where('kind', '=', 'events')
      .execute();
    const goals = events.flatMap(
      (e) =>
        (e.detail as { slots: { mint: string; events: { code: string }[] }[] }).slots
          .filter((s) => s.mint === TSLA)
          .flatMap((s) => s.events.filter((ev) => ev.code === 'goal')),
    );
    expect(goals).toEqual([]);
  });

  it('a spike that reverts on the next tick banks nothing', async () => {
    await tickAfter(3);
    h.prices.move(TSLA, 1.4);
    await tickAfter(30);
    expect(await points()).toBe(0);

    h.prices.set(TSLA, 100);
    await tickAfter(30);
    expect(await points()).toBe(0);
  });

  it('a 15% step that persists banks a clamped 10%', async () => {
    await tickAfter(3);
    h.prices.move(TSLA, 1.15);
    await tickAfter(30); // held
    expect(await points()).toBe(0);

    await tickAfter(30); // still there: confirmed, clamped
    expect(await points()).toBe(100);
  });

  it("an asset that fails a requirement stops scoring and says why", async () => {
    // Buying and selling straight back would lose 12%: a market cheap to push around.
    h.depth.set(TSLA, 12);
    await h.app.get(MarketDepthService).checkAll();
    await tickAfter(3);

    const status = await h.db
      .selectFrom('asset_scoring_status')
      .selectAll()
      .where('mint', '=', TSLA)
      .executeTakeFirstOrThrow();
    expect(status).toMatchObject({ eligible: false, reason: 'thin_market' });

    h.prices.move(TSLA, 1.08);
    await tickAfter(30);
    expect(await points()).toBe(0);

    // Still on the team, still tradable, flagged everywhere it appears.
    const roster = await h.rosters.getRoster(me, 'football');
    const slot = roster.slots.find((s) => s.stock?.mint === TSLA)!;
    expect(slot.stock!.notScoring).toBe('thin market');
  });

  it('a paused stock can be placed in a slot, and banks nothing there', async () => {
    h.depth.set('mint-HOOD', 9);
    await h.app.get(MarketDepthService).checkAll();
    await tickAfter(3);

    const roster = await h.rosters.getRoster(me, 'football');
    const fwd = roster.slots.find((s) => s.stock?.mint === TSLA)!;
    const after = await h.rosters.fillSlot(me, 'football', fwd.slotIndex, 'mint-HOOD');
    expect(after.slots[fwd.slotIndex].stock).toMatchObject({ mint: 'mint-HOOD', notScoring: 'thin market' });

    const before = await points();
    h.prices.move('mint-HOOD', 1.08);
    await tickAfter(30);
    await tickAfter(30);
    expect(await points()).toBe(before);
  });

  it('a stock with no route at all is a thin market too', async () => {
    h.depth.set(TSLA, null);
    await h.app.get(MarketDepthService).checkAll();
    await tickAfter(3);
    const status = await h.db
      .selectFrom('asset_scoring_status')
      .select(['eligible', 'reason'])
      .where('mint', '=', TSLA)
      .executeTakeFirstOrThrow();
    expect(status).toEqual({ eligible: false, reason: 'thin_market' });
  });
});
