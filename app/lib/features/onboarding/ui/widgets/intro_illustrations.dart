import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/draft/ui/widgets/formation_board.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/shared/domain/roster_shapes.dart';

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

/// The team screen's own board, drafting itself: each sport in turn, its
/// positions filling with stocks in their jerseys and tier colours, then on
/// to the next sport. With animations off it shows a full football team.
class LineupIllustration extends StatefulWidget {
  const LineupIllustration({super.key});

  @override
  State<LineupIllustration> createState() => _LineupIllustrationState();
}

class _LineupIllustrationState extends State<LineupIllustration> with SingleTickerProviderStateMixin {
  /// Time on each sport: drafting, a pause on the full team, a fade.
  static const _perSport = Duration(milliseconds: 3600);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _perSport * SportMode.values.length,
  );

  // Example picks by tier, in the order they're drafted.
  static const _demo = {
    RiskTier.blueChip: ['BRK.Bx', 'KOx', 'JNJx', 'PGx', 'WMTx', 'MCDx', 'AAPLx'],
    RiskTier.balanced: ['MSFTx', 'AMZNx', 'METAx', 'GOOGLx', 'Vx'],
    RiskTier.momentum: ['TSLAx', 'NVDAx', 'PLTRx', 'COINx', 'AMDx'],
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
      _controller.value = 0.2; // football, every position filled
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// [mode]'s team with its first [filled] positions drafted.
  static Roster _team(SportMode mode, int filled) {
    final empty = emptyRoster(mode);
    final used = <RiskTier, int>{};
    return Roster(
      mode: mode,
      formation: empty.formation,
      captainSlot: mode == SportMode.americanFootball || filled == 0 ? null : 0,
      slots: [
        for (final (i, slot) in empty.slots.indexed)
          if (i >= filled)
            slot
          else
            () {
              // FLEX takes any tier; it gets a balanced pick.
              final tier = slot.position.requiredTier ?? RiskTier.balanced;
              final n = used[tier] = (used[tier] ?? -1) + 1;
              final symbol = _demo[tier]![n % _demo[tier]!.length];
              return slot.fill(
                XStock(symbol: symbol, companyName: symbol, mint: 'demo-$symbol', tier: tier, priceUsd: 0),
                1,
              );
            }(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final sports = SportMode.values.length;
        final at = _controller.value * sports;
        final mode = SportMode.values[at.floor().clamp(0, sports - 1)];
        final t = at - at.floor(); // 0..1 through this sport
        final size = rosterShape(mode).length;
        // Draft over the first 60%, hold, then fade out over the last 10%.
        final filled = (size * _phase(t, 0.05, 0.6) + 0.001).floor().clamp(0, size);
        final opacity = math.min(_phase(t, 0, 0.06), 1 - _phase(t, 0.9, 1));

        return Column(
          children: [
            _SportTabs(selected: mode),
            const SizedBox(height: 12),
            Expanded(
              child: Opacity(
                opacity: opacity,
                // A new board per sport, so players start in place rather
                // than sliding over from the last sport's positions.
                child: Center(
                  child: FormationBoard(key: ValueKey(mode), roster: _team(mode, filled)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The three sports, the one being shown lit.
class _SportTabs extends StatelessWidget {
  const _SportTabs({required this.selected});

  final SportMode selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final mode in SportMode.values)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: mode == selected ? AppColors.primary.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: mode == selected ? AppColors.primary : AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(mode.icon, size: 14, color: mode == selected ? AppColors.primary : AppColors.textMuted),
                if (mode == selected) ...[
                  const SizedBox(width: 6),
                  Text(
                    mode.label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
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
      aspectRatio: 0.9,
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
