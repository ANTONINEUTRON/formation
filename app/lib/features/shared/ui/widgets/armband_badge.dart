import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';

/// Captain ('C') or vice-captain ('V') marker.
class ArmbandBadge extends StatelessWidget {
  const ArmbandBadge({required this.label, this.size = 18, super.key});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: label == 'C' ? const Color(0xFFFACC15) : AppColors.textPrimary,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.background, width: 1.5),
      ),
      child: Text(
        label,
        style: AppTextStyles.mono(
          fontSize: size * 0.55,
          fontWeight: FontWeight.w800,
          color: AppColors.textInverse,
        ),
      ),
    );
  }
}
