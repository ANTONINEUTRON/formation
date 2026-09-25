import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/features/profile/ui/widgets/icon_action.dart';
import 'package:formation/features/shared/domain/models.dart';

class ProfileCard extends StatelessWidget {
  const ProfileCard({
    required this.walletAddress,
    this.profile,
    this.onEdit,
    super.key,
  });

  final String walletAddress;

  /// Null until the profile loads; the card falls back to the wallet address.
  final Profile? profile;
  final VoidCallback? onEdit;

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
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: profile == null
                ? const Icon(Icons.person, color: AppColors.primary, size: 32)
                : Text(
                    profile!.username.characters.first.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.username ?? shortAddress(walletAddress),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  shortAddress(walletAddress),
                  style: AppTextStyles.mono(fontSize: 11, color: AppColors.textMuted),
                ),
                if (profile?.bio case final bio? when bio.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    bio,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
                if (profile != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${profile!.followers} follower${profile!.followers == 1 ? '' : 's'} · '
                    'following ${profile!.following}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),

          if (onEdit != null)
            IconAction(
              icon: Icons.edit_outlined,
              tooltip: 'Edit profile',
              onTap: onEdit!,
            ),
          IconAction(
            icon: Icons.share_rounded,
            tooltip: 'Share profile',
            onTap: () => SharePlus.instance.share(ShareParams(
              text: 'Challenge me on Formation, fantasy sports with real stocks. My wallet: $walletAddress',
            )),
          ),
        ],
      ),
    );
  }
}
