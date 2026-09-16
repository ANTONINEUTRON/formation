import { signToken, verifyToken } from './token.js';

describe('token', () => {
  const payload = { sub: 'user-1', wallet: 'Wallet111', exp: 2_000 };

  it('round-trips a valid token', () => {
    expect(verifyToken(signToken(payload, 's3cret'), 's3cret', 1_000)).toEqual(
      payload,
    );
  });

  it('rejects a token signed with another secret', () => {
    expect(verifyToken(signToken(payload, 'other'), 's3cret', 1_000)).toBeNull();
  });

  it('rejects an expired token', () => {
    expect(verifyToken(signToken(payload, 's3cret'), 's3cret', 3_000)).toBeNull();
  });

  it('rejects a tampered payload', () => {
    const [, sig] = signToken(payload, 's3cret').split('.');
    const forged = Buffer.from(
      JSON.stringify({ ...payload, sub: 'user-2' }),
    ).toString('base64url');
    expect(verifyToken(`${forged}.${sig}`, 's3cret', 1_000)).toBeNull();
  });
});
