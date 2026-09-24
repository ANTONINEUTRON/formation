import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/shared/domain/models.dart';

/// Chips for switching the leaderboard between all time, month, week and a
/// custom range. Picking "Custom" opens a date range picker; cancelling it
/// leaves the current period alone.
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    required this.period,
    required this.onChanged,
    super.key,
  });

  final LeaguePeriod period;
  final ValueChanged<LeaguePeriod> onChanged;

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: period.from == null
          ? null
          : DateTimeRange(start: period.from!, end: period.to ?? now),
      builder: (context, child) => Theme(data: AppTheme.darkTheme, child: child!),
    );
    if (range == null) return;
    onChanged(LeaguePeriod.custom(from: range.start, to: range.end));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: LeaguePeriodKind.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final kind = LeaguePeriodKind.values[i];
          final selected = period.kind == kind;
          // The custom chip shows the chosen range once there is one.
          final label = selected ? period.label : kind.label;

          return ChoiceChip(
            label: Text(label),
            selected: selected,
            showCheckmark: false,
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.background : AppColors.textSecondary,
            ),
            backgroundColor: AppColors.surface,
            selectedColor: AppColors.primary,
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border,
            ),
            onSelected: (_) {
              if (kind == LeaguePeriodKind.custom) {
                _pickCustom(context);
              } else {
                onChanged(LeaguePeriod(kind));
              }
            },
          );
        },
      ),
    );
  }
}
