/**
 * Sign In With Solana: checking a message the wallet built and signed.
 *
 * The web app signs in with the wallet's `solana:signIn` feature rather than
 * our own challenge, for one reason: on Android Chrome every hop to the wallet
 * app has to come straight from a tap. The challenge flow needs two hops —
 * connect, then sign — and Chrome blocks the second, so Mobile Wallet Adapter
 * sign-in failed every time. `signIn` connects and signs in a single hop.
 *
 * The cost is that the wallet writes the message, not us, so there is no
 * server-issued challenge to compare it against. What stands in for one:
 *
 *   - the signature, over the exact bytes the wallet signed;
 *   - the address in the message, which must be the wallet claiming it;
 *   - the domain, which the wallet fills in from the page it is on, so a
 *     message signed on someone else's site is refused;
 *   - Issued At, within a few minutes of now, so an old message is refused;
 *   - the nonce, accepted once, so a captured message cannot be replayed.
 *
 * The nonce is chosen by the app rather than issued by us, deliberately: a
 * round trip to fetch one between the tap and the wallet hop is exactly the
 * delay that can cost the tap its permission to open the wallet.
 */

/** The fields of a SIWS message this server relies on. */
export interface SiwsMessage {
  domain: string;
  address: string;
  nonce?: string;
  issuedAt?: string;
}

const HEADER = /^(\S+) wants you to sign in with your Solana account:$/;

/** How old a message may be, and how far ahead of our clock. */
export const SIWS_MAX_AGE_MS = 5 * 60_000;
export const SIWS_MAX_SKEW_MS = 60_000;

/** Nonces are the app's, so hold them to something unguessable-looking. */
const NONCE = /^[A-Za-z0-9]{8,64}$/;

/**
 * Parses the parts of a SIWS message we check, or returns null if it is not
 * one.
 *
 * Fields are read from the end: the statement comes before them and is free
 * text, so a statement line that happens to read "Nonce: x" must not be taken
 * for the real field below it.
 */
export function parseSiwsMessage(text: string): SiwsMessage | null {
  const lines = text.split('\n');
  const header = HEADER.exec(lines[0] ?? '');
  const address = (lines[1] ?? '').trim();
  if (!header || !address) return null;

  const field = (name: string): string | undefined => {
    for (let i = lines.length - 1; i >= 2; i--) {
      const prefix = `${name}: `;
      if (lines[i].startsWith(prefix)) return lines[i].slice(prefix.length).trim();
    }
    return undefined;
  };

  return { domain: header[1], address, nonce: field('Nonce'), issuedAt: field('Issued At') };
}

/**
 * Hosts a SIWS message may name as its domain.
 *
 * The web app's own origins, from the same CORS_ORIGINS list that decides
 * which pages may call the API at all, plus localhost on any port for
 * development.
 */
export function allowedSiwsHost(domain: string, webOrigins: readonly string[]): boolean {
  const host = domain.toLowerCase();
  const hostname = host.replace(/:\d+$/, '');
  if (hostname === 'localhost' || hostname === '127.0.0.1') return true;

  return webOrigins.some((origin) => {
    try {
      return new URL(origin).host.toLowerCase() === host;
    } catch {
      return false;
    }
  });
}

/**
 * Why a parsed message cannot be accepted, or null if it can.
 *
 * The signature and nonce reuse are checked by the caller; this covers what
 * can be judged from the message alone.
 */
export function siwsProblem(
  message: SiwsMessage,
  walletAddress: string,
  webOrigins: readonly string[],
  now = Date.now(),
): string | null {
  if (message.address !== walletAddress) return 'Signed for a different wallet';
  if (!allowedSiwsHost(message.domain, webOrigins)) return 'Signed for a different site';
  if (!message.nonce || !NONCE.test(message.nonce)) return 'Sign-in message has no usable nonce';

  const issued = message.issuedAt ? Date.parse(message.issuedAt) : NaN;
  if (Number.isNaN(issued)) return 'Sign-in message has no issue time';
  if (issued > now + SIWS_MAX_SKEW_MS) return 'Sign-in message is from the future';
  if (issued < now - SIWS_MAX_AGE_MS) return 'Sign-in expired, try again';
  return null;
}
