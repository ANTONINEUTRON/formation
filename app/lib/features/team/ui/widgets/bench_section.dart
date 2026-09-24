import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/features/shared/domain/models.dart';

/// The bench: held xStocks that aren't in the starting lineup.
///
/// The wallet is the squad, so anything bought shows up here automatically and
/// can be substituted into any slot its tier allows.
class BenchSection extends StatelessWidget {
  const BenchSection({
    required this.bench,
    required this.onSubstitute,
    super.key,
  });

  final List<BenchSlot> bench;

  /// Called with the bench stock the player wants to bring on.
  final ValueChanged<BenchSlot> onSubstitute;

  @override
  Widget build(BuildContext context) {
    if (bench.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Bench',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Text(
              '${bench.length} held, not playing',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final slot in bench) ...[
          _BenchTile(slot: slot, onSubstitute: () => onSubstitute(slot)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _BenchTile extends StatelessWidget {
  const _BenchTile({required this.slot, required this.onSubstitute});

  final BenchSlot slot;
  final VoidCallback onSubstitute;

  @override
  Widget build(BuildContext context) {
    final canPlay = slot.eligibleSlots.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: slot.stock.tier.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              slot.stock.tier.label,
              style: TextStyle(fontSize: 9, color: slot.stock.tier.color),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.stock.symbol,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${formatShares(slot.balance)} · ${formatUsd(slot.valueUsd)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: canPlay ? onSubstitute : null,
            child: Text(canPlay ? 'Sub in' : 'No slot'),
          ),
        ],
      ),
    );
  }
}
