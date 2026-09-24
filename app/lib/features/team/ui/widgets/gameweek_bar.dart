import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/utils/format.dart';
import 'package:symbians/features/shared/domain/models.dart';

/// Live countdown to the end of the gameweek, plus the debug scoring controls.
class GameweekBar extends StatefulWidget {
  const GameweekBar({
    required this.gameweek,
    this.onRunTick,
    this.onAdvance,
    this.isBusy = false,
    super.key,
  });

  final Gameweek? gameweek;

  /// Debug only: record prices now and rescore.
  final VoidCallback? onRunTick;

  /// Debug only: close this gameweek and open the next.
  final VoidCallback? onAdvance;
  final bool isBusy;

  @override
  State<GameweekBar> createState() => _GameweekBarState();
}

class _GameweekBarState extends State<GameweekBar> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameweek = widget.gameweek;

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: gameweek?.isLive ?? false ? AppColors.success : AppColors.textMuted,
            shape: BoxShape.circle,
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fade(begin: 0.3, end: 1, duration: 900.ms),
        const SizedBox(width: 8),
        Text(
          gameweek == null ? 'NO GAMEWEEK' : 'LIVE',
          style: const TextStyle(fontSize: 11, letterSpacing: 1.2, color: AppColors.success),
        ),
        const SizedBox(width: 12),
        if (gameweek != null)
          Expanded(
            child: Text(
              'Ends in ${formatCountdown(gameweek.remaining)}',
              style: AppTextStyles.mono(fontSize: 12, color: AppColors.textSecondary),
            ),
          )
        else
          const Spacer(),
        if (widget.onRunTick != null)
          TextButton.icon(
            onPressed: widget.isBusy ? null : widget.onRunTick,
            icon: widget.isBusy
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bolt, size: 16),
            label: const Text('Tick'),
          ),
        if (widget.onAdvance != null)
          TextButton.icon(
            onPressed: widget.isBusy ? null : widget.onAdvance,
            icon: const Icon(Icons.skip_next, size: 16),
            label: const Text('Next GW'),
          ),
      ],
    );
  }
}
