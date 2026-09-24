import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/features/profile/ui/cubits/profile_state.dart';
import 'package:formation/features/shared/domain/models.dart';

/// W/L and league rank for each sport.
class RecordSummary extends StatelessWidget {
  const RecordSummary({required this.records, super.key});

  final Map<SportMode, SportRecord> records;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final mode in SportMode.values)
            ListTile(
              leading: Icon(mode.icon, color: AppColors.primary),
              title: Text(mode.label),
              subtitle: Text(
                records[mode]?.rank == null
                    ? 'No team yet'
                    : 'Rank #${records[mode]!.rank} · ${formatPoints(records[mode]!.points ?? 0)} pts',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              trailing: Text(
                '${records[mode]?.wins ?? 0}W – ${records[mode]?.losses ?? 0}L',
                style: AppTextStyles.mono(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}
