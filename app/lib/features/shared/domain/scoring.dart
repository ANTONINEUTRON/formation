/// Scoring math from spec §3.5, extended with FPL-style captaincy and bench.
/// Mirrors `backend/src/scoring/score-window.ts` so the fixture repository
/// scores exactly like the real backend.
library;

/// One roster slot's state at the start and end of a scoring window.
class SlotWindow {
  const SlotWindow({
    required this.startBalance,
    required this.endBalance,
    required this.startPrice,
    required this.endPrice,
    this.weight = 1,
    this.role,
    this.benchOrder,
    this.isViceCaptain = false,
  });

  final double startBalance;
  final double endBalance;
  final double startPrice;
  final double endPrice;

  /// 0 = substitute, 1 = starter, 2 = captain.
  final double weight;

  /// Squad role for like-for-like auto-subs ('GK', 'DEF', ...). Null when the
  /// sport has no bench.
  final String? role;

  /// Position in the substitution order; null for starters.
  final int? benchOrder;
  final bool isViceCaptain;

  /// Only shares held for the whole window count.
  bool get counts =>
      (startBalance < endBalance ? startBalance : endBalance) > 0 && startPrice > 0;

  double get returnPct => (endPrice - startPrice) / startPrice;
}

class WindowScore {
  const WindowScore({required this.returnPct, required this.points});

  /// Weighted average slot return across counted slots, as a fraction.
  final double returnPct;

  /// 1 basis point of return = 1 point.
  final int points;
}

/// Scores a roster over one window.
///
/// - A slot whose `min(startBalance, endBalance)` is zero doesn't count, so
///   buying a pumping token mid-window earns nothing until the next baseline.
/// - The captain counts double. If the captain doesn't count, the
///   vice-captain gets the double weight instead.
/// - A starter who doesn't count is replaced by the first substitute of the
///   same role, in bench order. Substitutes otherwise score nothing.
/// - Returns are weight-averaged, not summed, so roster size doesn't change
///   the magnitude.
WindowScore scoreWindow(List<SlotWindow> slots) {
  final weights = [for (final s in slots) s.weight];

  final captain = slots.indexWhere((s) => s.weight >= 2);
  if (captain != -1 && !slots[captain].counts) {
    final vice = slots.indexWhere((s) => s.isViceCaptain && s.weight > 0 && s.counts);
    if (vice != -1) weights[vice] = 2;
  }

  final bench = [
    for (var i = 0; i < slots.length; i++)
      if (slots[i].weight == 0 && slots[i].benchOrder != null && slots[i].counts) i,
  ]..sort((a, b) => slots[a].benchOrder!.compareTo(slots[b].benchOrder!));
  for (final s in slots) {
    if (s.weight == 0 || s.counts || s.role == null) continue;
    final sub = bench.indexWhere((b) => slots[b].role == s.role);
    if (sub != -1) weights[bench.removeAt(sub)] = 1;
  }

  var total = 0.0;
  var weighted = 0.0;
  for (var i = 0; i < slots.length; i++) {
    if (weights[i] <= 0 || !slots[i].counts) continue;
    total += weights[i];
    weighted += weights[i] * slots[i].returnPct;
  }
  if (total == 0) return const WindowScore(returnPct: 0, points: 0);
  final avg = weighted / total;
  return WindowScore(returnPct: avg, points: (avg * 10000).round());
}
