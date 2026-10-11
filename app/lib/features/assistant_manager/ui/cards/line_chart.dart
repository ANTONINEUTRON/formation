import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/assistant_manager/domain/assistant_cards.dart';

/// Lines for a chart, in a stable order: the stocks first, the benchmark last.
const seriesColors = [AppColors.primary, AppColors.info, AppColors.tierBalanced, AppColors.warning];

Color colorForSeries(List<ChartSeries> all, ChartSeries series) => series.isBenchmark
    ? AppColors.textMuted
    : seriesColors[all.where((s) => !s.isBenchmark).toList().indexOf(series) % seriesColors.length];

/// % change lines with a zero baseline. Drag across it to read the values at
/// any moment; let go and it settles back to the latest.
class PercentLineChart extends StatefulWidget {
  const PercentLineChart({required this.series, this.height = 150, super.key});

  final List<ChartSeries> series;
  final double height;

  @override
  State<PercentLineChart> createState() => _PercentLineChartState();
}

class _PercentLineChartState extends State<PercentLineChart> {
  /// 0..1 across the chart while the Manager is scrubbing, null otherwise.
  double? _scrub;

  @override
  Widget build(BuildContext context) {
    final lines = widget.series.where((s) => s.points.length >= 2).toList();
    if (lines.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text(
            'Not enough price history yet.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      );
    }

    final start = lines.map((s) => s.points.first.$1).reduce((a, b) => a.isBefore(b) ? a : b);
    final end = lines.map((s) => s.points.last.$1).reduce((a, b) => a.isAfter(b) ? a : b);
    final at = _scrub == null
        ? end
        : start.add(Duration(milliseconds: (end.difference(start).inMilliseconds * _scrub!).round()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final s in lines)
              _Legend(color: colorForSeries(lines, s), label: s.symbol, value: _valueAt(s, at)),
            if (_scrub != null)
              Text(
                DateFormat('MMM d, HH:mm').format(at),
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, box) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (d) =>
                setState(() => _scrub = _fraction(d.localPosition.dx, box.maxWidth)),
            onHorizontalDragUpdate: (d) =>
                setState(() => _scrub = _fraction(d.localPosition.dx, box.maxWidth)),
            onHorizontalDragEnd: (_) => setState(() => _scrub = null),
            onTapDown: (d) => setState(() => _scrub = _fraction(d.localPosition.dx, box.maxWidth)),
            onTapUp: (_) => setState(() => _scrub = null),
            child: CustomPaint(
              size: Size(box.maxWidth, widget.height),
              painter: _LinesPainter(lines: lines, start: start, end: end, scrub: _scrub),
            ),
          ),
        ),
      ],
    );
  }

  double _fraction(double dx, double width) => (dx / width).clamp(0, 1);

  /// The last point at or before [at].
  double _valueAt(ChartSeries s, DateTime at) {
    var value = s.points.first.$2;
    for (final (time, pct) in s.points) {
      if (time.isAfter(at)) break;
      value = pct;
    }
    return value;
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, required this.value});

  final Color color;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 3, color: color),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
        const SizedBox(width: 4),
        Text(
          formatPctChange(value),
          style: AppTextStyles.mono(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: value >= 0 ? AppColors.success : AppColors.error,
          ),
        ),
      ],
    );
  }
}

/// "+1.24%" / "−0.80%", from a value already in percent.
String formatPctChange(double pct) => '${pct >= 0 ? '+' : '−'}${pct.abs().toStringAsFixed(2)}%';

class _LinesPainter extends CustomPainter {
  _LinesPainter({required this.lines, required this.start, required this.end, required this.scrub});

  final List<ChartSeries> lines;
  final DateTime start;
  final DateTime end;
  final double? scrub;

  @override
  void paint(Canvas canvas, Size size) {
    final values = [
      for (final s in lines)
        for (final p in s.points) p.$2,
    ];
    var lo = math.min(0.0, values.reduce(math.min));
    var hi = math.max(0.0, values.reduce(math.max));
    if (hi - lo < 0.5) {
      hi += 0.25;
      lo -= 0.25;
    }
    final pad = (hi - lo) * 0.08;
    lo -= pad;
    hi += pad;
    final span = end.difference(start).inMilliseconds.clamp(1, 1 << 62);

    double x(DateTime t) => size.width * t.difference(start).inMilliseconds / span;
    double y(double v) => size.height * (1 - (v - lo) / (hi - lo));

    // Zero line: above it the pick has gained, below it lost.
    final zero = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y(0)), Offset(size.width, y(0)), zero);

    // Benchmark first, so the stocks draw over it.
    for (final s in [...lines.where((l) => l.isBenchmark), ...lines.where((l) => !l.isBenchmark)]) {
      final path = Path();
      for (var i = 0; i < s.points.length; i++) {
        final (t, v) = s.points[i];
        i == 0 ? path.moveTo(x(t), y(v)) : path.lineTo(x(t), y(v));
      }
      final color = colorForSeries(lines, s);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.isBenchmark ? 1.4 : 2.2
        ..strokeJoin = StrokeJoin.round;
      if (s.isBenchmark) {
        _dashed(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }
    }

    if (scrub != null) {
      final sx = size.width * scrub!;
      canvas.drawLine(
        Offset(sx, 0),
        Offset(sx, size.height),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
    }
  }

  void _dashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 5, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_LinesPainter old) => old.lines != lines || old.scrub != scrub;
}
