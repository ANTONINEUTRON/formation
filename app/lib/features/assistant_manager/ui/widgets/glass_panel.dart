import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';

/// Frosted glass: whatever is behind shows through, blurred and tinted, so the
/// assistant reads as a layer over the screen the Manager was on.
class GlassPanel extends StatelessWidget {
  const GlassPanel({required this.child, required this.borderRadius, super.key});

  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.surfaceElevated.withValues(alpha: 0.78),
                AppColors.background.withValues(alpha: 0.86),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}
