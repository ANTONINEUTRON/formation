import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:symbians/features/draft/ui/widgets/position_slot_chip.dart';
import 'package:symbians/features/shared/domain/models.dart';
import 'package:symbians/features/shared/domain/roster_shapes.dart';

/// The court / pitch / field with each on-board slot placed on it.
///
/// Positions come from [boardLayout]: fixed per sport, or by formation for
/// football (substitutes are shown separately in a bench strip).
class FormationBoard extends StatelessWidget {
  const FormationBoard({required this.roster, required this.onSlotTap, super.key});

  final Roster roster;
  final ValueChanged<int> onSlotTap;

  double get _aspectRatio => switch (roster.mode) {
        SportMode.basketball => 0.95,
        SportMode.football => 0.68,
        SportMode.americanFootball => 0.62,
      };

  @override
  Widget build(BuildContext context) {
    final layout = boardLayout(roster);
    final onBoard = [for (var i = 0; i < layout.length; i++) if (layout[i] != null) i];

    return AspectRatio(
      aspectRatio: _aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final chip = math.min(56.0, w / (onBoard.length > 5 ? 6.2 : 4.5));
          const labelHeight = 16.0;

          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _BoardPainter(roster.mode))),
                for (final i in onBoard)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    left: (layout[i]!.dx * w - chip / 2).clamp(0, w - chip),
                    top: (layout[i]!.dy * h - chip / 2).clamp(0, h - chip - labelHeight),
                    width: chip,
                    child: PositionSlotChip(
                      slot: roster.slots[i],
                      size: chip,
                      onTap: () => onSlotTap(i),
                      armband: roster.armband(i),
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

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.mode);

  final SportMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    switch (mode) {
      case SportMode.basketball:
        _court(canvas, size, rect, line);
      case SportMode.football:
        _pitch(canvas, size, rect, line);
      case SportMode.americanFootball:
        _field(canvas, size, rect, line);
    }
    canvas.drawRect(rect.deflate(6), line);
  }

  void _court(Canvas canvas, Size s, Rect rect, Paint line) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A2A18), Color(0xFF24190E)],
        ).createShader(rect),
    );
    final hoop = Offset(s.width / 2, s.height * 0.08);
    // Paint (key) and free-throw circle.
    final keyW = s.width * 0.32;
    final keyH = s.height * 0.38;
    canvas.drawRect(Rect.fromLTWH(hoop.dx - keyW / 2, 6, keyW, keyH), line);
    canvas.drawCircle(Offset(hoop.dx, 6 + keyH), keyW / 2, line);
    canvas.drawCircle(hoop, 8, line);
    // Three-point arc.
    canvas.drawArc(Rect.fromCircle(center: hoop, radius: s.width * 0.44), 0, math.pi, false, line);
    // Half-court circle at the bottom edge.
    canvas.drawCircle(Offset(hoop.dx, s.height - 6), s.width * 0.14, line);
  }

  void _pitch(Canvas canvas, Size s, Rect rect, Paint line) {
    const stripes = 10;
    for (var i = 0; i < stripes; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, s.height * i / stripes, s.width, s.height / stripes),
        Paint()..color = i.isEven ? const Color(0xFF123524) : const Color(0xFF0F2D1F),
      );
    }
    final mid = s.height / 2;
    canvas.drawLine(Offset(6, mid), Offset(s.width - 6, mid), line);
    canvas.drawCircle(Offset(s.width / 2, mid), s.width * 0.14, line);
    for (final top in [true, false]) {
      final boxW = s.width * 0.6;
      final boxH = s.height * 0.15;
      final goalW = s.width * 0.3;
      final goalH = s.height * 0.06;
      final y = top ? 6.0 : s.height - 6;
      final dir = top ? 1 : -1;
      canvas.drawRect(Rect.fromPoints(Offset((s.width - boxW) / 2, y), Offset((s.width + boxW) / 2, y + dir * boxH)), line);
      canvas.drawRect(Rect.fromPoints(Offset((s.width - goalW) / 2, y), Offset((s.width + goalW) / 2, y + dir * goalH)), line);
    }
  }

  void _field(Canvas canvas, Size s, Rect rect, Paint line) {
    canvas.drawRect(rect, Paint()..color = const Color(0xFF14331F));
    final endZone = s.height * 0.08;
    final zonePaint = Paint()..color = const Color(0xFF7C3AED).withValues(alpha: 0.25);
    canvas.drawRect(Rect.fromLTWH(0, 0, s.width, endZone), zonePaint);
    canvas.drawRect(Rect.fromLTWH(0, s.height - endZone, s.width, endZone), zonePaint);
    final playable = s.height - 2 * endZone;
    for (var i = 0; i <= 10; i++) {
      final y = endZone + playable * i / 10;
      canvas.drawLine(Offset(6, y), Offset(s.width - 6, y), line);
      for (final x in [s.width * 0.38, s.width * 0.62]) {
        for (var j = 1; j < 5; j++) {
          final hy = y + playable / 50 * j;
          if (i < 10) canvas.drawLine(Offset(x - 4, hy), Offset(x + 4, hy), line);
        }
      }
    }
    // Line of scrimmage.
    final scrimmage = s.height * 0.5;
    canvas.drawLine(
      Offset(6, scrimmage),
      Offset(s.width - 6, scrimmage),
      Paint()
        ..color = const Color(0xFF3B82F6).withValues(alpha: 0.7)
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_BoardPainter oldDelegate) => oldDelegate.mode != mode;
}
