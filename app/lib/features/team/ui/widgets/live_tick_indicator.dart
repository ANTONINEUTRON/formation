import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/utils/format.dart';

/// "Next tick in 42:13", counting down to the top of the hour.
class LiveTickIndicator extends StatefulWidget {
  const LiveTickIndicator({this.onRunTick, this.isTicking = false, super.key});

  /// Shown as a debug "Run tick" button when non-null.
  final VoidCallback? onRunTick;
  final bool isTicking;

  @override
  State<LiveTickIndicator> createState() => _LiveTickIndicatorState();
}

class _LiveTickIndicatorState extends State<LiveTickIndicator> {
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

  Duration get _untilNextTick {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day, now.hour + 1);
    return next.difference(now);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fade(begin: 0.3, end: 1, duration: 900.ms),
        const SizedBox(width: 8),
        const Text('LIVE', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: AppColors.success)),
        const SizedBox(width: 12),
        Text(
          'Next tick in ${formatCountdown(_untilNextTick).substring(3)}',
          style: AppTextStyles.mono(fontSize: 12, color: AppColors.textSecondary),
        ),
        const Spacer(),
        if (widget.onRunTick != null)
          TextButton.icon(
            onPressed: widget.isTicking ? null : widget.onRunTick,
            icon: widget.isTicking
                ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.bolt, size: 16),
            label: const Text('Run tick'),
          ),
      ],
    );
  }
}
