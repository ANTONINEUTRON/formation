import type { PriceInfo } from './chain.service.js';

/** Injection tokens for the two chain reads, so tests can fake them. */
export const PRICE_SOURCE = 'PRICE_SOURCE';
export const BALANCE_SOURCE = 'BALANCE_SOURCE';

export interface PriceSource {
  getPrices(mints: string[], options?: { fresh?: boolean }): Promise<Map<string, PriceInfo>>;
}

export interface BalanceSource {
  getBalances(wallet: string, options?: { fresh?: boolean }): Promise<Map<string, number>>;
  invalidateBalances(wallet?: string): void;
}
