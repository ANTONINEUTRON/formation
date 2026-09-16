import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';

/// Small labelled stat, e.g. "RANK / #12".
class StatPill extends StatelessWidget {
  const StatPill({
    required this.label,
    required this.value,
    this.color = AppColors.textPrimary,
    super.key,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.mono(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
