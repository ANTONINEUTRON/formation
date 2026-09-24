import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/core/widgets/stat_pill.dart';
import 'package:formation/features/shared/domain/models.dart';

/// Today's points front and centre, with the running total and rank behind.
class ScoreHeader extends StatelessWidget {
  const ScoreHeader({required this.roster, required this.totalPlayers, super.key});

  final Roster roster;
  final int totalPlayers;

  @override
  Widget build(BuildContext context) {
    final session = roster.session;
    final points = session?.points ?? 0;

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
          Text(
            session == null ? 'POINTS' : 'TODAY',
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          // Animates from the previous value whenever a tick lands.
          TweenAnimationBuilder<double>(
            tween: Tween(end: points),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              formatSignedPoints(value),
              style: AppTextStyles.mono(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: pnlColor(points),
              ),
            ),
          ),
          Text(
            session?.entered == false
                ? 'Finish your team to start scoring'
                : 'Banked today · beat SPYx to score',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatPill(label: 'SEASON', value: formatPoints(roster.classicPoints)),
              StatPill(
                label: 'RANK',
                value: roster.classicRank == null
                    ? '—'
                    : '#${roster.classicRank} / $totalPlayers',
              ),
              StatPill(label: 'TEAM VALUE', value: formatUsd(roster.totalValueUsd)),
            ],
          ),
        ],
      ),
    );
  }
}
