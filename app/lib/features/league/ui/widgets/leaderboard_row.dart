import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/utils/format.dart';
import 'package:symbians/features/shared/domain/models.dart';

const _medalColors = [Color(0xFFFACC15), Color(0xFFCBD5E1), Color(0xFFD97706)];

class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({required this.entry, this.onTap, super.key});

  final LeaderboardEntry entry;

  /// Tapping another player's row starts a duel challenge.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isTop3 = entry.rank <= 3;
    final highlight = entry.isCurrentUser;

    return Material(
      color: highlight
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlight
                  ? AppColors.primary
                  : isTop3
                      ? _medalColors[entry.rank - 1].withValues(alpha: 0.4)
                      : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: isTop3
                    ? Icon(Icons.emoji_events,
                        color: _medalColors[entry.rank - 1], size: 22)
                    : Text(
                        '#${entry.rank}',
                        style: AppTextStyles.mono(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      highlight ? '${entry.username} (you)' : entry.username,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: highlight || isTop3
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    Text(
                      shortAddress(entry.walletAddress),
                      style: AppTextStyles.mono(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (entry.streak > 1) ...[
                const Icon(Icons.local_fire_department,
                    size: 16, color: AppColors.warning),
                Text(
                  '${entry.streak}',
                  style: AppTextStyles.mono(
                      fontSize: 12, color: AppColors.warning),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                formatPoints(entry.points),
                style: AppTextStyles.mono(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: highlight ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'pts',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
