import 'dart:async';

import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/utils/format.dart';

/// Live countdown to a duel's end time.
class DuelCountdown extends StatefulWidget {
  const DuelCountdown({required this.endTime, this.fontSize = 13, super.key});

  final DateTime endTime;
  final double fontSize;

  @override
  State<DuelCountdown> createState() => _DuelCountdownState();
}

class _DuelCountdownState extends State<DuelCountdown> {
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
    final remaining = widget.endTime.difference(DateTime.now());
    return Text(
      remaining.isNegative ? 'Settling…' : formatCountdown(remaining),
      style: AppTextStyles.mono(
        fontSize: widget.fontSize,
        fontWeight: FontWeight.w600,
        color: AppColors.warning,
      ),
    );
  }
}
