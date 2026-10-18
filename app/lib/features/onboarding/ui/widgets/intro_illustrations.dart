import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/shared/domain/models.dart';

/// Plays [builder]'s animation once, from 0 to 1, when first shown. With
/// animations switched off on the device it starts at the end.
class _PlayOnce extends StatefulWidget {
  const _PlayOnce({required this.duration, required this.builder});

  final Duration duration;
  final Widget Function(BuildContext context, double t) builder;

  @override
  State<_PlayOnce> createState() => _PlayOnceState();
}

class _PlayOnceState extends State<_PlayOnce> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: _controller, builder: (context, _) => widget.builder(context, _controller.value));
}

/// The part of [t] that falls between [start] and [end], eased, as 0..1.
double _phase(double t, double start, double end) =>
    Curves.easeOutCubic.transform(((t - start) / (end - start)).clamp(0.0, 1.0));

// ── Your stocks are your players ──────────────────────────────────────────────

/// A night pitch whose positions fill with stocks, one line at a time, each
/// in its tier's colour.
class PitchIllustration extends StatelessWidget {
  const PitchIllustration({super.key});

  // (position, tier, symbol, x, y) with x, y as fractions of the pitch.
  static const _players = [
    ('FWD', RiskTier.momentum, 'TSLAx', 0.32, 0.16),
    ('FWD', RiskTier.momentum, 'NVDAx', 0.68, 0.16),
    ('MID', RiskTier.balanced, 'MSFTx', 0.2, 0.43),
    ('MID', RiskTier.balanced, 'AMZNx', 0.5, 0.4),
    ('MID', RiskTier.balanced, 'METAx', 0.8, 0.43),
    ('DEF', RiskTier.blueChip, 'KOx', 0.3, 0.67),
    ('DEF', RiskTier.blueChip, 'JNJx', 0.7, 0.67),
    ('GK', RiskTier.blueChip, 'BRK.Bx', 0.5, 0.88),
  ];

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.82,
      child: _PlayOnce(
        duration: const Duration(milliseconds: 1600),
        builder: (context, t) => LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            final chip = (w * 0.24).clamp(56.0, 84.0);
            return Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _PitchPainter())),
                for (var i = 0; i < _players.length; i++)
                  _placed(_players[i], _phase(t, 0.1 + (_players.length - 1 - i) * 0.08, 0.5 + (_players.length - 1 - i) * 0.08), w, h, chip),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _placed((String, RiskTier, String, double, double) player, double p, double w, double h, double chip) {
    final (position, tier, symbol, x, y) = player;
    // Each one rises into place from just below its spot.
    return Positioned(
      left: x * w - chip / 2,
      top: y * h - chip * 0.34 + (1 - p) * 24,
      width: chip,
      child: Opacity(
        opacity: p,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tier.color.withValues(alpha: 0.85), width: 1.4),
            boxShadow: [BoxShadow(color: tier.color.withValues(alpha: 0.25 * p), blurRadius: 12)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(position, style: TextStyle(fontSize: 9, color: tier.color, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              FittedBox(
                child: Text(symbol, style: AppTextStyles.mono(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pitch = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(22));
    canvas.drawRRect(
      pitch,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF143A28), Color(0xFF0E2A1D)],
        ).createShader(Offset.zero & size),
    );

    // Mown stripes.
    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.025);
    final band = size.height / 8;
    for (var i = 0; i < 8; i += 2) {
      canvas.drawRect(Rect.fromLTWH(0, i * band, size.width, band), stripe);
    }

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final inset = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    canvas.drawRRect(RRect.fromRectAndRadius(inset, const Radius.circular(14)), line);
    canvas.drawLine(Offset(inset.left, size.height / 2), Offset(inset.right, size.height / 2), line);
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.14, line);
    final boxWidth = size.width * 0.46;
    final boxHeight = size.height * 0.12;
    canvas.drawRect(Rect.fromLTWH((size.width - boxWidth) / 2, inset.top, boxWidth, boxHeight), line);
    canvas.drawRect(Rect.fromLTWH((size.width - boxWidth) / 2, inset.bottom - boxHeight, boxWidth, boxHeight), line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── You score when they beat the market ───────────────────────────────────────

/// Two lines drawn across a chart: the S&P 500, and a pick pulling ahead of
/// it. The gap between them fills in as the points count up.
class BeatMarketIllustration extends StatelessWidget {
  const BeatMarketIllustration({super.key});

  /// Points the illustration counts up to.
  static const _points = 42;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.15,
      child: _PlayOnce(
        duration: const Duration(milliseconds: 2000),
        builder: (context, t) {
          final draw = _phase(t, 0, 0.75);
          final points = (_points * _phase(t, 0.3, 1)).round();
          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              children: [
                const Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    _Legend(color: AppColors.primary, label: 'Your pick'),
                    _Legend(color: AppColors.textMuted, label: 'S&P 500'),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: CustomPaint(painter: _ChartPainter(draw))),
                      // Top left, where the chart is empty: the lines finish top right.
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Opacity(
                          opacity: _phase(t, 0.25, 0.45),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '+$points pts',
                              style: AppTextStyles.mono(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textInverse,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 3, color: color),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.progress);

  /// How much of the chart is drawn, 0..1 from left to right.
  final double progress;

  static const _steps = 48;

  /// Both lines as heights from 0 (bottom) to 1 (top), over x from 0 to 1.
  static double _market(double x) => 0.14 + 0.12 * x + 0.03 * math.sin(x * 11);
  static double _pick(double x) => _market(x) + 0.4 * math.pow(x, 1.5) + 0.015 * math.sin(x * 13);

  @override
  void paint(Canvas canvas, Size size) {
    Offset at(double x, double y) => Offset(x * size.width, (1 - y) * size.height);

    final grid = Paint()
      ..color = AppColors.border.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (progress <= 0) return;

    final count = math.max(1, (_steps * progress).round());
    final xs = [for (var i = 0; i <= count; i++) i / count * progress];

    // The lead: the area between the pick and the market.
    final gap = Path()..moveTo(at(0, _market(0)).dx, at(0, _market(0)).dy);
    for (final x in xs) {
      final p = at(x, _pick(x));
      gap.lineTo(p.dx, p.dy);
    }
    for (final x in xs.reversed) {
      final m = at(x, _market(x));
      gap.lineTo(m.dx, m.dy);
    }
    gap.close();
    canvas.drawPath(
      gap,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary.withValues(alpha: 0.35), AppColors.primary.withValues(alpha: 0.05)],
        ).createShader(Offset.zero & size),
    );

    Path line(double Function(double) f) {
      final path = Path();
      for (final (i, x) in xs.indexed) {
        final p = at(x, f(x));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      return path;
    }

    canvas.drawPath(
      line(_market),
      Paint()
        ..color = AppColors.textMuted
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      line(_pick),
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // A dot riding the head of the pick's line.
    final head = at(xs.last, _pick(xs.last));
    canvas.drawCircle(head, 9, Paint()..color = AppColors.primary.withValues(alpha: 0.25));
    canvas.drawCircle(head, 4.5, Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) => oldDelegate.progress != progress;
}
