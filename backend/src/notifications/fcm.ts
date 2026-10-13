import { createSign } from 'node:crypto';

/** Injection token for the push sender (FCM in production, a fake in tests). */
export const PUSH_SENDER = Symbol('PUSH_SENDER');

export interface PushMessage {
  title: string;
  body: string;
  /** FCM data values must be strings. */
  data?: Record<string, string>;
}

/** invalid_token means FCM no longer knows the device: forget it. */
export type PushResult = 'sent' | 'invalid_token' | 'failed';

export interface PushSender {
  /** False when no service account is configured: nothing is pushed. */
  readonly enabled: boolean;
  send(token: string, message: PushMessage): Promise<PushResult>;
}

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
}

const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const DEFAULT_TOKEN_URI = 'https://oauth2.googleapis.com/token';

/**
 * Reads FCM_SERVICE_ACCOUNT: the Firebase service account key, as raw JSON or
 * base64-encoded JSON (easier to paste into a hosting dashboard). Returns
 * null when it's missing or unusable.
 */
export function parseServiceAccount(value: string | undefined): ServiceAccount | null {
  const raw = value?.trim();
  if (!raw) return null;
  const json = raw.startsWith('{') ? raw : Buffer.from(raw, 'base64').toString('utf8');
  try {
    const parsed = JSON.parse(json) as Partial<ServiceAccount>;
    if (!parsed.project_id || !parsed.client_email || !parsed.private_key) return null;
    return parsed as ServiceAccount;
  } catch {
    return null;
  }
}

const base64url = (input: Buffer | string) => Buffer.from(input).toString('base64url');

/**
 * Sends through FCM's HTTP v1 API. Signs its own OAuth assertion with the
 * service account's key rather than pulling in firebase-admin for two calls;
 * the access token is cached until shortly before it expires.
 */
export class FcmPushSender implements PushSender {
  private accessToken?: { value: string; expiresAt: number };

  constructor(
    private readonly account: ServiceAccount | null,
    private readonly http: typeof fetch = fetch,
    private readonly now: () => number = Date.now,
  ) {}

  get enabled(): boolean {
    return this.account !== null;
  }

  async send(token: string, message: PushMessage): Promise<PushResult> {
    if (!this.account) return 'failed';
    const res = await this.http(
      `https://fcm.googleapis.com/v1/projects/${this.account.project_id}/messages:send`,
      {
        method: 'POST',
        headers: {
          authorization: `Bearer ${await this.token()}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: message.title, body: message.body },
            data: message.data ?? {},
            android: { priority: 'high' },
            apns: { payload: { aps: { sound: 'default' } } },
          },
        }),
      },
    );
    if (res.ok) return 'sent';
    const text = await res.text();
    // A token for an uninstalled app, or one that was never valid.
    if (res.status === 404 || /UNREGISTERED|registration-token-not-registered/.test(text)) {
      return 'invalid_token';
    }
    if (res.status === 400 && /INVALID_ARGUMENT/.test(text) && /token/i.test(text)) {
      return 'invalid_token';
    }
    return 'failed';
  }

  /** A fresh or cached OAuth access token for FCM. */
  private async token(): Promise<string> {
    const account = this.account!;
    const now = this.now();
    if (this.accessToken && this.accessToken.expiresAt - 60_000 > now) {
      return this.accessToken.value;
    }
    const iat = Math.floor(now / 1000);
    const tokenUri = account.token_uri ?? DEFAULT_TOKEN_URI;
    const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
    const claims = base64url(
      JSON.stringify({ iss: account.client_email, scope: SCOPE, aud: tokenUri, iat, exp: iat + 3600 }),
    );
    const signature = createSign('RSA-SHA256')
      .update(`${header}.${claims}`)
      .sign(account.private_key)
      .toString('base64url');

    const res = await this.http(tokenUri, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: `${header}.${claims}.${signature}`,
      }).toString(),
    });
    if (!res.ok) throw new Error(`FCM auth failed: ${res.status} ${await res.text()}`);
    const body = (await res.json()) as { access_token: string; expires_in: number };
    this.accessToken = { value: body.access_token, expiresAt: now + body.expires_in * 1000 };
    return body.access_token;
  }
}
