/**
 * Whether a holding counts: worth at least [minUsd]. Points don't depend on
 * how much of a stock is held, so a few cents of one would otherwise score
 * like a full position.
 *
 * A holding with no known price can't be valued; it counts, since a stock
 * without a price doesn't score anyway.
 */
export function counts(balance: number, priceUsd: number | null | undefined, minUsd: number): boolean {
  if (!(balance > 0)) return false;
  if (!priceUsd || priceUsd <= 0 || minUsd <= 0) return true;
  // A hair under the line still counts, so $1.00 shown never reads as too little.
  return balance * priceUsd >= minUsd - 1e-6;
}

/** [balance] if it counts, otherwise 0. */
export const countedBalance = (balance: number, priceUsd: number | null | undefined, minUsd: number): number =>
  counts(balance, priceUsd, minUsd) ? balance : 0;
