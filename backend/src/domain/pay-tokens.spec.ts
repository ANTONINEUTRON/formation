import { loadPayTokens, parsePaySymbol, SOL_MINT, USDC_MINT } from './pay-tokens.js';

describe('pay tokens', () => {
  const SKR = 'SKRbvo6Gf7GondiT3BbTfuRDPqLWei4j2Qy2NPGZhW3';

  it('always offers USDC and SOL, and SKR only once its mint is set', () => {
    const without = loadPayTokens({});
    expect(without.map((t) => t.symbol)).toEqual(['USDC', 'SOL']);

    const withSkr = loadPayTokens({ SKR_MINT: SKR, SKR_DECIMALS: '6' });
    expect(withSkr.map((t) => t.symbol)).toEqual(['USDC', 'SOL', 'SKR']);
    expect(withSkr[2]).toMatchObject({ mint: SKR, decimals: 6 });
  });

  it('withholds SKR rather than guessing its decimals', () => {
    // SKR is 6 decimals, not the 9 most Solana tokens use. Defaulting would
    // scale a 10 SKR buy to 10_000 SKR, so an unstated value drops the token.
    for (const decimals of [undefined, '', 'nine', '-1']) {
      const tokens = loadPayTokens({ SKR_MINT: SKR, SKR_DECIMALS: decimals });
      expect(tokens.map((t) => t.symbol)).toEqual(['USDC', 'SOL']);
    }
  });

  it('carries the right decimals, which is what scales the swap amount', () => {
    const [usdc, sol] = loadPayTokens({});
    expect(usdc).toMatchObject({ mint: USDC_MINT, decimals: 6 });
    expect(sol).toMatchObject({ mint: SOL_MINT, decimals: 9 });

    // The bug this guards: $10 is 10_000_000 in USDC but 10_000_000_000 in
    // lamports. Sharing one constant would be a 1000x error on a real swap.
    expect(Math.round(10 * 10 ** usdc.decimals)).toBe(10_000_000);
    expect(Math.round(10 * 10 ** sol.decimals)).toBe(10_000_000_000);
  });

  it('gives each token its own fee account, since Jupiter matches on mint', () => {
    const tokens = loadPayTokens({
      JUPITER_FEE_ACCOUNT_USDC: 'usdc-fee-account',
      JUPITER_FEE_ACCOUNT_SOL: 'sol-fee-account',
    });
    expect(tokens.find((t) => t.symbol === 'USDC')?.feeAccount).toBe('usdc-fee-account');
    expect(tokens.find((t) => t.symbol === 'SOL')?.feeAccount).toBe('sol-fee-account');
  });

  it('falls back to the old single-account name for USDC', () => {
    const [usdc] = loadPayTokens({ JUPITER_FEE_ACCOUNT: 'legacy-account' });
    expect(usdc.feeAccount).toBe('legacy-account');
  });

  it('leaves a token without a fee account earning nothing, not failing', () => {
    const tokens = loadPayTokens({ JUPITER_FEE_ACCOUNT_USDC: 'usdc-fee-account' });
    expect(tokens.find((t) => t.symbol === 'SOL')?.feeAccount).toBe('');
  });

  it('defaults to USDC and rejects anything it does not accept', () => {
    expect(parsePaySymbol(undefined)).toBe('USDC');
    expect(parsePaySymbol('sol')).toBe('SOL');
    expect(() => parsePaySymbol('ETH')).toThrow(/payWith must be one of/);
  });
});
