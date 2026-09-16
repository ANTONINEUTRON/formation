/**
 * Scoring math from the Formation spec §3.5, extended with FPL-style
 * captaincy and bench. Mirrored in `app/lib/features/shared/domain/scoring.dart`.
 */

export interface SlotWindow {
  startBalance: number;
  endBalance: number;
  startPrice: number;
  endPrice: number;
  /** 0 = substitute, 1 = starter, 2 = captain. Defaults to 1. */
  weight?: number;
  /** Squad role for like-for-like auto-subs ('GK', 'DEF', ...). */
  role?: string | null;
  /** Position in the substitution order; null for starters. */
  benchOrder?: number | null;
  isViceCaptain?: boolean;
}

export interface WindowScore {
  /** Weighted average slot return across counted slots, as a fraction. */
  returnPct: number;
  /** 1 basis point of return = 1 point. */
  points: number;
}

/** Only shares held for the whole window count. */
const counts = (s: SlotWindow) =>
  Math.min(s.startBalance, s.endBalance) > 0 && s.startPrice > 0;

/**
 * Scores a roster over one window.
 *
 * - A slot whose `min(startBalance, endBalance)` is zero doesn't count, so
 *   buying a pumping token mid-window earns nothing until the next baseline.
 * - The captain counts double. If the captain doesn't count, the
 *   vice-captain gets the double weight instead.
 * - A starter who doesn't count is replaced by the first substitute of the
 *   same role, in bench order. Substitutes otherwise score nothing.
 * - Returns are weight-averaged, not summed, so roster size doesn't change
 *   the magnitude.
 */
export function scoreWindow(slots: SlotWindow[]): WindowScore {
  const weights = slots.map((s) => s.weight ?? 1);

  const captain = slots.findIndex((s) => (s.weight ?? 1) >= 2);
  if (captain !== -1 && !counts(slots[captain])) {
    const vice = slots.findIndex(
      (s) => s.isViceCaptain && (s.weight ?? 1) > 0 && counts(s),
    );
    if (vice !== -1) weights[vice] = 2;
  }

  const bench = slots
    .map((_, i) => i)
    .filter((i) => weights[i] === 0 && slots[i].benchOrder != null && counts(slots[i]))
    .sort((a, b) => slots[a].benchOrder! - slots[b].benchOrder!);
  for (const s of slots) {
    if ((s.weight ?? 1) === 0 || counts(s) || s.role == null) continue;
    const sub = bench.findIndex((b) => slots[b].role === s.role);
    if (sub !== -1) weights[bench.splice(sub, 1)[0]] = 1;
  }

  let total = 0;
  let weighted = 0;
  slots.forEach((s, i) => {
    if (weights[i] <= 0 || !counts(s)) return;
    total += weights[i];
    weighted += weights[i] * ((s.endPrice - s.startPrice) / s.startPrice);
  });
  if (total === 0) return { returnPct: 0, points: 0 };
  const returnPct = weighted / total;
  // Round half away from zero, matching Dart's round().
  const bp = returnPct * 10_000;
  return { returnPct, points: Math.sign(bp) * Math.round(Math.abs(bp)) };
}

export interface SnapshotRow {
  token_mint: string;
  balance: number;
  price_usd: number;
  weight?: number;
  role?: string | null;
  bench_order?: number | null;
  is_vice?: boolean;
}

/**
 * Scores the change between two roster snapshots, matched by mint. Lineup
 * metadata comes from the start snapshot, so armband and bench changes only
 * apply from the next window.
 */
export function scoreSnapshots(
  start: SnapshotRow[],
  end: SnapshotRow[],
): WindowScore {
  const endByMint = new Map(end.map((row) => [row.token_mint, row]));
  return scoreWindow(
    start.map((s) => {
      const e = endByMint.get(s.token_mint);
      return {
        startBalance: s.balance,
        endBalance: e?.balance ?? 0,
        startPrice: s.price_usd,
        endPrice: e?.price_usd ?? s.price_usd,
        weight: s.weight ?? 1,
        role: s.role ?? null,
        benchOrder: s.bench_order ?? null,
        isViceCaptain: s.is_vice ?? false,
      };
    }),
  );
}
