import type { AuthUser } from '../../src/domain/dto.js';
import { NotificationsService } from '../../src/notifications/notifications.service.js';
import { PushService } from '../../src/notifications/push.service.js';
import { DAILY_PUSH_BUDGET } from '../../src/notifications/push-rules.js';
import { XStocksService } from '../../src/xstocks/xstocks.service.js';
import { createHarness } from './harness.js';
import type { Harness } from './harness.js';

/** SCORING_PLAN.md Phase 4: whatever notifies also pushes, within limits. */
describe('push notifications', () => {
  let h: Harness;
  let me: AuthUser;
  let push: PushService;
  let notifications: NotificationsService;

  beforeAll(async () => {
    h = await createHarness();
    push = h.app.get(PushService);
    notifications = h.app.get(NotificationsService);
  });
  afterAll(async () => {
    await h.close();
  });
  beforeEach(async () => {
    await h.reset();
    me = await h.createPlayer('me');
    // The test clock is 15:00 UTC: outside default quiet hours in UTC.
    await push.registerDevice(me.id, { token: 'device-token-1', platform: 'android', timeZone: 'UTC' });
  });

  const goal = () =>
    notifications.push({ userId: me.id, kind: 'goal', title: 'Goal! TSLAx scores', body: 'Provisional' });

  it('pushes what lands in the inbox, to every device the Manager registered', async () => {
    await push.registerDevice(me.id, { token: 'device-token-2', platform: 'web' });
    await goal();
    expect(h.pushes.sent.map((s) => s.token)).toEqual(['device-token-1', 'device-token-2']);
    expect(h.pushes.sent[0].message).toMatchObject({ title: 'Goal! TSLAx scores', data: { kind: 'goal' } });
    // The inbox has it too.
    expect(await notifications.unreadCount(me.id)).toBe(1);
  });

  it('respects a switched-off category, and quiet hours in the Manager\'s zone', async () => {
    await push.saveSettings(me.id, { categories: { goals: false } });
    await goal();
    expect(h.pushes.sent).toHaveLength(0);

    await push.saveSettings(me.id, { categories: { goals: true }, timeZone: 'Asia/Tokyo' });
    // 15:00 UTC is midnight in Tokyo: inside the default 22:00–08:00.
    await goal();
    expect(h.pushes.sent).toHaveLength(0);

    await push.saveSettings(me.id, { quietEnabled: false });
    await goal();
    expect(h.pushes.sent).toHaveLength(1);
    // Quiet or not, the inbox got all three.
    expect(await notifications.unreadCount(me.id)).toBe(3);
  });

  it('stops at the daily budget', async () => {
    for (let i = 0; i < DAILY_PUSH_BUDGET + 3; i++) await goal();
    expect(h.pushes.sent).toHaveLength(DAILY_PUSH_BUDGET);
  });

  it('forgets a device FCM says is gone', async () => {
    h.pushes.invalid.add('device-token-1');
    await goal();
    const tokens = await h.db.selectFrom('device_tokens').select('token').execute();
    expect(tokens).toEqual([]);
    expect((await push.settings(me.id)).devices).toBe(0);
  });

  it('pushes nothing at all without FCM credentials', async () => {
    h.pushes.enabled = false;
    await goal();
    expect(h.pushes.sent).toHaveLength(0);
    expect((await push.settings(me.id)).available).toBe(false);
  });

  it("tells a Manager when their captain stops scoring", async () => {
    await h.draft(me, 'football');
    const roster = await h.rosters.getRoster(me, 'football');
    const fwd = roster.slots.find((s) => s.stock?.mint === 'mint-TSLA')!;
    await h.rosters.setCaptaincy(me, 'football', { captainSlot: fwd.slotIndex, viceCaptainSlot: 0 });

    await h.priceTicks.tick(); // TSLA is scoring
    await h.db.updateTable('xstocks').set({ liquidity_usd: 10 }).where('mint', '=', 'mint-TSLA').execute();
    h.app.get(XStocksService).invalidate();
    h.clock.advance(30);
    await h.priceTicks.tick();

    const warning = h.pushes.sent.find((s) => s.message.title.startsWith("Your captain isn't scoring"));
    expect(warning?.message.title).toBe("Your captain isn't scoring: thin liquidity");
  });

  it('validates settings', async () => {
    await expect(push.saveSettings(me.id, { categories: { nonsense: true } })).rejects.toThrow('Unknown');
    await expect(push.saveSettings(me.id, { quietStart: 1440 })).rejects.toThrow('minutes');
    await expect(push.saveSettings(me.id, { timeZone: 'Mars/Olympus' })).rejects.toThrow('IANA');
    await expect(push.registerDevice(me.id, { token: 'x', platform: 'android' })).rejects.toThrow('token');
  });
});
