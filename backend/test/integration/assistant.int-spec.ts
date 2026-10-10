import { AssistantService } from '../../src/assistant/assistant.service.js';
import type { AuthUser } from '../../src/domain/dto.js';
import { createHarness } from './harness.js';
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
      { kind: 'setCaptain', slotIndex: 4, vice: false, reason: 'steadiest pick' },
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
