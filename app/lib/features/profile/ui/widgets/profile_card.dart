
import 'package:flutter/material.dart';
import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/features/profile/ui/widgets/icon_action.dart';

class ProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.person,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'John Doe',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@johndoe',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Joined April 2026',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
              ],
            ),
          ),

          // Action icons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconAction(
                icon: Icons.edit_outlined,
                tooltip: 'Edit profile',
                onTap: () {
                  // TODO: Edit profile
                },
              ),
              const SizedBox(width: 4),
              IconAction(
                icon: Icons.share_rounded,
                tooltip: 'Share profile',
                onTap: () {
                  // TODO: Share profile
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
