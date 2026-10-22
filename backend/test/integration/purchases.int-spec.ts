import { AssistantService } from '../../src/assistant/assistant.service.js';
import { PurchasesService } from '../../src/assistant/purchases.service.js';
import { MEMO_PREFIX } from '../../src/assistant/skr-payments.js';
import type { ObservedPayment } from '../../src/assistant/skr-payments.js';
import type { AuthUser } from '../../src/domain/dto.js';
import { TEST_SKR, createHarness } from './harness.js';
import type { Harness } from './harness.js';

describe('buying assistant credits with SKR', () => {
  let h: Harness;
  let purchases: PurchasesService;
  let assistant: AssistantService;
  let manager: AuthUser;

  /** What the chain would report for an honest payment of [quoteId]. */
  const paid = (quoteId: string, amountRaw: bigint, over: Partial<ObservedPayment> = {}): ObservedPayment => ({
    succeeded: true,
    blockTime: Math.floor(h.clock.now() / 1000),
    signers: [manager.walletAddress],
    transfers: [
      { mint: TEST_SKR.mint, destination: TEST_SKR.treasury, authority: manager.walletAddress, amountRaw },
    ],
    memos: [`${MEMO_PREFIX}${quoteId}`],
    ...over,
  });

  beforeAll(async () => {
    h = await createHarness();
    purchases = h.app.get(PurchasesService);
    assistant = h.app.get(AssistantService);
  });

  afterAll(async () => {
    await h.close();
  });

  beforeEach(async () => {
    await h.reset();
    manager = await h.createPlayer('marcus');
  });

  it('lists the packs and prices one in SKR at the live price', async () => {
    const profile = await assistant.profile(manager);
    expect(profile.canBuyCredits).toBe(true);
    expect(profile.packs.map((p) => p.id)).toEqual(['credits-100', 'credits-230', 'credits-550', 'credits-1650']);

    // $1 at $0.02 per SKR is 50 SKR.
    const quote = await purchases.quote(manager, 'credits-100');
    expect(quote).toMatchObject({ credits: 100, usd: 5, skrAmount: 250 }); // $5 at $0.02 an SKR
    await expect(purchases.quote(manager, 'credits-7')).rejects.toThrow(/Unknown credit pack/);
  });

  it('builds the transfer to the treasury and credits the Manager once it lands', async () => {
    await assistant.profile(manager); // trial credits: 5
    const quote = await purchases.quote(manager, 'credits-100');
    await purchases.build(manager, quote.quoteId);

    const request = h.skrPayments.built[0];
    expect(request).toMatchObject({
      payer: manager.walletAddress,
      mint: TEST_SKR.mint,
      treasury: TEST_SKR.treasury,
      amountRaw: 250_000_000n,
      memo: `${MEMO_PREFIX}${quote.quoteId}`,
    });

    h.skrPayments.onChain.set('sig-1', paid(quote.quoteId, 250_000_000n));
    expect(await purchases.confirm(manager, { quoteId: quote.quoteId, signature: 'sig-1' })).toEqual({
      credits: 111,
    });

    // Neither the quote nor the transaction can be counted twice.
    await expect(
      purchases.confirm(manager, { quoteId: quote.quoteId, signature: 'sig-1' }),
    ).rejects.toThrow(/already counted/);
    const second = await purchases.quote(manager, 'credits-100');
    h.skrPayments.onChain.set('sig-1', paid(second.quoteId, 250_000_000n));
    await expect(
      purchases.confirm(manager, { quoteId: second.quoteId, signature: 'sig-1' }),
    ).rejects.toThrow(/already counted/);
    expect((await assistant.profile(manager)).credits).toBe(111);
  });

  it('refuses a payment that does not match the quote, and grants nothing', async () => {
    await assistant.profile(manager);
    const quote = await purchases.quote(manager, 'credits-100');
    h.skrPayments.onChain.set('short', paid(quote.quoteId, 249_000_000n));
    await expect(
      purchases.confirm(manager, { quoteId: quote.quoteId, signature: 'short' }),
    ).rejects.toThrow(/less than the quoted amount/);

    const stranger = await h.createPlayer('stranger');
    await expect(purchases.confirm(stranger, { quoteId: quote.quoteId, signature: 'short' })).rejects.toThrow(
      /Unknown quote/,
    );
    expect((await assistant.profile(manager)).credits).toBe(11);
  });

  it('will not build from an expired quote', async () => {
    const quote = await purchases.quote(manager, 'credits-230');
    h.clock.advance(3);
    await expect(purchases.build(manager, quote.quoteId)).rejects.toThrow(/expired/);
  });
});
