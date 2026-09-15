import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';

enum AutonomyLevel { advisory, semiAuto, fullAuto }

/// Three-option autonomy picker used in agent forms.
class AutonomySelector extends StatelessWidget {
  const AutonomySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final AutonomyLevel value;
  final ValueChanged<AutonomyLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AutonomyOption(
          title: 'Advisory Only',
          subtitle: 'Agent suggests trades, you execute manually',
          icon: Icons.visibility_outlined,
          isSelected: value == AutonomyLevel.advisory,
          onTap: () => onChanged(AutonomyLevel.advisory),
        ),
        const SizedBox(height: 8),
        AutonomyOption(
          title: 'Semi-Autonomous',
          subtitle: 'Agent proposes trades, you approve via notification',
          icon: Icons.notification_important_outlined,
          isSelected: value == AutonomyLevel.semiAuto,
          onTap: () => onChanged(AutonomyLevel.semiAuto),
        ),
        const SizedBox(height: 8),
        AutonomyOption(
          title: 'Full Autonomy',
          subtitle: 'Agent executes trades within your risk limits',
          icon: Icons.smart_toy_outlined,
          isSelected: value == AutonomyLevel.fullAuto,
          onTap: () => onChanged(AutonomyLevel.fullAuto),
        ),
      ],
    );
  }
}

/// Single option row inside [AutonomySelector].
class AutonomyOption extends StatelessWidget {
  const AutonomyOption({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
