import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/features/shared/domain/models.dart';
import 'package:symbians/features/team/ui/widgets/roster_slot_card.dart';

/// The Team tab's roster list. Football shows the starting XI with its
/// formation and armbands, then the bench in auto-sub order.
class LineupSection extends StatelessWidget {
  const LineupSection({required this.roster, required this.onEdit, super.key});

  final Roster roster;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final lineup = roster.lineup;
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    if (lineup == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Lineup', style: titleStyle),
              const Spacer(),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
            ],
          ),
          for (final slot in roster.slots) ...[
            RosterSlotCard(slot: slot, teamValueUsd: roster.totalValueUsd),
            const SizedBox(height: 8),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Starting XI', style: titleStyle),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                lineup.formation.name,
                style: AppTextStyles.mono(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('Pick team'),
            ),
          ],
        ),
        for (final i in lineup.starters) ...[
          RosterSlotCard(
            slot: roster.slots[i],
            teamValueUsd: roster.totalValueUsd,
            armband: lineup.armband(i),
          ),
          const SizedBox(height: 8),
        ],
        const Padding(
          padding: EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            'SUBSTITUTES',
            style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: AppColors.textMuted),
          ),
        ),
        for (final i in lineup.bench) ...[
          RosterSlotCard(slot: roster.slots[i], teamValueUsd: roster.totalValueUsd, isSubstitute: true),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
