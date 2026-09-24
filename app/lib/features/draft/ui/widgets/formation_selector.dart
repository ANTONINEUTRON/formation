import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/shared/domain/lineup.dart';

/// Horizontal picker of the FPL formations.
class FormationSelector extends StatelessWidget {
  const FormationSelector({required this.current, required this.onSelected, super.key});

  final Formation current;
  final ValueChanged<Formation> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: footballFormations.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final formation = footballFormations[i];
          final selected = formation == current;
          return ChoiceChip(
            label: Text(formation.name),
            selected: selected,
            showCheckmark: false,
            selectedColor: AppColors.primary,
            labelStyle: AppTextStyles.mono(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.textInverse : AppColors.textPrimary,
            ),
            onSelected: (_) {
              if (!selected) onSelected(formation);
            },
          );
        },
      ),
    );
  }
}
