import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/shared/ui/widgets/armband_badge.dart';

/// A tappable roster position on the formation board or bench.
class PositionSlotChip extends StatelessWidget {
  const PositionSlotChip({
    required this.slot,
    required this.size,
    required this.onTap,
    this.armband,
    this.isSelected = false,
    this.isHighlighted = false,
    super.key,
  });

  final RosterSlot slot;
  final double size;
  final VoidCallback onTap;

  /// 'C' or 'V' badge, if any.
  final String? armband;

  /// The player currently being substituted.
  final bool isSelected;

  /// A legal substitution partner.
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final stock = slot.stock;
    final color = stock?.tier.color ?? slot.position.requiredTier?.color ?? AppColors.textPrimary;
    final ring = isSelected
        ? Colors.white
        : isHighlighted
            ? AppColors.primaryLight
            : null;
    final symbol = stock == null
        ? null
        : stock.symbol.endsWith('x')
            ? stock.symbol.substring(0, stock.symbol.length - 1)
            : stock.symbol;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: stock == null ? AppColors.background.withValues(alpha: 0.6) : color,
                    border: Border.all(
                      color: ring ?? color,
                      width: ring != null ? 3 : (stock == null ? 2 : 0),
                    ),
                    boxShadow: [
                      if (ring != null)
                        BoxShadow(color: ring.withValues(alpha: 0.7), blurRadius: 14)
                      else if (stock != null)
                        BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: stock == null
                      ? Icon(Icons.add, color: color, size: size * 0.45)
                      : Padding(
                          padding: const EdgeInsets.all(4),
                          child: FittedBox(
                            child: Text(
                              symbol!,
                              style: AppTextStyles.mono(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textInverse,
                              ),
                            ),
                          ),
                        ),
                ),
                if (armband != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: ArmbandBadge(label: armband!, size: size * 0.38),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              slot.position.label,
              style: AppTextStyles.mono(fontSize: 10, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
