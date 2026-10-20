import type { ImageData, LlmProvider, LlmRequest, LlmResponse, SearchResult } from '../../src/assistant/llm.js';
import { LlmError } from '../../src/assistant/llm.js';
import type { ObservedPayment, SkrPayments, TransferRequest } from '../../src/assistant/skr-payments.js';
import type { PriceInfo } from '../../src/core/chain.service.js';
import type { Clock } from '../../src/core/clock.js';
import type { BalanceSource, PriceSource } from '../../src/core/sources.js';
import type { PushMessage, PushResult, PushSender } from '../../src/notifications/fcm.js';

/** Records pushes instead of calling FCM. Tokens in [invalid] answer as gone. */
export class FakePushSender implements PushSender {
  enabled = true;
  readonly sent: { token: string; message: PushMessage }[] = [];
  readonly invalid = new Set<string>();

  async send(token: string, message: PushMessage): Promise<PushResult> {
    if (this.invalid.has(token)) return 'invalid_token';
    this.sent.push({ token, message });
    return 'sent';
  }

  reset(): void {
    this.enabled = true;
    this.sent.length = 0;
    this.invalid.clear();
  }
}

/** Clock the tests move by hand. */
export class FakeClock implements Clock {
  constructor(private current = Date.UTC(2026, 0, 5, 12, 0, 0)) {}

  now(): number {
    return this.current;
  }

  date(): Date {
    return new Date(this.current);
  }

  set(at: number | Date): void {
    this.current = at instanceof Date ? at.getTime() : at;
  }

  advance(minutes: number): void {
    this.current += minutes * 60_000;
  }
}

/** Scripted prices; tests move a stock and re-run scoring. */
export class FakePriceSource implements PriceSource {
  private readonly prices = new Map<string, PriceInfo>();

  set(mint: string, usdPrice: number, priceChange24h = 0): void {
    this.prices.set(mint, { usdPrice, priceChange24h });
  }

  /** Multiplies the current price, e.g. 1.05 for +5%. */
  /** No price at all, as for a mint Jupiter doesn't know. */
  remove(mint: string): void {
    this.prices.delete(mint);
  }

  move(mint: string, factor: number): void {
    const current = this.prices.get(mint);
    if (current) this.set(mint, current.usdPrice * factor, current.priceChange24h);
  }

  getPrices(mints: string[]): Promise<Map<string, PriceInfo>> {
    return Promise.resolve(
      new Map(
        mints.flatMap((mint) => {
          const price = this.prices.get(mint);
          return price ? [[mint, price] as const] : [];
        }),
      ),
    );
  }
}

/** Wallet holdings the tests control, including selling mid-window. */
export class FakeBalanceSource implements BalanceSource {
  private readonly wallets = new Map<string, Map<string, number>>();

  set(wallet: string, mint: string, amount: number): void {
    const balances = this.wallets.get(wallet) ?? new Map<string, number>();
    balances.set(mint, amount);
    this.wallets.set(wallet, balances);
  }

  setAll(wallet: string, mints: string[], amount: number): void {
    for (const mint of mints) this.set(wallet, mint, amount);
  }

  getBalances(wallet: string): Promise<Map<string, number>> {
    return Promise.resolve(new Map(this.wallets.get(wallet) ?? []));
  }

  invalidateBalances(): void {
    // Nothing is cached in the fake.
  }
}

/**
 * Stands in for Gemini. Replies with whatever [reply] holds, records every
 * request so tests can check the context it was given, and fails on demand.
 */
export class FakeLlmProvider implements LlmProvider {
  available = true;
  fail = false;
  reply: unknown = { text: 'Looking good, boss.', mood: 'neutral', suggestions: [] };
  readonly requests: LlmRequest[] = [];

  async generate(request: LlmRequest): Promise<LlmResponse> {
    this.requests.push(request);
    if (this.fail) throw new LlmError('fake failure');
    return { json: this.reply, tokensIn: 100, tokensOut: 20 };
  }

  failSearch = false;
  readonly searches: string[] = [];

  async search(prompt: string): Promise<SearchResult> {
    this.searches.push(prompt);
    if (this.failSearch) throw new LlmError('fake search failure');
    return {
      text: 'Shares rose after strong quarterly results.',
      sources: [{ title: 'Example News', url: 'https://news.example.com/story' }],
      tokensIn: 50,
      tokensOut: 30,
    };
  }

  failImage = false;
  readonly imagePrompts: string[] = [];

  /** Echoes a tiny PNG named after the request, so tests can tell poses apart. */
  async editImage(prompt: string, image: ImageData): Promise<ImageData> {
    this.imagePrompts.push(prompt);
    if (this.failImage) throw new LlmError('fake image failure');
    return { mime: 'image/png', data: Buffer.concat([image.data.subarray(0, 4), Buffer.from(`#${this.imagePrompts.length}`)]) };
  }

  reset(): void {
    this.available = true;
    this.fail = false;
    this.failSearch = false;
    this.failImage = false;
    this.imagePrompts.length = 0;
    this.searches.length = 0;
    this.reply = { text: 'Looking good, boss.', mood: 'neutral', suggestions: [] };
    this.requests.length = 0;
  }
}

/** Stands in for the chain when buying credits: records builds, and reports whatever payment a test plants. */
export class FakeSkrPayments implements SkrPayments {
  readonly built: TransferRequest[] = [];
  readonly onChain = new Map<string, ObservedPayment>();

  async buildTransfer(request: TransferRequest): Promise<string> {
    this.built.push(request);
    return Buffer.from(JSON.stringify({ ...request, amountRaw: String(request.amountRaw) })).toString('base64');
  }

  async observe(signature: string): Promise<ObservedPayment | null> {
    return this.onChain.get(signature) ?? null;
  }

  reset(): void {
    this.built.length = 0;
    this.onChain.clear();
  }
}
