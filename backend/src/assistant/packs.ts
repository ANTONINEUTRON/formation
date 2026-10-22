/** A bundle of Assistant Manager credits, priced in dollars and paid in SKR. */
export interface CreditPack {
  id: string;
  credits: number;
  usd: number;
}

/**
 * 5¢ a credit at $5, stepping down evenly to 3¢ at $50:
 * $5 = 100 (5¢), $10 = 230 (4.35¢), $20 = 550 (3.64¢), $50 = 1,650 (3.03¢).
 */
export const DEFAULT_PACKS = '100:5,230:10,550:20,1650:50';

/**
 * Reads ASSISTANT_PACKS, e.g. "100:5,230:10" (credits:usd). A malformed entry
 * is a configuration mistake that would otherwise surface as a wrong price on
 * screen, so it throws at boot rather than being skipped.
 */
export function parsePacks(value: string | undefined): CreditPack[] {
  const raw = value?.trim() || DEFAULT_PACKS;
  const packs = raw.split(',').map((entry) => {
    const [credits, usd] = entry.split(':').map((part) => Number(part.trim()));
    if (!Number.isInteger(credits) || credits <= 0 || !Number.isFinite(usd) || usd <= 0) {
      throw new Error(`ASSISTANT_PACKS entry "${entry}" must look like credits:usd, e.g. 50:1`);
    }
    return { id: `credits-${credits}`, credits, usd };
  });
  if (new Set(packs.map((p) => p.id)).size !== packs.length) {
    throw new Error('ASSISTANT_PACKS lists the same credit amount twice');
  }
  return packs.sort((a, b) => a.credits - b.credits);
}
