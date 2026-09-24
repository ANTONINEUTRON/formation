import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/utils/format.dart';
import 'package:symbians/core/widgets/stat_pill.dart';
import 'package:symbians/features/shared/domain/models.dart';

/// Gameweek points front and centre, with the season total and rank behind it.
class ScoreHeader extends StatelessWidget {
  const ScoreHeader({required this.roster, required this.totalPlayers, super.key});

  final Roster roster;
  final int totalPlayers;

  @override
  Widget build(BuildContext context) {
    final gameweek = roster.gameweek;
    final points = gameweek?.points ?? 0;

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
            gameweek == null ? 'POINTS' : 'GAMEWEEK ${gameweek.number}',
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
            gameweek?.entered == false
                ? 'Your team joins the next gameweek'
                : 'Points this gameweek · beat SPYx to score',
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
