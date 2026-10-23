import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/features/draft/ui/widgets/formation_board.dart';
import 'package:formation/features/shared/domain/models.dart';

/// The picture shared from a team: the lineup on the pitch with the
/// Manager's name, points, rank and streak, in Formation's night-pitch look.
/// Drawn off screen at [size] (4:5, the shape feeds show best).
///
/// Your own team reads its numbers from the roster; another Manager's come
/// from their profile, so each can be passed in.
class TeamShareCard extends StatelessWidget {
  const TeamShareCard({
    required this.roster,
    required this.username,
    this.totalPlayers,
    this.streak = 0,
    this.seasonPoints,
    this.rank,
    this.todayPoints,
    super.key,
  });

  static const size = Size(400, 500);

  final Roster roster;
  final String username;

  /// Players on the board, for "#7 of 120"; null shows just the rank.
  final int? totalPlayers;
  final int streak;

  /// Override the roster's own season total, rank and today's points.
  final double? seasonPoints;
  final int? rank;
  final double? todayPoints;

  @override
  Widget build(BuildContext context) {
    final today = todayPoints ?? roster.session?.points ?? 0;
    final rank = this.rank ?? roster.classicRank;
    final season = seasonPoints ?? roster.classicPoints;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surfaceElevated, AppColors.background],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Image.asset('assets/brand/formation_logo_nobg.png', height: 22),
              const SizedBox(width: 8),
              Text(
                'FORMATION',
                style: AppTextStyles.mono(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderLight),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(roster.mode.icon, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(roster.mode.label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
              if (streak > 1) ...[
                const Icon(Icons.local_fire_department, size: 18, color: AppColors.warning),
                Text(
                  '$streak days',
                  style: AppTextStyles.mono(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warning),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Stat(label: 'SEASON', value: formatPoints(season)),
              _Stat(
                label: 'RANK',
                value: rank == null ? '—' : (totalPlayers == null ? '#$rank' : '#$rank of $totalPlayers'),
              ),
              _Stat(label: 'TODAY', value: formatSignedPoints(today), color: pnlColor(today)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: FormationBoard(roster: roster),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (roster.mode == SportMode.football && roster.formation != null)
                Text(
                  roster.formation!,
                  style: AppTextStyles.mono(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              const Spacer(),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    'formation.titalabs.xyz',
                    style: AppTextStyles.mono(fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color = AppColors.textPrimary});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 9, letterSpacing: 1.2, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: AppTextStyles.mono(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}
