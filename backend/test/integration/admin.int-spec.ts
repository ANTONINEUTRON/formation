import request from 'supertest';
import { AdminHoldingsService } from '../../src/admin/holdings.service.js';
import { AdminManagersService } from '../../src/admin/managers-admin.service.js';
import { AuthService } from '../../src/auth/auth.service.js';
import { signToken } from '../../src/auth/token.js';
import type { AuthUser } from '../../src/domain/dto.js';
import { LeagueService } from '../../src/league/league.service.js';
import { ADMIN_WALLET, createHarness } from './harness.js';
import type { Harness } from './harness.js';

const REASON = 'Testing the admin dashboard';

describe('admin', () => {
  let h: Harness;
  let managers: AdminManagersService;
  let holdings: AdminHoldingsService;
  let admin: AuthUser;
  let player: AuthUser;

  const tokenFor = (user: AuthUser) =>
    signToken({ sub: user.id, wallet: user.walletAddress, exp: Date.now() + 3_600_000 }, process.env.AUTH_SECRET!);
  const http = () => request(h.app.getHttpServer());
  const asAdmin = () => ({ Authorization: `Bearer ${tokenFor(admin)}` });
  const actionCount = async () =>
    Number((await h.db.selectFrom('admin_actions').select((eb) => eb.fn.countAll<string>().as('n')).executeTakeFirstOrThrow()).n);

  beforeAll(async () => {
    h = await createHarness();
    managers = h.app.get(AdminManagersService);
    holdings = h.app.get(AdminHoldingsService);
  });
  afterAll(async () => {
    await h.close();
  });
  beforeEach(async () => {
    await h.reset();
    admin = await h.createPlayer('the_admin');
    player = await h.createPlayer('striker');
  });

  describe('access', () => {
    const routes: [string, string][] = [
      ['get', '/admin/me'],
      ['get', '/admin/health'],
      ['get', '/admin/actions'],
      ['get', '/admin/platform/users'],
      ['get', '/admin/platform/assets'],
      ['get', '/admin/assistant'],
      ['get', '/admin/feedback'],
      ['post', '/admin/tick'],
    ];

    it('refuses a Manager who is not on the allowlist, on every route', async () => {
      for (const [method, path] of routes) {
        const res = await (http() as unknown as Record<string, (p: string) => request.Test>)[method](path)
          .set('Authorization', `Bearer ${tokenFor(player)}`);
        expect([path, res.status]).toEqual([path, 403]);
      }
      await http().get(`/admin/managers/${player.id}`).set('Authorization', `Bearer ${tokenFor(player)}`).expect(403);
    });

    it('refuses no credentials and a wrong key', async () => {
      await http().get('/admin/me').expect(401);
      await http().get('/admin/me').set('x-admin-key', 'nope').expect(401);
    });

    it('lets an allowlisted wallet and the admin key in', async () => {
      const wallet = await http().get('/admin/me').set(asAdmin()).expect(200);
      expect(wallet.body).toEqual({ admin: true, as: ADMIN_WALLET });
      const key = await http().get('/admin/me').set('x-admin-key', process.env.ADMIN_KEY!).expect(200);
      expect(key.body).toEqual({ admin: true, as: 'key' });
    });

    it('keeps the old script endpoints working on the key, recording them', async () => {
      await http().post('/admin/tick').set('x-admin-key', process.env.ADMIN_KEY!).expect(201);
      const [row] = await h.db.selectFrom('admin_actions').selectAll().execute();
      expect(row).toMatchObject({ admin: 'key', action: 'ops.scoring.tick', reason: 'Script call (x-admin-key)' });
    });

    it('asks a wallet admin for a reason', async () => {
      await http().post('/admin/tick').set(asAdmin()).send({}).expect(400);
      await http().post('/admin/tick').set(asAdmin()).send({ reason: REASON }).expect(201);
    });
  });

  describe('audit', () => {
    it('records each write once, and nothing when the write fails', async () => {
      await managers.clearBio(ADMIN_WALLET, player.id, REASON);
      expect(await actionCount()).toBe(1);

      // Fails after the change starts: a correction over the limit.
      await expect(
        managers.correct(ADMIN_WALLET, player.id, { mode: 'football', points: 9999, reason: REASON }),
      ).rejects.toThrow('second confirmation');
      // Fails inside the transaction: a duplicate suspension.
      await managers.suspend(ADMIN_WALLET, player.id, REASON);
      await expect(managers.suspend(ADMIN_WALLET, player.id, REASON)).rejects.toThrow('Already suspended');
      expect(await actionCount()).toBe(2);

      await expect(managers.clearBio(ADMIN_WALLET, player.id, 'no')).rejects.toThrow('at least 5');
      expect(await actionCount()).toBe(2);
    });

    it('lists actions newest first, filterable by Manager', async () => {
      await managers.clearBio(ADMIN_WALLET, player.id, REASON);
      h.clock.advance(1);
      await managers.resetUsername(ADMIN_WALLET, player.id, REASON);
      const res = await http().get(`/admin/actions?userId=${player.id}`).set(asAdmin()).expect(200);
      expect(res.body.map((a: { action: string }) => a.action)).toEqual(['user.username_reset', 'user.bio_clear']);
      expect(res.body[0].detail).toMatchObject({ before: 'striker' });
    });
  });

  describe('moderation', () => {
    it('suspends: sign-in and existing sessions are refused, boards skip them; unsuspend restores', async () => {
      await h.draft(player, 'football');
      await managers.correct(ADMIN_WALLET, player.id, { mode: 'football', points: 25, reason: REASON });
      const board = () => h.app.get(LeagueService).leaderboard('football', admin.id);

      await managers.suspend(ADMIN_WALLET, player.id, REASON);
      await http().get('/roster/football').set('Authorization', `Bearer ${tokenFor(player)}`).expect(403);
      await expect(
        (h.app.get(AuthService) as unknown as { issue(w: string): Promise<unknown> }).issue(player.walletAddress),
      ).rejects.toThrow('suspended');
      const hidden = JSON.stringify(await board());
      expect(hidden).not.toContain(player.id);

      await managers.unsuspend(ADMIN_WALLET, player.id, REASON);
      await http().get('/roster/football').set('Authorization', `Bearer ${tokenFor(player)}`).expect(200);
      expect(JSON.stringify(await board())).toContain(player.id);
    });

    it('resets a username to the wallet-derived one and deletes a custom avatar', async () => {
      const { result } = await managers.resetUsername(ADMIN_WALLET, player.id, REASON);
      expect(result.username).toMatch(/^wall_/);
      await h.db
        .insertInto('assistant_profiles')
        .values({ user_id: player.id, character_id: 'custom', personality: 'scout', custom_name: 'Boss' })
        .execute();
      await h.db
        .insertInto('assistant_avatars')
        .values({ user_id: player.id, pose: 'neutral', mime: 'image/png', image: Buffer.alloc(4) })
        .execute();
      await managers.deleteAvatar(ADMIN_WALLET, player.id, REASON);
      const profile = await h.db.selectFrom('assistant_profiles').selectAll().where('user_id', '=', player.id).executeTakeFirstOrThrow();
      expect(profile).toMatchObject({ character_id: 'scout', custom_name: null });
    });
  });

  describe('corrections and credits', () => {
    it('corrects a score through the ledger, and needs a second confirmation past the limit', async () => {
      const out = await managers.correct(ADMIN_WALLET, player.id, { mode: 'basketball', points: -12.5, reason: REASON });
      expect(out.result).toMatchObject({ before: 0, after: -12.5 });
      const row = await h.db.selectFrom('points_ledger').selectAll().where('user_id', '=', player.id).executeTakeFirstOrThrow();
      expect(row).toMatchObject({ kind: 'correction', points: -12.5, sport_mode: 'basketball' });

      await managers.correct(ADMIN_WALLET, player.id, { mode: 'basketball', points: 600, reason: REASON, confirmLarge: true });
      const detail = await managers.detail(player.id);
      expect(detail.scores.find((s) => s.mode === 'basketball')?.seasonTotal).toBe(587.5);
    });

    it('grants and claws back credits, never below 0', async () => {
      const grant = await managers.adjustCredits(ADMIN_WALLET, player.id, { credits: 10, reason: REASON });
      const welcome = grant.result.before;
      expect(grant.result.balance).toBe(welcome + 10);

      const claw = await managers.adjustCredits(ADMIN_WALLET, player.id, { credits: -10_000, reason: REASON });
      expect(claw.result).toMatchObject({ balance: 0, applied: -(welcome + 10) });
      const last = await h.db.selectFrom('credit_ledger').selectAll().orderBy('id', 'desc').executeTakeFirstOrThrow();
      expect(last).toMatchObject({ reason: 'admin', balance_after: 0 });
    });
  });

  describe('deletion', () => {
    it('anonymises the account but keeps its points, and asks for the username', async () => {
      await h.draft(player, 'football');
      await managers.correct(ADMIN_WALLET, player.id, { mode: 'football', points: 40, reason: REASON });
      await h.db.updateTable('users').set({ email: 'striker@example.com', bio: 'Hi' }).where('id', '=', player.id).execute();

      await expect(
        managers.deleteAccount(ADMIN_WALLET, player.id, { reason: REASON, confirmUsername: 'wrong' }),
      ).rejects.toThrow('confirm');
      await managers.deleteAccount(ADMIN_WALLET, player.id, { reason: REASON, confirmUsername: 'striker' });

      const user = await h.db.selectFrom('users').selectAll().where('id', '=', player.id).executeTakeFirstOrThrow();
      expect(user).toMatchObject({ bio: null, email: null, wallet_address: `deleted:${player.id}` });
      expect(user.username).toMatch(/^deleted-/);
      expect(await h.db.selectFrom('rosters').selectAll().where('user_id', '=', player.id).execute()).toHaveLength(0);
      const points = await h.db.selectFrom('points_ledger').selectAll().where('user_id', '=', player.id).execute();
      expect(points.reduce((sum, r) => sum + r.points, 0)).toBe(40);

      const [record] = await h.db.selectFrom('admin_actions').selectAll().where('action', '=', 'user.delete').execute();
      expect(JSON.stringify(record)).not.toContain('striker');
      // The real wallet can start over as a new account.
      const again = await h.users.upsertByWallet(player.walletAddress);
      expect(again.id).not.toBe(player.id);
    });
  });

  describe('holdings and the list', () => {
    it('values catalogue xStocks only, counts unpriced as $0, and skips seeds', async () => {
      h.balances.setAll(player.walletAddress, ['mint-AAPL'], 2);
      h.balances.set(player.walletAddress, 'not-a-catalogue-mint', 500);
      h.balances.set(player.walletAddress, 'mint-NVDA', 1);
      h.prices.set('mint-AAPL', 150);
      h.prices.remove('mint-NVDA');
      const seed = await h.users.upsertByWallet('wallet-seed');
      await h.db.updateTable('users').set({ is_seed: true }).where('id', '=', seed.id).execute();

      const run = await holdings.runJob('job');
      expect(run.read).toBe(2); // the admin and the player; never the seed

      const overview = await holdings.overview();
      const aapl = overview.byStock.find((s) => s.symbol === 'AAPLx');
      expect(aapl?.usdValue).toBeGreaterThan(0);
      expect(overview.byStock.some((s) => s.mint === 'not-a-catalogue-mint')).toBe(false);
      expect(overview.byStock.find((s) => s.symbol === 'NVDAx')).toMatchObject({ amount: 11, usdValue: null }); // 10 each from createPlayer, plus 1
      expect(overview.walletsTotal).toBe(2);
      expect(overview.trend).toHaveLength(1);

      const usage = await holdings.rpcUsage();
      expect(usage.today.job).toBe(4);
    });

    it('reads only what is due, and stops at the daily budget', async () => {
      await holdings.runJob('job');
      const again = await holdings.runJob('job');
      expect(again.read).toBe(0); // read moments ago, under the re-read floor

      h.clock.advance(8 * 24 * 3_600_000);
      await h.db
        .insertInto('rpc_usage')
        .values({ day: new Date(h.clock.now()).toISOString().slice(0, 10), source: 'job', calls: 4999 })
        .execute();
      const capped = await holdings.runJob('job');
      expect(capped).toMatchObject({ read: 0, stoppedBy: 'budget' });
    });

    it('filters the Manager list by sign-up, activity and holdings', async () => {
      await h.db.updateTable('users').set({ created_at: new Date(h.clock.now() - 40 * 86_400_000) }).where('id', '=', admin.id).execute();
      await h.db.updateTable('users').set({ last_seen_at: h.clock.date() }).where('id', '=', player.id).execute();
      h.balances.setAll(player.walletAddress, ['mint-AAPL'], 3);
      await holdings.runJob('job');

      const list = (query: Record<string, string>) => managers.list(query);
      expect((await list({})).matching).toBe(2);
      expect((await list({ signedUp: '30d' })).rows.map((r) => r.username)).toEqual(['striker']);
      expect((await list({ active: '24h' })).rows.map((r) => r.username)).toEqual(['striker']);
      expect((await list({ holds: 'has', q: 'STRI' })).rows.map((r) => r.username)).toEqual(['striker']);
      expect((await list({ sort: 'username', dir: 'asc' })).rows.map((r) => r.username)).toEqual(['striker', 'the_admin']);

      const res = await http().get('/admin/platform/users?status=suspended').set(asAdmin()).expect(200);
      expect(res.body).toMatchObject({ matching: 0, total: 2 });
    });
  });

  it('reports health without failing on an empty database', async () => {
    const res = await http().get('/admin/health').set(asAdmin()).expect(200);
    expect(res.body.checks.map((c: { key: string }) => c.key)).toEqual(
      expect.arrayContaining(['price_tick', 'bank', 'stocks_priced', 'leagues', 'ai', 'database']),
    );
  });

  it('summarises the Assistant Manager for the last 30 days', async () => {
    const res = await http().get('/admin/assistant').set(asAdmin()).expect(200);
    expect(res.body.days).toHaveLength(30);
  });
});
