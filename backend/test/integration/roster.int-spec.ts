import type { AuthUser } from '../../src/domain/dto.js';
import { createHarness } from './harness.js';
import type { Harness } from './harness.js';

describe('rosters', () => {
  let h: Harness;
  let user: AuthUser;

  beforeAll(async () => {
    h = await createHarness();
  });
  afterAll(async () => {
    await h.close();
  });
  beforeEach(async () => {
    await h.reset();
    user = await h.createPlayer('drafter');
  });

  it('starts football at 4-4-2 with eleven empty slots', async () => {
    const roster = await h.rosters.getRoster(user, 'football');
    expect(roster.formation).toBe('4-4-2');
    expect(roster.slots).toHaveLength(11);
    expect(roster.slots.map((s) => s.positionLabel)).toEqual([
      'GK', 'DEF', 'DEF', 'DEF', 'DEF', 'MID', 'MID', 'MID', 'MID', 'FWD', 'FWD',
    ]);
    expect(roster.slots.every((s) => s.stock === null)).toBe(true);
    expect(await h.rosters.isComplete(user.id, 'football')).toBe(false);
  });

  it('fills a slot with a held, tier-matching stock', async () => {
    const roster = await h.rosters.fillSlot(user, 'football', 0, 'mint-AAPL');
    expect(roster.slots[0].stock?.symbol).toBe('AAPLx');
    expect(roster.slots[0].balance).toBe(10);
  });

  it('rejects the wrong tier, an unheld stock and a duplicate pick', async () => {
    await expect(h.rosters.fillSlot(user, 'football', 0, 'mint-TSLA')).rejects.toThrow(
      "can't play GK",
    );

    h.balances.set(user.walletAddress, 'mint-AAPL', 0);
    await expect(h.rosters.fillSlot(user, 'football', 0, 'mint-AAPL')).rejects.toThrow(
      'You do not hold AAPLx',
    );

    await h.rosters.fillSlot(user, 'football', 1, 'mint-KO');
    await expect(h.rosters.fillSlot(user, 'football', 2, 'mint-KO')).rejects.toThrow(
      'already on this team',
    );
  });

  it('drafts a complete team in every sport', async () => {
    for (const mode of ['football', 'basketball', 'american_football'] as const) {
      await h.draft(user, mode);
      expect(await h.rosters.isComplete(user.id, mode)).toBe(true);
    }
  });

  it('keeps picks in role order when the formation changes, and reports drops', async () => {
    const picked = await h.draft(user, 'football');
    const result = await h.rosters.setFormation(user, 'football', '3-5-2');

    // 4-4-2 → 3-5-2: one defender too many, one midfield slot left empty.
    expect(result.dropped.map((s) => s.mint)).toEqual([picked[4]]);
    expect(result.roster.formation).toBe('3-5-2');
    const filled = result.roster.slots.filter((s) => s.stock !== null);
    expect(filled).toHaveLength(10);
    expect(result.roster.slots[8].stock).toBeNull(); // the new midfield slot
    expect(await h.rosters.isComplete(user.id, 'football')).toBe(false);
  });

  it('moves the armband with its stock and clears it when dropped', async () => {
    await h.draft(user, 'football');
    await h.rosters.setCaptaincy(user, 'football', { captainSlot: 5, viceCaptainSlot: 9 });

    // Slot 5 is the first midfielder; in 3-5-2 it becomes slot 4.
    const moved = await h.rosters.setFormation(user, 'football', '3-5-2');
    expect(moved.roster.captainSlot).toBe(4);

    // Back to 4-4-2 drops the fifth midfielder; captain still exists.
    await h.rosters.setCaptaincy(user, 'football', { captainSlot: 3 });
    const back = await h.rosters.setFormation(user, 'football', '5-3-2');
    expect(back.roster.captainSlot).toBe(3);
  });

  it('only lets a filled slot wear the armband, and only in the right sports', async () => {
    await expect(
      h.rosters.setCaptaincy(user, 'football', { captainSlot: 0 }),
    ).rejects.toThrow('Pick a stock for that slot');

    await h.draft(user, 'basketball');
    const roster = await h.rosters.setCaptaincy(user, 'basketball', { captainSlot: 0 });
    expect(roster.captainSlot).toBe(0);
    expect(roster.viceCaptainSlot).toBeNull();

    await h.draft(user, 'american_football');
    await expect(
      h.rosters.setCaptaincy(user, 'american_football', { captainSlot: 0 }),
    ).rejects.toThrow("don't have a captain");
  });

  it('rejects formations outside the rules and for other sports', async () => {
    await expect(h.rosters.setFormation(user, 'football', '2-5-3')).rejects.toThrow(
      'not a valid formation',
    );
    await expect(h.rosters.setFormation(user, 'basketball', '4-4-2')).rejects.toThrow(
      'Only football',
    );
  });
});
