import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/utils/format.dart';
import 'package:symbians/features/shared/domain/models.dart';

/// Basketball duels are won on categories, like fantasy basketball's 9-cat.
class CategoryScoreboard extends StatelessWidget {
  const CategoryScoreboard({
    required this.categories,
    required this.viewerIsChallenger,
    super.key,
  });

  final List<DuelCategory> categories;

  /// Which side of each row belongs to the signed-in player.
  final bool viewerIsChallenger;

  @override
  Widget build(BuildContext context) {
    String side(DuelCategory c, bool mine) {
      final value = (mine == viewerIsChallenger) ? c.challenger : c.opponent;
      return c.isPercent ? formatPct(value, signed: false) : formatPoints(value);
    }

    bool won(DuelCategory c, bool mine) {
      final winner = mine == viewerIsChallenger ? 'challenger' : 'opponent';
      return c.winner == winner;
    }

    final myWins = categories.where((c) => won(c, true)).length;
    final rivalWins = categories.where((c) => won(c, false)).length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'CATEGORIES',
                style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: AppColors.textMuted),
              ),
              const Spacer(),
              Text(
                '$myWins – $rivalWins',
                style: AppTextStyles.mono(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: myWins >= rivalWins ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      side(category, true),
                      style: AppTextStyles.mono(
                        fontSize: 13,
                        fontWeight: won(category, true) ? FontWeight.w700 : FontWeight.w400,
                        color: won(category, true) ? AppColors.success : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      category.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      side(category, false),
                      textAlign: TextAlign.right,
                      style: AppTextStyles.mono(
                        fontSize: 13,
                        fontWeight: won(category, false) ? FontWeight.w700 : FontWeight.w400,
                        color: won(category, false) ? AppColors.error : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
