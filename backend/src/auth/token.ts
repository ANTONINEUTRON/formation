import { createHmac, timingSafeEqual } from 'node:crypto';

export interface TokenPayload {
  /** User id. */
  sub: string;
  wallet: string;
  /** Expiry, epoch milliseconds. */
  exp: number;
}

/** Compact HMAC-signed bearer token: base64url(payload).base64url(sig). */
export function signToken(payload: TokenPayload, secret: string): string {
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  return `${body}.${hmac(body, secret)}`;
}

export function verifyToken(
  token: string,
  secret: string,
  now = Date.now(),
): TokenPayload | null {
  const [body, sig] = token.split('.');
  if (!body || !sig) return null;
  const expected = Buffer.from(hmac(body, secret));
  const actual = Buffer.from(sig);
  if (expected.length !== actual.length || !timingSafeEqual(expected, actual)) {
    return null;
  }
  try {
    const payload = JSON.parse(
      Buffer.from(body, 'base64url').toString(),
    ) as TokenPayload;
    return payload.exp > now ? payload : null;
  } catch {
    return null;
  }
}

function hmac(body: string, secret: string): string {
  return createHmac('sha256', secret).update(body).digest('base64url');
}
