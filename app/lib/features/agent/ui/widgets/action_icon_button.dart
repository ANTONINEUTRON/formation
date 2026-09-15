
import 'package:flutter/material.dart';
import 'package:symbians/core/theme/theme.dart';

class ActionIconButton extends StatelessWidget {
  const ActionIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: AppColors.textMuted,
          size: 20,
        ),
      ),
    );
  }
}
