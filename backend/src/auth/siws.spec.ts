import { UnauthorizedException } from '@nestjs/common';
import bs58 from 'bs58';
import nacl from 'tweetnacl';
import type { AppConfig } from '../core/config.js';
import type { UsersService } from '../users/users.service.js';
import { AuthService } from './auth.service.js';
import { allowedSiwsHost, parseSiwsMessage, siwsProblem } from './siws.js';

const ORIGINS = ['https://formation-xstocks.web.app', 'https://formation.titalabs.xyz'];

/** The message layout the SIWS spec fixes, which is what wallets produce. */
function siwsText(fields: {
  domain: string;
  address: string;
  statement?: string;
  nonce?: string;
  issuedAt?: string;
}): string {
  const lines = [`${fields.domain} wants you to sign in with your Solana account:`, fields.address];
  if (fields.statement) lines.push('', fields.statement);
  const tail: string[] = [];
  if (fields.nonce) tail.push(`Nonce: ${fields.nonce}`);
  if (fields.issuedAt) tail.push(`Issued At: ${fields.issuedAt}`);
  if (tail.length) lines.push('', ...tail);
  return lines.join('\n');
}

describe('parseSiwsMessage', () => {
  it('reads domain, address, nonce and issue time', () => {
    const parsed = parseSiwsMessage(
      siwsText({
        domain: 'formation-xstocks.web.app',
        address: 'Addr1',
        statement: 'Sign in to Formation',
        nonce: 'abcdef123456',
        issuedAt: '2026-10-08T12:00:00.000Z',
      }),
    );
    expect(parsed).toEqual({
      domain: 'formation-xstocks.web.app',
      address: 'Addr1',
      nonce: 'abcdef123456',
      issuedAt: '2026-10-08T12:00:00.000Z',
    });
  });

  it('takes the real field, not a look-alike planted in the statement', () => {
    const parsed = parseSiwsMessage(
      siwsText({
        domain: 'formation-xstocks.web.app',
        address: 'Addr1',
        statement: 'Nonce: planted00',
        nonce: 'realnonce123',
        issuedAt: '2026-10-08T12:00:00.000Z',
      }),
    );
    expect(parsed?.nonce).toBe('realnonce123');
  });

  it('rejects anything that is not a SIWS message', () => {
    expect(parseSiwsMessage('Sign in to Formation\nWallet: x\nNonce: y')).toBeNull();
    expect(parseSiwsMessage('')).toBeNull();
  });
});

describe('allowedSiwsHost', () => {
  it('accepts the web app origins and localhost on any port', () => {
    expect(allowedSiwsHost('formation-xstocks.web.app', ORIGINS)).toBe(true);
    expect(allowedSiwsHost('localhost:8080', ORIGINS)).toBe(true);
    expect(allowedSiwsHost('127.0.0.1:5000', ORIGINS)).toBe(true);
  });

  it('refuses any other site, including look-alikes', () => {
    expect(allowedSiwsHost('evil.example', ORIGINS)).toBe(false);
    expect(allowedSiwsHost('formation-xstocks.web.app.evil.example', ORIGINS)).toBe(false);
  });
});

describe('siwsProblem', () => {
  const now = Date.parse('2026-10-08T12:00:00.000Z');
  const ok = {
    domain: 'formation-xstocks.web.app',
    address: 'Addr1',
    nonce: 'abcdef123456',
    issuedAt: '2026-10-08T11:59:00.000Z',
  };

  it('passes a fresh message for this wallet from this site', () => {
    expect(siwsProblem(ok, 'Addr1', ORIGINS, now)).toBeNull();
  });

  it('names what is wrong otherwise', () => {
    expect(siwsProblem(ok, 'Addr2', ORIGINS, now)).toMatch(/different wallet/);
    expect(siwsProblem({ ...ok, domain: 'evil.example' }, 'Addr1', ORIGINS, now)).toMatch(
      /different site/,
    );
    expect(siwsProblem({ ...ok, nonce: undefined }, 'Addr1', ORIGINS, now)).toMatch(/nonce/);
    expect(siwsProblem({ ...ok, nonce: 'short' }, 'Addr1', ORIGINS, now)).toMatch(/nonce/);
    expect(
      siwsProblem({ ...ok, issuedAt: '2026-10-08T11:50:00.000Z' }, 'Addr1', ORIGINS, now),
    ).toMatch(/expired/);
    expect(
      siwsProblem({ ...ok, issuedAt: '2026-10-08T12:10:00.000Z' }, 'Addr1', ORIGINS, now),
    ).toMatch(/future/);
  });
});

describe('AuthService.verifySiws', () => {
  const keys = nacl.sign.keyPair();
  const wallet = bs58.encode(keys.publicKey);

  const service = () =>
    new AuthService(
      { authSecret: 'test-secret', webOrigins: ORIGINS } as AppConfig,
      {
        upsertByWallet: async (address: string) => ({
          id: 'user-1',
          username: 'player',
          wallet_address: address,
        }),
      } as unknown as UsersService,
    );

  /** What the app sends: the wallet's bytes as base64, the signature as base58. */
  const signed = (text: string, signer = keys.secretKey) => {
    const bytes = new TextEncoder().encode(text);
    return {
      message: Buffer.from(bytes).toString('base64'),
      signature: bs58.encode(nacl.sign.detached(bytes, signer)),
    };
  };

  const fresh = (nonce = 'abcdef123456') =>
    siwsText({
      domain: 'formation-xstocks.web.app',
      address: wallet,
      statement: 'Sign in to Formation',
      nonce,
      issuedAt: new Date().toISOString(),
    });

  it('issues a token for a valid, fresh, signed message', async () => {
    const { message, signature } = signed(fresh());
    const result = await service().verifySiws(wallet, message, signature);
    expect(result.token).toBeTruthy();
    expect(result.user.walletAddress).toBe(wallet);
  });

  it('refuses the same message twice, so a captured one cannot be replayed', async () => {
    const auth = service();
    const { message, signature } = signed(fresh('replaynonce1'));
    await auth.verifySiws(wallet, message, signature);
    await expect(auth.verifySiws(wallet, message, signature)).rejects.toThrow(/already used/);
  });

  it('refuses a message altered after signing', async () => {
    const { signature } = signed(fresh('tamper000001'));
    const altered = Buffer.from(fresh('tamper000002')).toString('base64');
    await expect(service().verifySiws(wallet, altered, signature)).rejects.toThrow(
      UnauthorizedException,
    );
  });

  it('refuses a message signed by a different key', async () => {
    const other = nacl.sign.keyPair();
    const { message, signature } = signed(fresh('otherkey0001'), other.secretKey);
    await expect(service().verifySiws(wallet, message, signature)).rejects.toThrow(
      /Invalid wallet signature/,
    );
  });

  it('does not let a forged message burn the real nonce', async () => {
    const auth = service();
    const nonce = 'protectme001';
    const other = nacl.sign.keyPair();
    const forged = signed(fresh(nonce), other.secretKey);
    await expect(auth.verifySiws(wallet, forged.message, forged.signature)).rejects.toThrow();

    // The genuine sign-in with that nonce still works.
    const genuine = signed(fresh(nonce));
    await expect(auth.verifySiws(wallet, genuine.message, genuine.signature)).resolves.toBeTruthy();
  });
});
