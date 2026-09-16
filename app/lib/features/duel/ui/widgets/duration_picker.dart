import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/features/shared/domain/models.dart';

/// Preset duel lengths: 1h / 6h / 24h / 3d / 7d.
class DurationPicker extends StatelessWidget {
  const DurationPicker({required this.selected, required this.onChanged, super.key});

  final Duration selected;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final d in duelDurations)
          ChoiceChip(
            label: Text(formatDuelDuration(d)),
            selected: d == selected,
            onSelected: (_) => onChanged(d),
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              color: d == selected ? AppColors.textInverse : AppColors.textPrimary,
            ),
            showCheckmark: false,
          ),
      ],
    );
  }
}
