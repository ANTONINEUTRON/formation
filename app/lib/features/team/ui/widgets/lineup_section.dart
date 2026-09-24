import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/utils/format.dart';
import 'package:symbians/features/shared/domain/models.dart';
import 'package:symbians/features/team/ui/widgets/roster_slot_card.dart';

/// The Team tab's roster list, with each pick's gameweek score.
class LineupSection extends StatelessWidget {
  const LineupSection({required this.roster, required this.onEdit, super.key});

  final Roster roster;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final isFootball = roster.mode == SportMode.football;
    final gameweek = roster.gameweek;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              isFootball ? 'Starting XI' : 'Lineup',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (isFootball && roster.formation != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  roster.formation!,
                  style: AppTextStyles.mono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
            const Spacer(),
            TextButton.icon(
              onPressed: onEdit,
              icon: Icon(isFootball ? Icons.tune : Icons.edit_outlined, size: 16),
              label: Text(isFootball ? 'Pick team' : 'Edit'),
            ),
          ],
        ),
        for (var i = 0; i < roster.slots.length; i++) ...[
          RosterSlotCard(
            slot: roster.slots[i],
            teamValueUsd: roster.totalValueUsd,
            score: gameweek?.scoreFor(i),
            armband: roster.armband(i),
          ),
          const SizedBox(height: 8),
        ],
        if (gameweek != null && gameweek.teamEvents.isNotEmpty) ...[
          const SizedBox(height: 4),
          for (final event in gameweek.teamEvents)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.group, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    '${event.label} ${formatSignedPoints(event.points)}',
                    style: AppTextStyles.mono(fontSize: 12, color: pnlColor(event.points)),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
