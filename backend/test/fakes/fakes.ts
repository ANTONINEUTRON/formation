import type { PriceInfo } from '../../src/core/chain.service.js';
import type { Clock } from '../../src/core/clock.js';
import type { BalanceSource, PriceSource } from '../../src/core/sources.js';

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
