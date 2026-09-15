import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';

/// 1-5 risk level picker used in agent forms.
class RiskLevelSelector extends StatelessWidget {
  const RiskLevelSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  static const _labels = ['Very Low', 'Low', 'Medium', 'High', 'Very High'];
  static const _colors = [
    AppColors.success,
    Color(0xFF84cc16), // lime
    AppColors.warning,
    Color(0xFFf97316), // orange
    AppColors.error,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (i) {
              final isSelected = i + 1 == value;
              return GestureDetector(
                onTap: () => onChanged(i + 1),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _colors[i].withValues(alpha: 0.2)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? _colors[i] : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: isSelected ? _colors[i] : AppColors.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(
            _labels[value - 1],
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _colors[value - 1],
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
