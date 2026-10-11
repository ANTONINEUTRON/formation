import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/assistant_manager/domain/assistant_cards.dart';
import 'package:formation/features/assistant_manager/ui/cards/line_chart.dart';

/// The shell every answer card sits in: dark glass, a title row, then content.
class CardFrame extends StatelessWidget {
  const CardFrame({required this.title, required this.child, this.trailing, this.icon, super.key});

  final String title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: AppColors.primary), const SizedBox(width: 6)],
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: AppTextStyles.mono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// A chart with range chips (1D, 7D, 30D) and a toggle for the S&P 500 line.
class RangedChart extends StatefulWidget {
  const RangedChart({required this.chart, super.key});

  final ChartData chart;

  @override
  State<RangedChart> createState() => _RangedChartState();
}

class _RangedChartState extends State<RangedChart> {
  String _range = '7D';
  bool _benchmark = true;

  @override
  Widget build(BuildContext context) {
    final ranges = [
      for (final r in chartRanges)
        if (widget.chart[r]?.isNotEmpty ?? false) r,
    ];
    final range = ranges.contains(_range) ? _range : (ranges.isEmpty ? _range : ranges.last);
    final series = [
      for (final s in widget.chart[range] ?? const <ChartSeries>[])
        if (_benchmark || !s.isBenchmark) s,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PercentLineChart(series: series),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final r in chartRanges)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _Chip(
                  label: r,
                  selected: r == range,
                  onTap: ranges.contains(r) ? () => setState(() => _range = r) : null,
                ),
              ),
            const Spacer(),
            _Chip(
              label: 'vs S&P 500',
              selected: _benchmark,
              onTap: () => setState(() => _benchmark = !_benchmark),
            ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: onTap == null
                ? AppColors.textMuted.withValues(alpha: 0.5)
                : selected
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
