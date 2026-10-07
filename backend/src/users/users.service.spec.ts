import { BadRequestException } from '@nestjs/common';
import { defaultUsername, normaliseUsername } from './users.service.js';

/**
 * The default name a player is given has to satisfy the rule that the same
 * service enforces on save.
 *
 * It did not: a new player got `shortAddress(wallet)` — "ANcA…QAtU" — and the
 * ellipsis is not in [A-Za-z0-9_]. Since the app pre-fills the name field with
 * the player's current name, every save sent that invalid default back and the
 * request was rejected, so nobody could set a bio without renaming themselves.
 * The two functions have to agree, and these say so.
 */
describe('usernames', () => {
  const wallets = [
    'ANcA5rbPmoLs8fWtGnyVxNCGk4mRT3q9hT4pBdQAtU',
    '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU',
    'So11111111111111111111111111111111111111112',
  ];

  for (const wallet of wallets) {
    it(`gives ${wallet.slice(0, 6)}… a name the API will accept back`, () => {
      const username = defaultUsername(wallet);
      // The real assertion: a round trip through the save path must not throw.
      expect(normaliseUsername(username)).toBe(username);
    });
  }

  it('keeps the wallet recognisable in the default name', () => {
    expect(defaultUsername('ANcA5rbPmoLs8fWtGnyVxNCGk4mRT3q9hT4pBdQAtU')).toBe('ANcA_QAtU');
  });

  it('still produces a usable name for a wallet the rule would reject', () => {
    // Nothing should be able to make first sign-in fail, however odd the input.
    expect(normaliseUsername(defaultUsername('ab'))).toBeTruthy();
  });

  it('rejects a name with characters outside the set', () => {
    expect(() => normaliseUsername('ANcA…QAtU')).toThrow(BadRequestException);
    expect(() => normaliseUsername('has space')).toThrow(BadRequestException);
  });

  it('rejects a name that is too short or too long', () => {
    expect(() => normaliseUsername('ab')).toThrow(BadRequestException);
    expect(() => normaliseUsername('a'.repeat(21))).toThrow(BadRequestException);
  });

  it('trims before validating, so a pasted name with spaces is accepted', () => {
    expect(normaliseUsername('  marcus  ')).toBe('marcus');
  });
});
