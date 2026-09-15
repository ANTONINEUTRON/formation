import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';

/// Toggle row for enabling/disabling an agent trading capability.
///
/// Displays an optional "SOON" badge when [comingSoon] is true and disables
/// the switch.
class CapabilityToggle extends StatelessWidget {
  const CapabilityToggle({
    super.key,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onChanged,
    this.comingSoon = false,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: comingSoon
            ? AppColors.surface.withValues(alpha: 0.5)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: comingSoon
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (comingSoon) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'SOON',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                        ),
                      ),
                    ],
                  ],
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
          Switch.adaptive(
            value: enabled,
            onChanged: comingSoon ? null : onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
