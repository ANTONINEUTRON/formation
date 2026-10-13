import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';

/// "Not scoring: stale price" — shown wherever a stock whose price can't be
/// trusted right now appears. It stays on the team and tradable; it just banks
/// nothing until its price has been reliable for a day.
class NotScoringBadge extends StatelessWidget {
  const NotScoringBadge({required this.reason, this.compact = false, super.key});

  final String reason;

  /// Just the label, for tight rows.
  final bool compact;

  static const color = AppColors.warning;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Not scoring: $reason. It banks nothing until its price has been '
          'reliable for a day. You can keep it, bench it or swap it.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pause_circle_outline, size: 12, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                compact ? 'Not scoring' : 'Not scoring: $reason',
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.mono(fontSize: 10, fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
