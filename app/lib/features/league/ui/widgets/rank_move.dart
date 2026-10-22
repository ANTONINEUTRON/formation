import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/league/ui/cubits/league_state.dart';

/// One leaderboard row plus the gap after it, for working out where a row was.
const leaderboardRowExtent = 70.0;

/// Furthest a row is drawn from, in rows, so a jump of fifty places still
/// starts on screen and reads as a climb rather than a teleport.
const _maxRowsTravelled = 6;

const _slide = Duration(milliseconds: 750);
const _glow = Duration(milliseconds: 1800);

Color rankMoveColor(RankMove move) => move.isUp ? AppColors.primary : AppColors.warning;

String rankMoveLabel(RankMove move) => '${move.isUp ? '▲' : '▼'}${move.places.abs()}';

/// How far the row starts from where it ends up, in pixels.
double rankMoveOffset(RankMove move) =>
    move.places.clamp(-_maxRowsTravelled, _maxRowsTravelled) * leaderboardRowExtent;

/// The user's own row after their rank changed: it slides from its old place
/// to the new one, glows lime going up or amber going down, and briefly shows
/// how many places it moved.
class MovedRow extends StatefulWidget {
  const MovedRow({required this.move, required this.child, super.key});

  final RankMove move;
  final Widget child;

  @override
  State<MovedRow> createState() => _MovedRowState();
}

class _MovedRowState extends State<MovedRow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: _glow)..forward();

  late final Animation<double> _travel = CurvedAnimation(
    parent: _controller,
    curve: Interval(0, _slide.inMilliseconds / _glow.inMilliseconds, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = rankMoveColor(widget.move);
    final offset = rankMoveOffset(widget.move);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Glow rises while the row travels, then fades away.
        final t = _controller.value;
        final glow = t < 0.4 ? t / 0.4 : 1 - (t - 0.4) / 0.6;
        return Transform.translate(
          offset: Offset(0, offset * (1 - _travel.value)),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.55 * glow), blurRadius: 18, spreadRadius: 1),
                  ],
                ),
                child: child,
              ),
              Positioned(
                right: 10,
                top: -10,
                child: Opacity(
                  opacity: glow.clamp(0, 1),
                  child: _MoveChip(move: widget.move),
                ),
              ),
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// "▲3" in lime, or "▼1" in amber.
class _MoveChip extends StatelessWidget {
  const _MoveChip({required this.move});

  final RankMove move;

  @override
  Widget build(BuildContext context) {
    final color = rankMoveColor(move);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(
        rankMoveLabel(move),
        style: AppTextStyles.mono(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textInverse),
      ),
    );
  }
}

/// A row the user passed (or that passed them): it shifts one place the
/// opposite way, in step with the user's row.
class ShiftedRow extends StatelessWidget {
  const ShiftedRow({required this.move, required this.child, super.key});

  final RankMove move;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: _slide,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Transform.translate(
        // Moving up pushed them down a place, so they arrive from above.
        offset: Offset(0, (move.isUp ? -1 : 1) * leaderboardRowExtent * t),
        child: child,
      ),
      child: child,
    );
  }
}

/// The rank number in the banner, counting from the old rank to the new one.
class CountingRank extends StatelessWidget {
  const CountingRank({required this.rank, required this.style, this.move, super.key});

  final int rank;
  final RankMove? move;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final move = this.move;
    if (move == null) return Text('#$rank', style: style);
    return TweenAnimationBuilder<double>(
      key: ValueKey(move.serial),
      tween: Tween(begin: move.from.toDouble(), end: move.to.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Text('#${value.round()}', style: style),
    );
  }
}

/// The banner's chip: how far the user moved, fading after a few seconds.
class RankMoveBadge extends StatelessWidget {
  const RankMoveBadge({required this.move, super.key});

  final RankMove move;

  @override
  Widget build(BuildContext context) {
    final color = rankMoveColor(move);
    return TweenAnimationBuilder<double>(
      key: ValueKey(move.serial),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 4000),
      builder: (context, t, child) {
        // Pops in, holds, then fades.
        final opacity = t < 0.1 ? t / 0.1 : (t > 0.75 ? (1 - t) / 0.25 : 1.0);
        final scale = t < 0.1 ? 0.6 + 0.4 * (t / 0.1) : 1.0;
        return Opacity(opacity: opacity, child: Transform.scale(scale: scale, child: child));
      },
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${rankMoveLabel(move)} ${move.places.abs() == 1 ? 'place' : 'places'}',
          style: AppTextStyles.mono(fontSize: 12, fontWeight: FontWeight.w700, color: color),
        ),
      ),
    );
  }
}
