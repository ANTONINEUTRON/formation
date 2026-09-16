import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/utils/format.dart';
import 'package:symbians/features/profile/ui/widgets/icon_action.dart';

class ProfileCard extends StatelessWidget {
  const ProfileCard({required this.walletAddress, super.key});

  final String walletAddress;

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
                  shortAddress(walletAddress),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Formation player',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
              ],
            ),
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
