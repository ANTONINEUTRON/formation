import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:formation/features/shared/domain/models.dart';

/// A player's jersey for the sport: a football shirt, a basketball vest or an
/// American football jersey over shoulder pads. Filled in the pick's tier
/// colour when the slot has a stock, a dashed outline when it's empty.
class JerseyPainter extends CustomPainter {
  JerseyPainter({required this.mode, required this.color, required this.filled, this.ring});

  final SportMode mode;
  final Color color;
  final bool filled;

  /// Highlight outline (being substituted, or a legal swap), if any.
  final Color? ring;

  @override
  void paint(Canvas canvas, Size size) {
    final path = jerseyPath(mode, size);

    if (!filled) {
      canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.35));
      _dashed(
        canvas,
        path,
        Paint()
          ..color = ring ?? color
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring != null ? 2.5 : 1.6,
      );
      return;
    }

    final glow = ring ?? color;
    canvas.drawPath(
      path.shift(const Offset(0, 1)),
      Paint()
        ..color = glow.withValues(alpha: ring != null ? 0.75 : 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.18)!, Color.lerp(color, Colors.black, 0.22)!],
        ).createShader(Offset.zero & size),
    );

    // Trim: collar and sleeve or armhole edges, a darker tone of the shirt.
    final trim = Paint()
      ..color = Color.lerp(color, Colors.black, 0.45)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, size.width * 0.035)
      ..strokeCap = StrokeCap.round;
    for (final line in _trimLines(mode, size)) {
      canvas.drawPath(line, trim);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = ring ?? Colors.black.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring != null ? 2.5 : 1,
    );
  }

  /// Where the chest is, as a fraction of the height, for the ticker.
  static double chestY(SportMode mode) => switch (mode) {
    SportMode.football => 0.6,
    SportMode.basketball => 0.62,
    SportMode.americanFootball => 0.64,
  };

  /// The outline in a [size] box. Shapes are drawn in unit coordinates.
  static Path jerseyPath(SportMode mode, Size size) {
    final s = size.width;
    final p = Path();
    Offset o(double x, double y) => Offset(x * s, y * size.height);
    void to(double x, double y) => p.lineTo(x * s, y * size.height);
    void curve(double cx, double cy, double x, double y) =>
        p.quadraticBezierTo(cx * s, cy * size.height, x * s, y * size.height);

    switch (mode) {
      case SportMode.football:
        // Short sleeves and a V-neck.
        p.moveTo(o(0.38, 0.06).dx, o(0.38, 0.06).dy);
        to(0.17, 0.11);
        to(0.0, 0.29);
        to(0.13, 0.44);
        to(0.23, 0.36);
        to(0.23, 0.95);
        curve(0.5, 0.99, 0.77, 0.95);
        to(0.77, 0.36);
        to(0.87, 0.44);
        to(1.0, 0.29);
        to(0.83, 0.11);
        to(0.62, 0.06);
        to(0.5, 0.2);
      case SportMode.basketball:
        // A vest: narrow straps, deep armholes, scoop neck.
        p.moveTo(o(0.35, 0.04).dx, o(0.35, 0.04).dy);
        to(0.25, 0.04);
        curve(0.28, 0.32, 0.15, 0.4);
        to(0.17, 0.95);
        curve(0.5, 0.99, 0.83, 0.95);
        to(0.85, 0.4);
        curve(0.72, 0.32, 0.75, 0.04);
        to(0.65, 0.04);
        curve(0.5, 0.26, 0.35, 0.04);
      case SportMode.americanFootball:
        // Big rounded shoulder pads, stubby sleeves, a waist that tapers in.
        p.moveTo(o(0.4, 0.1).dx, o(0.4, 0.1).dy);
        curve(0.1, -0.04, 0.0, 0.2);
        to(0.0, 0.31);
        to(0.07, 0.38);
        to(0.21, 0.35);
        to(0.29, 0.95);
        curve(0.5, 0.99, 0.71, 0.95);
        to(0.79, 0.35);
        to(0.93, 0.38);
        to(1.0, 0.31);
        to(1.0, 0.2);
        curve(0.9, -0.04, 0.6, 0.1);
        curve(0.5, 0.2, 0.4, 0.1);
    }
    return p..close();
  }

  static List<Path> _trimLines(SportMode mode, Size size) {
    final s = size.width;
    final h = size.height;
    Path line(List<(double, double)> points) {
      final p = Path()..moveTo(points.first.$1 * s, points.first.$2 * h);
      for (final (x, y) in points.skip(1)) {
        p.lineTo(x * s, y * h);
      }
      return p;
    }

    return switch (mode) {
      SportMode.football => [
        line([(0.38, 0.06), (0.5, 0.2), (0.62, 0.06)]),
        line([(0.03, 0.33), (0.14, 0.42)]),
        line([(0.97, 0.33), (0.86, 0.42)]),
      ],
      SportMode.basketball => [
        Path()
          ..moveTo(0.35 * s, 0.04 * h)
          ..quadraticBezierTo(0.5 * s, 0.26 * h, 0.65 * s, 0.04 * h),
        Path()
          ..moveTo(0.25 * s, 0.04 * h)
          ..quadraticBezierTo(0.28 * s, 0.32 * h, 0.15 * s, 0.4 * h),
        Path()
          ..moveTo(0.75 * s, 0.04 * h)
          ..quadraticBezierTo(0.72 * s, 0.32 * h, 0.85 * s, 0.4 * h),
      ],
      SportMode.americanFootball => [
        Path()
          ..moveTo(0.4 * s, 0.1 * h)
          ..quadraticBezierTo(0.5 * s, 0.2 * h, 0.6 * s, 0.1 * h),
        // The edge of the shoulder pads, and sleeve stripes.
        Path()
          ..moveTo(0.06 * s, 0.24 * h)
          ..quadraticBezierTo(0.5 * s, 0.34 * h, 0.94 * s, 0.24 * h),
        line([(0.02, 0.33), (0.11, 0.37)]),
        line([(0.98, 0.33), (0.89, 0.37)]),
      ],
    };
  }

  static void _dashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 4, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(JerseyPainter old) =>
      old.mode != mode || old.color != color || old.filled != filled || old.ring != ring;
}
