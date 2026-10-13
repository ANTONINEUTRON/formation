import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/core/widgets/adaptive_sheet.dart';
import 'package:formation/core/widgets/loading_indicator.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/domain/models.dart';

/// The match week result card: the score, man of the match, the goals in
/// order and the turning point. Live until Friday full time, then final and
/// worth sharing.
class MatchWeekResultSheet extends StatelessWidget {
  const MatchWeekResultSheet({required this.result, required this.mode, super.key});

  final MatchWeekResult result;
  final SportMode mode;

  static Future<void> show(
    BuildContext context, {
    required FormationRepository repository,
    required SportMode mode,
  }) {
    final future = repository.getMatchWeekResult(mode);
    return showAdaptiveSheet<void>(
      context: context,
      builder: (_) => FutureBuilder<MatchWeekResult>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(32),
              child: Text(errorText(snapshot.error!), textAlign: TextAlign.center),
            );
          }
          if (!snapshot.hasData) {
            return const SizedBox(height: 240, child: LoadingIndicator());
          }
          return MatchWeekResultSheet(result: snapshot.data!, mode: mode);
        },
      ),
    );
  }

  String get _shareText {
    final week = result.week;
    final rank = result.rank == null ? '' : ', #${result.rank} of ${result.players}';
    final motm = result.manOfTheMatch == null ? '' : '. Man of the match: ${result.manOfTheMatch!.symbol}';
    return '${week.label} on Formation (${mode.label}): '
        '${formatSignedPoints(result.points)}$rank$motm. Beat the market, balance your team.';
  }

  @override
  Widget build(BuildContext context) {
    final week = result.week;
    final time = DateFormat('EEE HH:mm');

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    week.label.toUpperCase(),
                    style: const TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.textMuted),
                  ),
                ),
                _Pill(
                  label: result.isFinal ? 'Full time' : 'Live',
                  color: result.isFinal ? AppColors.textSecondary : AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              formatSignedPoints(result.points),
              style: AppTextStyles.mono(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: pnlColor(result.points),
              ),
            ),
            Text(
              result.rank == null
                  ? 'Nothing banked this week yet'
                  : '#${result.rank} of ${result.players} this week',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            if (result.manOfTheMatch != null)
              _Row(
                icon: Icons.star_rounded,
                color: AppColors.warning,
                title: 'Man of the match',
                value: '${result.manOfTheMatch!.symbol} · ${formatSignedPoints(result.manOfTheMatch!.points)}',
              ),
            if (result.turningPoint != null)
              _Row(
                icon: Icons.swap_vert,
                color: pnlColor(result.turningPoint!.points),
                title: 'Turning point',
                value: '${time.format(result.turningPoint!.at.toLocal())} · '
                    '${formatSignedPoints(result.turningPoint!.points)}',
              ),
            const SizedBox(height: 12),
            const Text(
              'GOALS',
              style: TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            if (result.goals.isEmpty)
              const Text('No goals yet this week.', style: TextStyle(color: AppColors.textMuted))
            else
              for (final goal in result.goals)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 84,
                        child: Text(
                          time.format(goal.at.toLocal()),
                          style: AppTextStyles.mono(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ),
                      const Icon(Icons.sports_soccer, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(child: Text('${goal.symbol} · ${goal.label}')),
                      Text(
                        formatSignedPoints(goal.points),
                        style: AppTextStyles.mono(fontSize: 12, color: AppColors.success),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => SharePlus.instance.share(ShareParams(text: _shareText)),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: Text(result.isFinal ? 'Share the result' : 'Share the score so far'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.color, required this.title, required this.value});

  final IconData icon;
  final Color color;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(color: AppColors.textSecondary))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
