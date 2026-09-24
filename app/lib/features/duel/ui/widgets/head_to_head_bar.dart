import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/utils/format.dart';

/// Diverging bar from a shared centre: the user's points grow left, the
/// rival's grow right, and whoever leads is coloured.
class HeadToHeadBar extends StatelessWidget {
  const HeadToHeadBar({
    required this.myPoints,
    required this.rivalPoints,
    required this.myLabel,
    required this.rivalLabel,
    this.height = 10,
    super.key,
  });

  final double myPoints;
  final double rivalPoints;
  final String myLabel;
  final String rivalLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxAbs = [myPoints.abs(), rivalPoints.abs(), 1.0].reduce((a, b) => a > b ? a : b);
    final iLead = myPoints >= rivalPoints;

    Widget half({required double value, required bool leading, required bool mirrored}) {
      final fraction = (value.abs() / maxAbs).clamp(0.04, 1.0);
      return Expanded(
        child: Align(
          alignment: mirrored ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              height: height,
              decoration: BoxDecoration(
                color: leading ? AppColors.primary : AppColors.textMuted.withValues(alpha: 0.5),
                borderRadius: BorderRadius.horizontal(
                  left: mirrored ? Radius.circular(height) : Radius.zero,
                  right: mirrored ? Radius.zero : Radius.circular(height),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            half(value: myPoints, leading: iLead, mirrored: true),
            Container(width: 2, height: height + 8, color: AppColors.textSecondary),
            half(value: rivalPoints, leading: !iLead, mirrored: false),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                '$myLabel  ${formatSignedPoints(myPoints)}',
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.mono(fontSize: 12, color: pnlColor(myPoints)),
              ),
            ),
            Expanded(
              child: Text(
                '${formatSignedPoints(rivalPoints)}  $rivalLabel',
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.mono(fontSize: 12, color: pnlColor(rivalPoints)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
