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
    expect(squad.draftsLeft).toBe(2);
  });

  it('buys a stock held only as dust, rather than counting it as held', async () => {
    h.balances.set(manager.walletAddress, 'mint-AAPL', 0.005); // $0.50 at $100
    h.llm.reply = { text: 'ok', picks: [{ slotIndex: 4, symbol: 'AAPLx', reason: 'blue chip at C' }] };
    const squad = await starter.draft(manager, { mode: 'basketball', budgetUsd: 10 });
    expect(squad.picks.find((p) => p.symbol === 'AAPLx')).toMatchObject({ needsPurchase: true });
  });

  it('skips buying what the Manager already holds', async () => {
    h.balances.set(manager.walletAddress, 'mint-AAPL', 3);
    h.llm.reply = { text: 'ok', picks: [{ slotIndex: 4, symbol: 'AAPLx', reason: 'you own it' }] };
    const squad = await starter.draft(manager, { mode: 'basketball', budgetUsd: 20 });
    const aapl = squad.picks.find((p) => p.symbol === 'AAPLx')!;
    expect(aapl).toMatchObject({ needsPurchase: false, amountUsd: 0 });
    expect(squad.picks.filter((p) => p.needsPurchase).every((p) => p.amountUsd === 5)).toBe(true);
  });

  it('pays every draft from the one credit balance, refunding a failed one, and records each move', async () => {
    h.llm.reply = { text: 'ok', picks: [] };
    const welcome = (await assistant.profile(manager)).credits;
    expect(welcome).toBe(11); // two drafts and five replies

    h.llm.fail = true;
    await expect(starter.draft(manager, { mode: 'basketball', budgetUsd: 10 })).rejects.toThrow(/refunded/);
    expect((await assistant.profile(manager)).credits).toBe(welcome);
    h.llm.fail = false;

    const first = await starter.draft(manager, { mode: 'basketball', budgetUsd: 10 });
    expect(first).toMatchObject({ credits: welcome - 3, draftsLeft: 2 });
    await starter.draft(manager, { mode: 'basketball', budgetUsd: 10 });
    await starter.draft(manager, { mode: 'basketball', budgetUsd: 10 });
    expect((await assistant.profile(manager)).credits).toBe(2);

    // Two credits left: not enough for another.
    await expect(starter.draft(manager, { mode: 'basketball', budgetUsd: 10 })).rejects.toThrow(/costs 3 credits/);

    const ledger = await h.db
      .selectFrom('credit_ledger')
      .select(['delta', 'balance_after', 'reason', 'ref'])
      .where('user_id', '=', manager.id)
      .orderBy('id')
      .execute();
    expect(ledger.map((e) => [e.reason, e.delta])).toEqual([
      ['welcome', 11],
      ['squad_draft', -3],
      ['refund', 3],
      ['squad_draft', -3],
      ['squad_draft', -3],
      ['squad_draft', -3],
    ]);
    expect(ledger.reduce((sum, e) => sum + e.delta, 0)).toBe(ledger.at(-1)!.balance_after);
  });

  it('never gives the welcome credits twice to the same wallet', async () => {
    await assistant.profile(manager);
    await starter.draft(manager, { mode: 'basketball', budgetUsd: 10 });
    // Signing in again with the same wallet finds the same account.
    const again = await h.createPlayer('rookie');
    expect(again.id).toBe(manager.id);
    expect((await assistant.profile(again)).credits).toBe(8);
    const welcomes = await h.db
      .selectFrom('credit_ledger')
      .select('id')
      .where('user_id', '=', manager.id)
      .where('reason', '=', 'welcome')
      .execute();
    expect(welcomes).toHaveLength(1);
  });

  it('needs at least the minimum buy per player, and declining costs nothing', async () => {
    await expect(starter.draft(manager, { mode: 'football', budgetUsd: 5 })).rejects.toThrow(/at least \$11/);
    await starter.dismiss(manager);
    expect((await assistant.profile(manager)).credits).toBe(11);
  });
});
