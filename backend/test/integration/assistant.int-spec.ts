import { AssistantService } from '../../src/assistant/assistant.service.js';
import type { AuthUser } from '../../src/domain/dto.js';
import { BENCHMARK_MINT, createHarness } from './harness.js';
import type { Harness } from './harness.js';

const ask = (text: string, mode = 'basketball') => ({
  context: { mode, screen: 'team' },
  messages: [{ role: 'manager', text }],
});

describe('assistant', () => {
  let h: Harness;
  let assistant: AssistantService;
  let manager: AuthUser;

  beforeAll(async () => {
    h = await createHarness();
    assistant = h.app.get(AssistantService);
  });

  afterAll(async () => {
    await h.close();
  });

  beforeEach(async () => {
    await h.reset();
    manager = await h.createPlayer('marcus');
  });

  it('asks the Manager to pick a character first, and grants trial credits once', async () => {
    const first = await assistant.profile(manager);
    expect(first.characterId).toBeNull();
    expect(first.characters.map((c) => c.id)).toEqual([
      'veteran',
      'analyst',
      'maverick',
      'mentor',
      'scout',
    ]);
    expect(first.credits).toBe(5);

    await expect(assistant.chat(manager, ask('hi'))).rejects.toThrow(/Pick your Assistant Manager/);
    const picked = await assistant.setCharacter(manager, 'mentor');
    expect(picked.characterId).toBe('mentor');
    // Reading the profile again never tops the trial back up.
    expect((await assistant.profile(manager)).credits).toBe(5);
    await expect(assistant.setCharacter(manager, 'pundit')).rejects.toThrow(/Unknown/);
  });

  it('answers from the live lineup, charges one credit, and keeps only legal moves', async () => {
    await assistant.setCharacter(manager, 'analyst');
    await h.draft(manager, 'basketball');
    h.llm.reply = {
      text: 'Make AAPLx your captain; it held up best.',
      mood: 'happy',
      suggestions: [
        { kind: 'setCaptain', slotIndex: 4, reason: 'steadiest pick' },
        { kind: 'fillSlot', slotIndex: 2, symbol: 'TSLAx', reason: 'momentum in a balanced slot' },
      ],
    };

    const reply = await assistant.chat(manager, ask('Who should I captain?'));

    expect(reply.text).toContain('captain');
    expect(reply.mood).toBe('happy');
    // TSLAx is momentum and slot 2 (SF) needs balanced, so only the captaincy survives.
    expect(reply.suggestions).toEqual([
      {
        kind: 'setCaptain',
        slotIndex: 4,
        symbol: expect.any(String),
        position: 'C',
        vice: false,
        reason: 'steadiest pick',
      },
    ]);
    expect(reply.credits).toBe(4);

    const request = h.llm.requests[0];
    expect(request.messages).toEqual([{ role: 'user', text: 'Who should I captain?' }]);
    expect(request.system).toContain('The Analyst');
    expect(request.system).toContain('"sport":"basketball"');
    expect(request.system).toContain('AAPLx');
  });

  it('refunds the credit when the model fails, and refuses at zero credits', async () => {
    await assistant.setCharacter(manager, 'veteran');
    h.llm.fail = true;
    await expect(assistant.chat(manager, ask('hello'))).rejects.toThrow(/not charged/);
    expect((await assistant.profile(manager)).credits).toBe(5);

    h.llm.fail = false;
    for (let i = 0; i < 5; i++) await assistant.chat(manager, ask(`question ${i}`));
    await expect(assistant.chat(manager, ask('one more'))).rejects.toMatchObject({ status: 402 });

    const usage = await h.db.selectFrom('assistant_usage').select(['credits', 'succeeded']).execute();
    expect(usage).toHaveLength(6);
    expect(usage.filter((u) => !u.succeeded)).toEqual([{ credits: 0, succeeded: false }]);
  });

  it('is unavailable without a model, before any credit is taken', async () => {
    await assistant.setCharacter(manager, 'scout');
    h.llm.available = false;
    await expect(assistant.chat(manager, ask('hi'))).rejects.toMatchObject({ status: 503 });
    expect((await assistant.profile(manager)).credits).toBe(5);
  });

  it('fills the cards it asks for from real prices, with news for one extra credit', async () => {
    await assistant.setCharacter(manager, 'analyst');
    await h.draft(manager, 'basketball');
    // A week of hourly ticks: AAPLx climbs 10%, the benchmark 4%.
    const now = h.clock.now();
    const ticks = [];
    for (let hour = 7 * 24; hour >= 0; hour--) {
      const progress = 1 - hour / (7 * 24);
      const at = new Date(now - hour * 3_600_000);
      ticks.push({ mint: 'mint-AAPL', price_usd: 100 * (1 + 0.1 * progress), captured_at: at });
      ticks.push({ mint: BENCHMARK_MINT, price_usd: 100 * (1 + 0.04 * progress), captured_at: at });
    }
    await h.db.insertInto('price_ticks').values(ticks).execute();

    h.llm.reply = {
      text: 'Here is how Apple is doing.',
      mood: 'neutral',
      suggestions: [],
      cards: [
        { type: 'statBoard', symbols: ['aaplx'] },
        { type: 'squadBubbles' },
        { type: 'compare', symbols: ['AAPLx'] }, // needs two stocks: dropped
      ],
    };
    const reply = await assistant.chat(manager, ask('What is AAPLx all about?'));

    expect(reply.cards.map((c) => c.type)).toEqual(['statBoard', 'squadBubbles']);
    const board = reply.cards[0];
    if (board.type !== 'statBoard') throw new Error('expected a stat board');
    expect(board.symbol).toBe('AAPLx');
    expect(board.position).toBe('C'); // drafted into the blue-chip slot
    expect(board.sharesHeld).toBe(10);
    expect(board.return7dPct).toBeCloseTo(10, 0);
    expect(board.benchmark7dPct).toBeCloseTo(4, 0);
    expect(board.alpha7dPct).toBeCloseTo(6, 0);
    expect(board.chart['7D'].map((s) => s.symbol)).toEqual(['AAPLx', 'S&P 500']);
    expect(board.news?.sources[0].url).toBe('https://news.example.com/story');
    expect(h.llm.searches[0]).toContain('Apple (AAPL)');
    // One credit for the reply, one for the news.
    expect(reply.credits).toBe(3);
  });

  it('skips the news rather than going below zero, and refunds a failed search', async () => {
    await assistant.setCharacter(manager, 'scout');
    h.llm.reply = { text: 'Apple.', mood: 'neutral', suggestions: [], cards: [{ type: 'statBoard', symbols: ['AAPLx'] }] };

    h.llm.failSearch = true;
    const failed = await assistant.chat(manager, ask('AAPLx?'));
    expect(failed.cards[0]).not.toHaveProperty('news');
    expect(failed.credits).toBe(4);

    // With a single credit left, the reply is answered and the news is skipped.
    h.llm.failSearch = false;
    await h.db.updateTable('assistant_credits').set({ balance: 1 }).execute();
    const lastCredit = await assistant.chat(manager, ask('AAPLx again?'));
    expect(lastCredit.credits).toBe(0);
    expect(lastCredit.cards[0]).not.toHaveProperty('news');
    expect(h.llm.searches).toHaveLength(1); // only the failed attempt
  });

  it('rejects a conversation that does not end with the Manager', async () => {
    await assistant.setCharacter(manager, 'maverick');
    await expect(
      assistant.chat(manager, {
        context: { mode: 'football' },
        messages: [{ role: 'assistant', text: 'Hello' }],
      }),
    ).rejects.toThrow(/last message/);
    await expect(assistant.chat(manager, { context: { mode: 'golf' }, messages: [] })).rejects.toThrow();
  });
});
