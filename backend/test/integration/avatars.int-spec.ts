import { AssistantService } from '../../src/assistant/assistant.service.js';
import { AvatarService } from '../../src/assistant/avatars.js';
import type { UploadedPhoto } from '../../src/assistant/avatars.js';
import type { AuthUser } from '../../src/domain/dto.js';
import { createHarness } from './harness.js';
import type { Harness } from './harness.js';

const photo = (over: Partial<UploadedPhoto> = {}): UploadedPhoto => ({
  buffer: Buffer.from([0x89, 0x50, 0x4e, 0x47, 1, 2, 3]),
  mimetype: 'image/png',
  size: 7,
  ...over,
});

describe('custom avatars', () => {
  let h: Harness;
  let avatars: AvatarService;
  let assistant: AssistantService;
  let manager: AuthUser;

  beforeAll(async () => {
    h = await createHarness();
    avatars = h.app.get(AvatarService);
    assistant = h.app.get(AssistantService);
  });

  afterAll(async () => {
    await h.close();
  });

  beforeEach(async () => {
    await h.reset();
    manager = await h.createPlayer('selfie');
  });

  it('draws four poses from the photo, free the first time, and makes it the active character', async () => {
    expect((await assistant.profile(manager)).avatarCost).toBe(0);

    const result = await avatars.create(manager, photo(), { personality: 'maverick', name: 'Coach Toly', consent: 'true' });
    expect(result.credits).toBe(11); // free

    // One drawing from the photo, then three poses drawn from that character.
    expect(h.llm.imagePrompts).toHaveLength(4);
    expect(h.llm.imagePrompts[0]).toContain('resembles them');
    expect(h.llm.imagePrompts.slice(1).every((p) => p.startsWith('Keep this exact character'))).toBe(true);

    const profile = await assistant.profile(manager);
    expect(profile.characterId).toBe('custom');
    expect(profile.characters.at(-1)).toMatchObject({ id: 'custom', name: 'Coach Toly', style: 'bold' });
    expect(profile.avatarVersion).not.toBeNull();
    expect(profile.avatarCost).toBe(20);

    const celebrating = await avatars.image(manager, 'celebrating');
    expect(celebrating.mime).toBe('image/png');
    await expect(avatars.image(manager, 'dancing')).rejects.toThrow(/No such pose/);

    // The custom character speaks with the borrowed personality.
    h.llm.reply = { text: 'Go bold.', mood: 'happy', suggestions: [] };
    await assistant.chat(manager, { context: { mode: 'football' }, messages: [{ role: 'manager', text: 'hi' }] });
    expect(h.llm.requests[0].system).toContain('You are Coach Toly');
  });

  it('charges for a second avatar, and refunds when drawing fails', async () => {
    await avatars.create(manager, photo(), { personality: 'mentor', consent: 'true' });
    await h.db.updateTable('assistant_credits').set({ balance: 25 }).execute();

    h.llm.failImage = true;
    await expect(avatars.create(manager, photo(), { personality: 'mentor', consent: 'true' })).rejects.toThrow(
      /not charged/,
    );
    expect((await assistant.profile(manager)).credits).toBe(25);

    h.llm.failImage = false;
    expect((await avatars.create(manager, photo(), { personality: 'scout', consent: 'true' })).credits).toBe(5);
    await expect(avatars.create(manager, photo(), { personality: 'scout', consent: 'true' })).rejects.toMatchObject({
      status: 402,
    });
  });

  it('refuses without consent, a personality, or a usable photo', async () => {
    await expect(avatars.create(manager, photo(), { personality: 'mentor' })).rejects.toThrow(/permission/);
    await expect(avatars.create(manager, photo(), { consent: 'true' })).rejects.toThrow(/personality/);
    await expect(
      avatars.create(manager, photo({ mimetype: 'image/gif' }), { personality: 'mentor', consent: 'true' }),
    ).rejects.toThrow(/JPEG, PNG or WebP/);
    await expect(avatars.create(manager, undefined, { personality: 'mentor', consent: 'true' })).rejects.toThrow(
      /Add a photo/,
    );
    // Picking "custom" before one exists is refused too.
    await expect(assistant.setCharacter(manager, 'custom')).rejects.toThrow(/Unknown/);
  });
});
