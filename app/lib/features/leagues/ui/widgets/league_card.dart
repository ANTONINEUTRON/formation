import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/features/shared/domain/models.dart';

/// One league in a list: who's in it, when it runs, and where it stands.
class LeagueCard extends StatelessWidget {
  const LeagueCard({required this.league, this.onTap, super.key});

  final League league;
  final VoidCallback? onTap;

  Color get _statusColor => switch (league.status) {
        LeagueStatus.live => AppColors.success,
        LeagueStatus.scheduled => AppColors.warning,
        LeagueStatus.fin => AppColors.textMuted,
      };

  String get _timing {
    if (league.status == LeagueStatus.scheduled) {
      final until = league.startsIn;
      return until.isNegative ? 'Starting now' : 'Starts in ${formatCountdown(until)}';
    }
    if (league.status == LeagueStatus.live) {
      final left = league.endsIn;
      return left.isNegative ? 'Settling' : '${formatCountdown(left)} left';
    }
    return 'Finished';
  }

  @override
  Widget build(BuildContext context) {
    final me = league.standings.where((s) => s.isCurrentUser).firstOrNull;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    league.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    league.status.label,
                    style: TextStyle(fontSize: 10, color: _statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  league.isDuel
                      ? Icons.sports_mma_outlined
                      : league.isPrivate
                          ? Icons.lock_outline
                          : Icons.public,
                  size: 13,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  league.isDuel
                      ? 'Head to head'
                      : '${league.memberCount} player${league.memberCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.schedule, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  _timing,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
            if (me != null) ...[
              const SizedBox(height: 8),
              Text(
                '#${me.rank} · ${formatSignedPoints(me.points)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: pnlColor(me.points),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
