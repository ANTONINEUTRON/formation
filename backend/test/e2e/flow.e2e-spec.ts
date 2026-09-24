import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import bs58 from 'bs58';
import request from 'supertest';
import nacl from 'tweetnacl';
import { rosterShape } from '../../src/domain/sport.js';
import type { SportMode } from '../../src/domain/sport.js';
import { BENCHMARK_MINT, createHarness, TEST_STOCKS } from '../integration/harness.js';
import type { Harness } from '../integration/harness.js';

/**
 * The whole demo script over HTTP: sign in with a wallet, draft, change
 * formation, captain a pick, run gameweeks, and settle a duel.
 *
 * Responses are saved to test/contract/*.json so the app's parser tests run
 * against real backend output.
 */
const CONTRACT_DIR = join(dirname(fileURLToPath(import.meta.url)), '../contract');

describe('Formation flow (e2e)', () => {
  let h: Harness;
  let http: ReturnType<typeof request>;
  let adminKey = '';

  beforeAll(async () => {
    h = await createHarness();
    adminKey = process.env.ADMIN_KEY!;
    http = request(h.app.getHttpServer());
    mkdirSync(CONTRACT_DIR, { recursive: true });
  });
  afterAll(async () => {
    await h.close();
  });

  const sample = (name: string, body: unknown) =>
    writeFileSync(join(CONTRACT_DIR, `${name}.json`), JSON.stringify(body, null, 2));

  /** Signs in a fresh wallet the way the app does (MWA message signing). */
  async function signIn(): Promise<{ token: string; wallet: string }> {
    const keypair = nacl.sign.keyPair();
    const wallet = bs58.encode(keypair.publicKey);

    const challenge = await http
      .post('/auth/challenge')
      .send({ walletAddress: wallet })
      .expect(201);
    const signature = nacl.sign.detached(
      new TextEncoder().encode(challenge.body.message as string),
      keypair.secretKey,
    );
    const verified = await http
      .post('/auth/verify')
      .send({ walletAddress: wallet, signature: bs58.encode(signature) })
      .expect(201);

    h.balances.setAll(
      wallet,
      TEST_STOCKS.map((s) => s.mint),
      10,
    );
    return { token: verified.body.token as string, wallet };
  }

  async function draft(token: string, mode: SportMode, formation?: string) {
    if (formation) {
      await http
        .put(`/roster/${mode}/formation`)
        .set('authorization', `Bearer ${token}`)
        .send({ formation })
        .expect(200);
    }
    const roster = await http
      .get(`/roster/${mode}`)
      .set('authorization', `Bearer ${token}`)
      .expect(200);

    const slots = roster.body.slots as { slotIndex: number; stock: { mint: string } | null }[];
    // Stocks already on the team can't be picked again.
    const used = new Set<string>(slots.flatMap((s) => (s.stock ? [s.stock.mint] : [])));
    for (const slot of slots) {
      if (slot.stock) continue;
      const tier = rosterShape(mode, roster.body.formation)[slot.slotIndex].tier;
      const stock = TEST_STOCKS.find(
        (s) => s.mint !== BENCHMARK_MINT && !used.has(s.mint) && (tier === null || s.tier === tier),
      )!;
      used.add(stock.mint);
      await http
        .put(`/roster/${mode}/slots/${slot.slotIndex}`)
        .set('authorization', `Bearer ${token}`)
        .send({ mint: stock.mint })
        .expect(200);
    }
  }

  it('serves a health check', async () => {
    await http.get('/').expect(200);
  });

  it('rejects unauthenticated and unsigned requests', async () => {
    await http.get('/roster/football').expect(401);
    await http.post('/admin/tick').expect(401);
    await http
      .post('/auth/verify')
      .send({ walletAddress: bs58.encode(nacl.sign.keyPair().publicKey), signature: bs58.encode(new Uint8Array(64)) })
      .expect(401);
  });

  it('walks the demo script end to end', async () => {
    await h.reset();
    const alice = await signIn();
    const auth = { authorization: `Bearer ${alice.token}` };

    // 1. The stock pool is public.
    const stocks = await http.get('/xstocks').expect(200);
    expect(stocks.body.length).toBe(TEST_STOCKS.length);
    sample('xstocks', stocks.body.slice(0, 3));

    // 2. Draft a football team, then switch shape: a pick drops out.
    await draft(alice.token, 'football');
    const changed = await http
      .put('/roster/football/formation')
      .set(auth)
      .send({ formation: '3-5-2' })
      .expect(200);
    expect(changed.body.dropped).toHaveLength(1);
    expect(changed.body.roster.formation).toBe('3-5-2');
    sample('formation-change', changed.body);

    // 3. Fill the new midfield slot and hand out the armbands.
    await draft(alice.token, 'football');
    const captained = await http
      .put('/roster/football/captain')
      .set(auth)
      .send({ captainSlot: 9, viceCaptainSlot: 0 })
      .expect(200);
    expect(captained.body.captainSlot).toBe(9);

    // 4. Prices move and points bank on the tick itself.
    await http.post('/admin/tick').set('x-admin-key', adminKey).expect(201);
    h.clock.advance(30);
    h.prices.move('mint-TSLA', 1.06);
    await http.post('/admin/tick').set('x-admin-key', adminKey).expect(201);

    const live = await http.get('/roster/football').set(auth).expect(200);
    expect(live.body.session.entered).toBe(true);
    expect(live.body.session.points).toBeGreaterThan(0);
    expect(live.body.session.freeSubstitutionsLeft).toBe(3);
    expect(live.body.bench.length).toBeGreaterThan(0);
    sample('roster-football', live.body);

    // 5. No window has to close: the leaderboard already has the points.
    const league = await http.get('/league/football').set(auth).expect(200);
    const mine = league.body.find((e: { isCurrentUser: boolean }) => e.isCurrentUser);
    expect(mine.points).toBeGreaterThan(0);
    expect(mine.rank).toBe(1);
    sample('league-football', league.body);

    // Weekly and custom views read the same ledger.
    const weekly = await http.get('/league/football?period=weekly').set(auth).expect(200);
    expect(weekly.body.find((e: { isCurrentUser: boolean }) => e.isCurrentUser).points)
      .toBeGreaterThan(0);

    // 6. Substituting a bench stock in: the first three a day are free.
    const benchPick = live.body.bench[0] as {
      stock: { mint: string };
      eligibleSlots: number[];
    };
    await http
      .put(`/roster/football/slots/${benchPick.eligibleSlots[0]}`)
      .set(auth)
      .send({ mint: benchPick.stock.mint })
      .expect(200);
    const afterSub = await http.get('/roster/football').set(auth).expect(200);
    expect(afterSub.body.session.substitutionsUsed).toBe(1);
    expect(afterSub.body.session.freeSubstitutionsLeft).toBe(2);

    // 7. A PvP duel is a two-player private league.
    const bob = await signIn();
    await draft(bob.token, 'football');
    const created = await http
      .post('/leagues')
      .set(auth)
      .send({
        name: 'Alice vs Bob',
        mode: 'football',
        visibility: 'private',
        startsAt: new Date(h.clock.now() + 60_000).toISOString(),
        durationHours: 1,
        maxMembers: 2,
        opponent: bob.wallet,
      })
      .expect(201);
    expect(created.body.memberCount).toBe(2);
    expect(created.body.status).toBe('scheduled');
    sample('league-created', created.body);

    h.clock.advance(30);
    h.prices.move('mint-TSLA', 1.08);
    await http.post('/admin/tick').set('x-admin-key', adminKey).expect(201);

    await http
      .post(`/admin/leagues/${created.body.id}/settle`)
      .set('x-admin-key', adminKey)
      .expect(201);

    const settled = await http.get(`/leagues/${created.body.id}`).set(auth).expect(200);
    expect(settled.body.status).toBe('final');
    expect(settled.body.standings).toHaveLength(2);
    expect(settled.body.standings[0].rank).toBe(1);
    sample('league-settled', settled.body);
  });

  it('shows a manager profile, follows them, and notifies both sides', async () => {
    await h.reset();
    const alice = await signIn();
    const bob = await signIn();
    await draft(alice.token, 'football');
    await draft(bob.token, 'football');
    await http.post('/admin/tick').set('x-admin-key', adminKey).expect(201);

    const bobId = (
      await http
        .get('/league/football')
        .set('authorization', `Bearer ${bob.token}`)
        .expect(200)
    ).body.find((e: { isCurrentUser: boolean }) => e.isCurrentUser).userId as string;

    // Alice can read Bob's public wallet and lineup.
    const profile = await http
      .get(`/managers/${bobId}?mode=football`)
      .set('authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(profile.body.username).toBeTruthy();
    expect(profile.body.holdings.length).toBeGreaterThan(0);
    expect(profile.body.lineup.length).toBeGreaterThan(0);
    expect(profile.body.holdings.some((h: { starting: boolean }) => h.starting)).toBe(true);
    expect(profile.body.following).toBe(false);
    expect(profile.body.isCurrentUser).toBe(false);
    sample('manager-profile', profile.body);

    // Following is idempotent and reflected on the next read.
    await http
      .post(`/managers/${bobId}/follow`)
      .set('authorization', `Bearer ${alice.token}`)
      .expect(201);
    await http
      .post(`/managers/${bobId}/follow`)
      .set('authorization', `Bearer ${alice.token}`)
      .expect(201);

    const followed = await http
      .get(`/managers/${bobId}?mode=football`)
      .set('authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(followed.body.following).toBe(true);
    expect(followed.body.followers).toBe(1);

    // Bob was told once, not twice.
    const bobInbox = await http
      .get('/notifications')
      .set('authorization', `Bearer ${bob.token}`)
      .expect(200);
    const followNotes = bobInbox.body.filter(
      (n: { kind: string }) => n.kind === 'new_follower',
    );
    expect(followNotes).toHaveLength(1);
    sample('notifications', bobInbox.body);

    // Bob substitutes: his follower hears about it.
    const bobRoster = await http
      .get('/roster/football')
      .set('authorization', `Bearer ${bob.token}`)
      .expect(200);
    const bench = bobRoster.body.bench as {
      stock: { mint: string };
      eligibleSlots: number[];
    }[];
    expect(bench.length).toBeGreaterThan(0);
    await http
      .put(`/roster/football/slots/${bench[0].eligibleSlots[0]}`)
      .set('authorization', `Bearer ${bob.token}`)
      .send({ mint: bench[0].stock.mint })
      .expect(200);

    const aliceInbox = await http
      .get('/notifications')
      .set('authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(
      aliceInbox.body.some((n: { kind: string }) => n.kind === 'manager_move'),
    ).toBe(true);

    // Unread count drops to zero once she reads them.
    const before = await http
      .get('/notifications/unread-count')
      .set('authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(before.body.count).toBeGreaterThan(0);
    await http
      .post('/notifications/read-all')
      .set('authorization', `Bearer ${alice.token}`)
      .expect(201);
    const after = await http
      .get('/notifications/unread-count')
      .set('authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(after.body.count).toBe(0);

    // You cannot follow yourself.
    const aliceId = (
      await http
        .get('/league/football')
        .set('authorization', `Bearer ${alice.token}`)
        .expect(200)
    ).body.find((e: { isCurrentUser: boolean }) => e.isCurrentUser).userId as string;
    await http
      .post(`/managers/${aliceId}/follow`)
      .set('authorization', `Bearer ${alice.token}`)
      .expect(400);
  });

  it('lists public leagues and lets another player join by code', async () => {
    await h.reset();
    const alice = await signIn();
    const bob = await signIn();
    await draft(alice.token, 'basketball');
    await draft(bob.token, 'basketball');

    const created = await http
      .post('/leagues')
      .set('authorization', `Bearer ${alice.token}`)
      .send({
        name: 'Open Hoops',
        mode: 'basketball',
        visibility: 'public',
        startsAt: new Date(h.clock.now() + 3_600_000).toISOString(),
        durationHours: 24,
      })
      .expect(201);
    expect(created.body.joinable).toBe(false); // the creator is already in

    const browse = await http
      .get('/leagues?mode=basketball')
      .set('authorization', `Bearer ${bob.token}`)
      .expect(200);
    expect(browse.body.map((l: { id: string }) => l.id)).toContain(created.body.id);
    expect(browse.body[0].joinable).toBe(true);
    sample('leagues-browse', browse.body);

    const joined = await http
      .post('/leagues/join')
      .set('authorization', `Bearer ${bob.token}`)
      .send({ code: created.body.joinCode })
      .expect(201);
    expect(joined.body.memberCount).toBe(2);
    expect(joined.body.joined).toBe(true);

    // Joining twice is harmless, and a started league is closed to newcomers.
    await http
      .post('/leagues/join')
      .set('authorization', `Bearer ${bob.token}`)
      .send({ code: created.body.joinCode })
      .expect(201);
  });
});
