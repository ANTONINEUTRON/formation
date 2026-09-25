import { loadConfig } from './config.js';

describe('Jupiter credentials', () => {
  it('stays on the keyless host and sends no key when none is set', () => {
    const config = loadConfig({});
    expect(config.jupiterApiUrl).toBe('https://lite-api.jup.ag');
    expect(config.jupiterHeaders).toEqual({});
  });

  it('moves to the keyed host as soon as a key is set', () => {
    // The two have to move together: a key is only honoured on api.jup.ag, and
    // lite-api.jup.ag silently ignores it and keeps the keyless rate limit.
    const config = loadConfig({ JUPITER_API_KEY: 'jup-key' });
    expect(config.jupiterApiUrl).toBe('https://api.jup.ag');
    expect(config.jupiterHeaders).toEqual({ 'x-api-key': 'jup-key' });
  });

  it('treats a blank or whitespace key as no key at all', () => {
    // An empty JUPITER_API_KEY= line is the normal state of a fresh .env, and
    // must not send an empty x-api-key header — Jupiter rejects that outright,
    // which would break prices and swaps rather than merely rate-limit them.
    for (const key of ['', '   ']) {
      const config = loadConfig({ JUPITER_API_KEY: key });
      expect(config.jupiterHeaders).toEqual({});
      expect(config.jupiterApiUrl).toBe('https://lite-api.jup.ag');
    }
  });

  it('lets an explicit host win, for self-hosted or staging endpoints', () => {
    const config = loadConfig({
      JUPITER_API_KEY: 'jup-key',
      JUPITER_API_URL: 'https://jupiter.internal',
    });
    expect(config.jupiterApiUrl).toBe('https://jupiter.internal');
    expect(config.jupiterHeaders).toEqual({ 'x-api-key': 'jup-key' });
  });
});
