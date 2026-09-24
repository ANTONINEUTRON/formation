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

    // 4. Open the gameweek and let prices move.
    await http.post('/admin/tick').set('x-admin-key', adminKey).expect(201);
    h.clock.advance(30);
    h.prices.move('mint-TSLA', 1.06);
    await http.post('/admin/tick').set('x-admin-key', adminKey).expect(201);

    const live = await http.get('/roster/football').set(auth).expect(200);
    expect(live.body.gameweek.entered).toBe(true);
    expect(live.body.gameweek.points).toBeGreaterThan(0);
    expect(live.body.gameweek.slots.length).toBeGreaterThan(0);
    sample('roster-football', live.body);

    const current = await http.get('/gameweeks/football/current').set(auth).expect(200);
    expect(current.body.id).toBe(live.body.gameweek.id);
    sample('gameweek-current', current.body);

    // 5. Close the gameweek: points land on the leaderboard.
    await http
      .post('/admin/gameweeks/football/advance')
      .set('x-admin-key', adminKey)
      .expect(201);
    const league = await http.get('/league/football').set(auth).expect(200);
    const mine = league.body.find((e: { isCurrentUser: boolean }) => e.isCurrentUser);
    expect(mine.points).toBeGreaterThan(0);
    expect(mine.rank).toBe(1);
    sample('league-football', league.body);

    // 6. Duel a second wallet and settle it.
    const bob = await signIn();
    await draft(bob.token, 'football');
    const created = await http
      .post('/duels')
      .set(auth)
      .send({ mode: 'football', opponent: bob.wallet, durationHours: 1 })
      .expect(201);
    await http
      .post(`/duels/${created.body.id}/accept`)
      .set('authorization', `Bearer ${bob.token}`)
      .expect(201);

    h.clock.advance(30);
    h.prices.move('mint-TSLA', 1.08);
    await http.post('/admin/tick').set('x-admin-key', adminKey).expect(201);
    h.balances.set(bob.wallet, 'mint-TSLA', 0); // Bob sells his forward
    h.clock.advance(31);

    const settled = await http
      .post(`/admin/duels/${created.body.id}/settle`)
      .set('x-admin-key', adminKey)
      .expect(201);
    expect(settled.body.status).toBe('settled');
    expect(settled.body.winnerId).not.toBeNull();

    const duels = await http.get('/duels?mode=football').set(auth).expect(200);
    expect(duels.body[0].status).toBe('settled');
    sample('duels-football', duels.body);

    const trophies = await http.get('/trophies').set(auth).expect(200);
    sample('trophies', trophies.body);
  });

  it('decides a basketball duel on categories', async () => {
    await h.reset();
    const alice = await signIn();
    const bob = await signIn();
    await draft(alice.token, 'basketball');
    await draft(bob.token, 'basketball');
    await http.post('/admin/tick').set('x-admin-key', adminKey).expect(201);

    const duel = await http
      .post('/duels')
      .set('authorization', `Bearer ${alice.token}`)
      .send({ mode: 'basketball', opponent: bob.wallet, durationHours: 1 })
      .expect(201);
    await http
      .post(`/duels/${duel.body.id}/accept`)
      .set('authorization', `Bearer ${bob.token}`)
      .expect(201);

    h.clock.advance(30);
    h.prices.move('mint-NVDA', 1.05);
    await http.post('/admin/tick').set('x-admin-key', adminKey).expect(201);
    h.balances.set(bob.wallet, 'mint-NVDA', 0);
    h.clock.advance(31);

    const settled = await http
      .post(`/admin/duels/${duel.body.id}/settle`)
      .set('x-admin-key', adminKey)
      .expect(201);
    expect(settled.body.categories).toHaveLength(5);
    sample('duel-basketball-settled', settled.body);
  });
});
