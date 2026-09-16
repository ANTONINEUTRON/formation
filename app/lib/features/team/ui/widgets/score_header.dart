import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/utils/format.dart';
import 'package:symbians/core/widgets/stat_pill.dart';
import 'package:symbians/features/shared/domain/models.dart';

/// Big Classic points figure with rank, last tick return and roster value.
class ScoreHeader extends StatelessWidget {
  const ScoreHeader({required this.roster, required this.totalPlayers, super.key});

  final Roster roster;
  final int totalPlayers;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CLASSIC POINTS',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          // Animates from the previous value whenever a tick lands.
          TweenAnimationBuilder<double>(
            tween: Tween(end: roster.classicPoints.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              formatPoints(value.round()),
              style: AppTextStyles.mono(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            '${formatPct(roster.lastReturnPct)} last tick  ·  '
            '${formatSignedPoints((roster.lastReturnPct * 10000).round())} pts',
            style: AppTextStyles.mono(
              fontSize: 13,
              color: pnlColor(roster.lastReturnPct),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatPill(
                label: 'RANK',
                value: roster.classicRank == null
                    ? '—'
                    : '#${roster.classicRank} / $totalPlayers',
              ),
              StatPill(label: 'TEAM VALUE', value: formatUsd(roster.totalValueUsd)),
              StatPill(
                label: 'SLOTS',
                value:
                    '${roster.slots.where((s) => s.isFilled).length}/${roster.slots.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
