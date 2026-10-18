import { AssistantService } from '../../src/assistant/assistant.service.js';
import { StarterService } from '../../src/assistant/starter.js';
import type { AuthUser } from '../../src/domain/dto.js';
import { rosterShape } from '../../src/domain/sport.js';
import { BENCHMARK_MINT, TEST_STOCKS, createHarness } from './harness.js';
import type { Harness } from './harness.js';

describe('free starter squad', () => {
  let h: Harness;
  let starter: StarterService;
  let assistant: AssistantService;
  let manager: AuthUser;

  beforeAll(async () => {
    h = await createHarness();
    starter = h.app.get(StarterService);
    assistant = h.app.get(AssistantService);
  });

  afterAll(async () => {
    await h.close();
  });

  beforeEach(async () => {
    await h.reset();
    manager = await h.createPlayer('rookie');
    // A brand-new Manager holds nothing.
    h.balances.setAll(manager.walletAddress, TEST_STOCKS.map((s) => s.mint), 0);
    await assistant.setCharacter(manager, 'veteran');
  });

  it('drafts a complete, tier-valid squad even when the model leaves gaps', async () => {
    h.llm.reply = {
      text: 'A sturdy start.',
      captainSlot: 4,
      picks: [
        { slotIndex: 0, symbol: 'NVDAx', reason: 'momentum at PG' },
        { slotIndex: 4, symbol: 'AAPLx', reason: 'blue chip at C' },
        { slotIndex: 2, symbol: 'TSLAx', reason: 'momentum is the wrong tier for SF' },
      ],
    };
    expect((await assistant.profile(manager)).starterDraftsLeft).toBe(2);

    const squad = await starter.draft(manager, { mode: 'basketball', budgetUsd: 25 });

    const shape = rosterShape('basketball');
    expect(squad.picks).toHaveLength(shape.length);
    for (const pick of squad.picks) {
      const tier = shape[pick.slotIndex].tier;
      expect(tier === null || pick.tier === tier).toBe(true);
      expect(pick.needsPurchase).toBe(true);
      expect(pick.amountUsd).toBe(5);
    }
    expect(new Set(squad.picks.map((p) => p.mint)).size).toBe(shape.length);
    expect(squad.picks.find((p) => p.slotIndex === 0)?.symbol).toBe('NVDAx');
    expect(squad.picks.find((p) => p.slotIndex === 2)?.symbol).not.toBe('TSLAx');
    expect(squad.picks.some((p) => p.mint === BENCHMARK_MINT)).toBe(false);
    expect(squad.captainSlot).toBe(4);
    expect(squad.viceCaptainSlot).toBeNull(); // basketball has no vice
    expect(squad.draftsLeft).toBe(1);
  });

  it('skips buying what the Manager already holds', async () => {
    h.balances.set(manager.walletAddress, 'mint-AAPL', 3);
    h.llm.reply = { text: 'ok', picks: [{ slotIndex: 4, symbol: 'AAPLx', reason: 'you own it' }] };
    const squad = await starter.draft(manager, { mode: 'basketball', budgetUsd: 20 });
    const aapl = squad.picks.find((p) => p.symbol === 'AAPLx')!;
    expect(aapl).toMatchObject({ needsPurchase: false, amountUsd: 0 });
    expect(squad.picks.filter((p) => p.needsPurchase).every((p) => p.amountUsd === 5)).toBe(true);
  });

  it('allows a draft and one regenerate, and hands a failed draft back', async () => {
    h.llm.reply = { text: 'ok', picks: [] };
    h.llm.fail = true;
    await expect(starter.draft(manager, { mode: 'basketball', budgetUsd: 10 })).rejects.toThrow(/still yours/);
    h.llm.fail = false;

    await starter.draft(manager, { mode: 'basketball', budgetUsd: 10 });
    await starter.draft(manager, { mode: 'basketball', budgetUsd: 10 });
    await expect(starter.draft(manager, { mode: 'basketball', budgetUsd: 10 })).rejects.toThrow(/already been used/);
    expect((await assistant.profile(manager)).starterDraftsLeft).toBe(0);
  });

  it('needs at least the minimum buy per player, and can be declined', async () => {
    await expect(starter.draft(manager, { mode: 'football', budgetUsd: 5 })).rejects.toThrow(/at least \$11/);
    await starter.dismiss(manager);
    expect((await assistant.profile(manager)).starterDraftsLeft).toBe(0);
  });
});
