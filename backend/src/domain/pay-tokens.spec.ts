import { loadPayTokens, parsePaySymbol, USDC_MINT } from './pay-tokens.js';

describe('pay tokens', () => {
  const SKR = 'SKRbvo6Gf7GondiT3BbTfuRDPqLWei4j2Qy2NPGZhW3';

  it('always offers USDC, and SKR only once its mint is set', () => {
    const without = loadPayTokens({});
    expect(without.map((t) => t.symbol)).toEqual(['USDC']);

    const withSkr = loadPayTokens({ SKR_MINT: SKR, SKR_DECIMALS: '6' });
    expect(withSkr.map((t) => t.symbol)).toEqual(['USDC', 'SKR']);
    expect(withSkr[1]).toMatchObject({ mint: SKR, decimals: 6 });
  });

  it('does not offer SOL as payment', () => {
    // Swaps need SOL for network fees. Letting players spend it on stocks
    // leaves them unable to sign the next transaction, and paying with it
    // needs a wrapped-SOL fee account on top. Even a configured account must
    // not bring it back.
    const tokens = loadPayTokens({
      SKR_MINT: SKR,
      SKR_DECIMALS: '6',
      JUPITER_FEE_ACCOUNT_SOL: 'sol-fee-account',
    });
    expect(tokens.map((t) => t.symbol)).not.toContain('SOL');
    expect(() => parsePaySymbol('SOL')).toThrow(/payWith must be one of/);
  });

  it('withholds SKR rather than guessing its decimals', () => {
    // SKR is 6 decimals, not the 9 most Solana tokens use. Defaulting would
    // scale a 10 SKR buy to 10_000 SKR, so an unstated value drops the token.
    for (const decimals of [undefined, '', 'nine', '-1']) {
      const tokens = loadPayTokens({ SKR_MINT: SKR, SKR_DECIMALS: decimals });
      expect(tokens.map((t) => t.symbol)).toEqual(['USDC']);
    }
  });

  it('scales each token by its own decimals, never a shared constant', () => {
    const [usdc, skr] = loadPayTokens({ SKR_MINT: SKR, SKR_DECIMALS: '9' });
    expect(usdc).toMatchObject({ mint: USDC_MINT, decimals: 6 });

    // The bug this guards: 10 units is 10_000_000 at 6 decimals but
    // 10_000_000_000 at 9. Sharing one constant would be a 1000x error.
    expect(Math.round(10 * 10 ** usdc.decimals)).toBe(10_000_000);
    expect(Math.round(10 * 10 ** skr.decimals)).toBe(10_000_000_000);
  });

  it('gives each token its own fee account, since Jupiter matches on mint', () => {
    const tokens = loadPayTokens({
      SKR_MINT: SKR,
      SKR_DECIMALS: '6',
      JUPITER_FEE_ACCOUNT_USDC: 'usdc-fee-account',
      JUPITER_FEE_ACCOUNT_SKR: 'skr-fee-account',
    });
    expect(tokens.find((t) => t.symbol === 'USDC')?.feeAccount).toBe('usdc-fee-account');
    expect(tokens.find((t) => t.symbol === 'SKR')?.feeAccount).toBe('skr-fee-account');
  });

  it('falls back to the old single-account name for USDC', () => {
    const [usdc] = loadPayTokens({ JUPITER_FEE_ACCOUNT: 'legacy-account' });
    expect(usdc.feeAccount).toBe('legacy-account');
  });

  it('leaves a token without a fee account earning nothing, not failing', () => {
    const tokens = loadPayTokens({ SKR_MINT: SKR, SKR_DECIMALS: '6' });
    expect(tokens.find((t) => t.symbol === 'SKR')?.feeAccount).toBe('');
  });

  it('defaults to USDC and rejects anything it does not accept', () => {
    expect(parsePaySymbol(undefined)).toBe('USDC');
    expect(parsePaySymbol('skr')).toBe('SKR');
    expect(() => parsePaySymbol('ETH')).toThrow(/payWith must be one of/);
  });
});
