import request from 'supertest';
import type { AuthUser } from '../../src/domain/dto.js';
import { createHarness } from './harness.js';
import type { Harness } from './harness.js';

/** A shared /managers/<id> link opens for someone with no wallet yet. */
describe('public Manager profile', () => {
  let h: Harness;
  let manager: AuthUser;
  const http = () => request(h.app.getHttpServer());

  beforeAll(async () => {
    h = await createHarness();
  });
  afterAll(async () => {
    await h.close();
  });
  beforeEach(async () => {
    await h.reset();
    manager = await h.createPlayer('sharer');
    await h.draft(manager, 'football');
  });

  it('shows the team to a guest, who can look but not follow', async () => {
    const res = await http().get(`/managers/${manager.id}?mode=football`).expect(200);
    expect(res.body).toMatchObject({ username: 'sharer', isCurrentUser: false, following: false });
    expect(res.body.lineup.length).toBeGreaterThan(0);

    await http().post(`/managers/${manager.id}/follow`).expect(401);
  });

  it('hides suspended accounts and treats a malformed id as unknown', async () => {
    await h.db.updateTable('users').set({ suspended_at: new Date() }).where('id', '=', manager.id).execute();
    await http().get(`/managers/${manager.id}?mode=football`).expect(404);
    await http().get('/managers/not-a-uuid?mode=football').expect(404);
  });
});
