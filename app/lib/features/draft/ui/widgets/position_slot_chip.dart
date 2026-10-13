import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/draft/ui/widgets/jersey.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/shared/ui/widgets/armband_badge.dart';
import 'package:formation/features/shared/ui/widgets/not_scoring_badge.dart';

/// A tappable roster position on the formation board: the sport's jersey in
/// the pick's tier colour with its ticker on the chest, or a dashed outline
/// with a "+" while the slot is empty.
class PositionSlotChip extends StatelessWidget {
  const PositionSlotChip({
    required this.mode,
    required this.slot,
    required this.size,
    this.onTap,
    this.armband,
    this.isSelected = false,
    this.isHighlighted = false,
    this.liveGoal = false,
    super.key,
  });

  /// It scored today: provisional until the daily rollup.
  final bool liveGoal;

  /// Decides the jersey: football shirt, basketball vest or gridiron jersey.
  final SportMode mode;
  final RosterSlot slot;
  final double size;
  final VoidCallback? onTap;

  /// Dark ink on light shirts, light ink on dark ones, so the ticker reads.
  static Color _ink(Color shirt) =>
      shirt.computeLuminance() > 0.35 ? AppColors.textInverse : AppColors.textPrimary;

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
      // A pointer has to be told this is clickable; a finger does not.
      // MouseRegion is inert off the web, so the chip is unchanged there.
      child: MouseRegion(
        cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  size: Size.square(size),
                  painter: JerseyPainter(mode: mode, color: color, filled: stock != null, ring: ring),
                ),
                // The ticker sits on the chest, like a name on a shirt.
                Positioned(
                  left: size * 0.26,
                  right: size * 0.26,
                  top: size * (JerseyPainter.chestY(mode) - 0.16),
                  height: size * 0.3,
                  child: stock == null
                      ? Icon(Icons.add, color: color, size: size * 0.3)
                      : FittedBox(
                          child: Text(
                            symbol!,
                            style: AppTextStyles.mono(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _ink(color),
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
                if (liveGoal)
                  Positioned(
                    top: -4,
                    left: -4,
                    child: Tooltip(
                      message: 'Scored today (provisional)',
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                        child: Icon(mode.icon, size: size * 0.28, color: AppColors.primary),
                      ),
                    ),
                  ),
                // A price that can't be trusted right now: kept, but banking nothing.
                if (stock?.notScoring != null)
                  Positioned(
                    bottom: 0,
                    right: -2,
                    child: Tooltip(
                      message: 'Not scoring: ${stock!.notScoring}',
                      child: Container(
                        decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                        child: Icon(Icons.pause_circle, size: size * 0.32, color: NotScoringBadge.color),
                      ),
                    ),
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
      ),
    );
  }
}
