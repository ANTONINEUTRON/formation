import type { PriceInfo } from './chain.service.js';

/** Injection tokens for the two chain reads, so tests can fake them. */
export const PRICE_SOURCE = 'PRICE_SOURCE';
export const BALANCE_SOURCE = 'BALANCE_SOURCE';

export interface PriceSource {
  getPrices(mints: string[], options?: { fresh?: boolean }): Promise<Map<string, PriceInfo>>;
}

/** Market depth, measured from quotes; faked in tests. */
export const DEPTH_SOURCE = 'DEPTH_SOURCE';

export interface DepthSource {
  /**
   * Percent lost buying [usd] of [mint] and selling it straight back, from
   * quotes alone. Null when there's no route either way. Throws when the quote
   * service can't be reached, so a busy API never reads as a thin market.
   */
  roundTripLossPct(mint: string, usd: number): Promise<number | null>;
}

export interface BalanceSource {
  getBalances(wallet: string, options?: { fresh?: boolean }): Promise<Map<string, number>>;
  invalidateBalances(wallet?: string): void;
}
