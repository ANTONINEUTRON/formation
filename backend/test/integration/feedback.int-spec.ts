import { AdminController } from '../../src/admin/admin.controller.js';
import type { AuthUser } from '../../src/domain/dto.js';
import { FEEDBACK_PER_HOUR, FeedbackService } from '../../src/feedback/feedback.service.js';
import { createHarness } from './harness.js';
import type { Harness } from './harness.js';

const png = (bytes = 64) => ({ buffer: Buffer.alloc(bytes, 7), mimetype: 'image/png', size: bytes });

describe('feedback', () => {
  let h: Harness;
  let feedback: FeedbackService;
  let admin: AdminController;
  let manager: AuthUser;

  beforeAll(async () => {
    h = await createHarness();
    feedback = h.app.get(FeedbackService);
    admin = h.app.get(AdminController);
  });
  afterAll(async () => {
    await h.close();
  });
  beforeEach(async () => {
    await h.reset();
    manager = await h.createPlayer('critic');
  });

  it('keeps a message with its rating, screenshot and the profile email to reply to', async () => {
    await h.db.updateTable('users').set({ email: 'critic@example.com' }).where('id', '=', manager.id).execute();
    const { id } = await feedback.submit(
      manager,
      { kind: 'bug', rating: '4', message: '  The buy button spun forever  ', appVersion: '0.6.0', platform: 'android' },
      png(),
    );
    // Without a screenshot, rating or email it's still welcome.
    await h.db.updateTable('users').set({ email: null }).where('id', '=', manager.id).execute();
    h.clock.advance(1);
    await feedback.submit(manager, { kind: 'idea', message: 'Dark mode please' }, undefined);

    const [idea, bug] = await admin.listFeedback({});
    expect(bug).toMatchObject({
      id,
      kind: 'bug',
      rating: 4,
      message: 'The buy button spun forever',
      replyEmail: 'critic@example.com',
      username: 'critic',
      appVersion: '0.6.0',
      platform: 'android',
      hasScreenshot: true,
      status: 'new',
    });
    expect(bug).not.toHaveProperty('screenshot');
    expect(idea).toMatchObject({ kind: 'idea', rating: null, replyEmail: null, hasScreenshot: false });

    const image = await feedback.screenshot(id);
    expect(image.mime).toBe('image/png');
    expect(image.data.length).toBe(64);
    await expect(feedback.screenshot(idea.id)).rejects.toThrow('No screenshot');
  });

  it('rejects what it cannot use', async () => {
    const ok = { kind: 'bug', message: 'Something broke' };
    await expect(feedback.submit(manager, { ...ok, kind: 'rant' }, undefined)).rejects.toThrow('bug, idea or other');
    await expect(feedback.submit(manager, { ...ok, rating: '6' }, undefined)).rejects.toThrow('1 to 5');
    await expect(feedback.submit(manager, { ...ok, rating: '2.5' }, undefined)).rejects.toThrow('1 to 5');
    await expect(feedback.submit(manager, { ...ok, message: 'no' }, undefined)).rejects.toThrow('a little more');
    await expect(feedback.submit(manager, { ...ok, message: 'x'.repeat(2001) }, undefined)).rejects.toThrow('2000');
    await expect(
      feedback.submit(manager, ok, { buffer: Buffer.alloc(8), mimetype: 'application/pdf', size: 8 }),
    ).rejects.toThrow('JPEG, PNG or WebP');
  });

  it(`takes ${FEEDBACK_PER_HOUR} an hour from one Manager`, async () => {
    for (let i = 0; i < FEEDBACK_PER_HOUR; i++) {
      await feedback.submit(manager, { kind: 'other', message: `note ${i}` }, undefined);
    }
    await expect(feedback.submit(manager, { kind: 'other', message: 'one more' }, undefined)).rejects.toMatchObject({
      status: 429,
    });
    // Someone else isn't held up, and an hour later the first can write again.
    const other = await h.createPlayer('fan');
    await feedback.submit(other, { kind: 'idea', message: 'Love it' }, undefined);
    h.clock.advance(61);
    await feedback.submit(manager, { kind: 'other', message: 'back again' }, undefined);
  });

  it('is marked read or done, and filtered by status', async () => {
    const { id } = await feedback.submit(manager, { kind: 'bug', message: 'Chart is blank' }, undefined);
    h.clock.advance(1);
    await feedback.submit(manager, { kind: 'idea', message: 'More sports' }, undefined);
    await admin.setFeedbackStatus(id, { status: 'done' });
    expect((await admin.listFeedback({ status: 'new' })).map((f) => f.message)).toEqual(['More sports']);
    expect((await admin.listFeedback({ status: 'done' })).map((f) => f.id)).toEqual([id]);
    await expect(admin.setFeedbackStatus(id, { status: 'archived' })).rejects.toThrow('new, read or done');
    await expect(admin.setFeedbackStatus('not-a-uuid', { status: 'read' })).rejects.toThrow('Unknown feedback');
  });
});
