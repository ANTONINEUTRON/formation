import { createVerify, generateKeyPairSync } from 'node:crypto';
import { FcmPushSender, parseServiceAccount } from './fcm.js';

const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const account = {
  project_id: 'formation-test',
  client_email: 'push@formation-test.iam.gserviceaccount.com',
  private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }).toString(),
};

/** A fetch that answers the OAuth exchange, then FCM with [fcm]. */
function fakeFetch(fcm: { status: number; body: string }) {
  const calls: { url: string; init: RequestInit }[] = [];
  const impl = (async (url: string, init: RequestInit) => {
    calls.push({ url, init });
    if (url.includes('oauth2')) {
      return new Response(JSON.stringify({ access_token: 'access-1', expires_in: 3600 }), { status: 200 });
    }
    return new Response(fcm.body, { status: fcm.status });
  }) as unknown as typeof fetch;
  return { impl, calls };
}

describe('parseServiceAccount', () => {
  it('reads raw or base64 JSON, and rejects anything incomplete', () => {
    const json = JSON.stringify(account);
    expect(parseServiceAccount(json)?.project_id).toBe('formation-test');
    expect(parseServiceAccount(Buffer.from(json).toString('base64'))?.client_email).toBe(account.client_email);
    expect(parseServiceAccount('')).toBeNull();
    expect(parseServiceAccount('{"project_id":"x"}')).toBeNull();
    expect(parseServiceAccount('not json')).toBeNull();
  });
});

describe('FcmPushSender', () => {
  it('is off without a service account', async () => {
    const sender = new FcmPushSender(null);
    expect(sender.enabled).toBe(false);
    expect(await sender.send('t', { title: 'a', body: 'b' })).toBe('failed');
  });

  it('signs an RS256 assertion, then sends with the access token', async () => {
    const { impl, calls } = fakeFetch({ status: 200, body: '{}' });
    const sender = new FcmPushSender(account, impl, () => 1_000_000);
    expect(await sender.send('device-1', { title: 'Goal!', body: 'TSLAx', data: { kind: 'goal' } })).toBe('sent');

    const assertion = new URLSearchParams(calls[0].init.body as string).get('assertion')!;
    const [header, claims, signature] = assertion.split('.');
    const valid = createVerify('RSA-SHA256').update(`${header}.${claims}`).verify(publicKey, signature, 'base64url');
    expect(valid).toBe(true);
    expect(JSON.parse(Buffer.from(claims, 'base64url').toString())).toMatchObject({
      iss: account.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
    });

    expect(calls[1].url).toBe('https://fcm.googleapis.com/v1/projects/formation-test/messages:send');
    expect((calls[1].init.headers as Record<string, string>).authorization).toBe('Bearer access-1');
    expect(JSON.parse(calls[1].init.body as string).message).toMatchObject({
      token: 'device-1',
      notification: { title: 'Goal!', body: 'TSLAx' },
      data: { kind: 'goal' },
    });

    // The access token is reused until it nears expiry.
    await sender.send('device-2', { title: 'x', body: 'y' });
    expect(calls.filter((c) => c.url.includes('oauth2'))).toHaveLength(1);
  });

  it('reports a token FCM no longer knows, so it can be forgotten', async () => {
    const gone = fakeFetch({ status: 404, body: '{"error":{"status":"NOT_FOUND","details":[{"errorCode":"UNREGISTERED"}]}}' });
    expect(await new FcmPushSender(account, gone.impl).send('old', { title: 'a', body: 'b' })).toBe('invalid_token');

    const down = fakeFetch({ status: 503, body: 'unavailable' });
    expect(await new FcmPushSender(account, down.impl).send('t', { title: 'a', body: 'b' })).toBe('failed');
  });
});
