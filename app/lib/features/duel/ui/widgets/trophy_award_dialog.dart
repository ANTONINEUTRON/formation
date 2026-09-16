import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/utils/format.dart';
import 'package:symbians/features/shared/domain/models.dart';

/// The win moment after a duel settles in the user's favour.
class TrophyAwardDialog extends StatelessWidget {
  const TrophyAwardDialog({required this.duel, super.key});

  final Duel duel;

  static Future<void> show(BuildContext context, Duel duel) => showDialog<void>(
        context: context,
        builder: (_) => TrophyAwardDialog(duel: duel),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 96, color: Color(0xFFFACC15))
                .animate()
                .scale(begin: const Offset(0.2, 0.2), duration: 600.ms, curve: Curves.elasticOut)
                .then()
                .shimmer(duration: 1200.ms, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              'You won!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 8),
            Text(
              'Your ${duel.mode.label} team beat ${duel.rival.username}\n'
              '${formatPct(duel.myReturnPct ?? 0)} vs ${formatPct(duel.rivalReturnPct ?? 0)}',
              textAlign: TextAlign.center,
              style: AppTextStyles.mono(fontSize: 13, color: AppColors.textSecondary),
            ).animate().fadeIn(delay: 450.ms),
            const SizedBox(height: 12),
            const Text(
              'A trophy has been recorded to your wallet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Nice'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
