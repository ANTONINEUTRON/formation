import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/features/draft/ui/widgets/position_slot_chip.dart';
import 'package:symbians/features/shared/domain/models.dart';

/// Football substitutes in auto-sub order, under the pitch.
class BenchStrip extends StatelessWidget {
  const BenchStrip({
    required this.roster,
    required this.onSlotTap,
    this.selectedSlot,
    this.highlightedSlots = const {},
    super.key,
  });

  final Roster roster;
  final ValueChanged<int> onSlotTap;
  final int? selectedSlot;
  final Set<int> highlightedSlots;

  @override
  Widget build(BuildContext context) {
    final bench = roster.lineup!.bench;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const RotatedBox(
            quarterTurns: 3,
            child: Text(
              'BENCH',
              style: TextStyle(fontSize: 10, letterSpacing: 1.4, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: 8),
          for (var order = 0; order < bench.length; order++)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    order == 0 ? 'GK' : '$order',
                    style: AppTextStyles.mono(fontSize: 10, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 2),
                  PositionSlotChip(
                    slot: roster.slots[bench[order]],
                    size: 42,
                    onTap: () => onSlotTap(bench[order]),
                    isSelected: selectedSlot == bench[order],
                    isHighlighted: highlightedSlots.contains(bench[order]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
