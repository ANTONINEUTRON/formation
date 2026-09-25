import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/shared/domain/models.dart';

/// Pinned above the leaderboard so the user's standing is always visible.
class MyRankBanner extends StatelessWidget {
  const MyRankBanner({
    required this.mode,
    required this.me,
    required this.totalPlayers,
    required this.onDraftTeam,
    super.key,
  });

  final SportMode mode;
  final LeaderboardEntry? me;
  final int totalPlayers;
  final VoidCallback onDraftTeam;

  @override
  Widget build(BuildContext context) {
    final me = this.me;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.22),
            AppColors.secondary.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: me == null
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    'Draft a ${mode.label} team to join the global league.',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: onDraftTeam, child: const Text('Draft')),
              ],
            )
          : Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR RANK',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        text: '#${me.rank}',
                        style: AppTextStyles.mono(fontSize: 28, fontWeight: FontWeight.w800),
                        children: [
                          TextSpan(
                            text: ' of $totalPlayers',
                            style: AppTextStyles.mono(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    
              ],
                ),
              ],
            ),
    );
  }
}
