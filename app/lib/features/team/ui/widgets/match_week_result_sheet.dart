import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:formation/features/assistant_manager/domain/assistant_models.dart';
import 'package:formation/features/assistant_manager/ui/cubits/assistant_cubit.dart';
import 'package:formation/features/assistant_manager/ui/widgets/character_view.dart';

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
  const MatchWeekResultSheet({required this.result, required this.mode, this.health, this.character, super.key});

  final MatchWeekResult result;
  final SportMode mode;

  /// The Assistant Manager's portfolio health card; null if it didn't load.
  final PortfolioHealth? health;

  /// Who delivers the health card.
  final AssistantCharacter? character;

  static Future<void> show(
    BuildContext context, {
    required FormationRepository repository,
    required SportMode mode,
  }) {
    final future = repository.getMatchWeekResult(mode);
    // The health card is a bonus: the result shows even if it fails.
    final health = repository.getPortfolioHealth(mode).then<PortfolioHealth?>((h) => h, onError: (_) => null);
    AssistantCharacter? character;
    try {
      character = context.read<AssistantCubit>().state.profile?.character;
    } on ProviderNotFoundException {
      character = null;
    }
    return showAdaptiveSheet<void>(
      context: context,
      builder: (_) => FutureBuilder<(MatchWeekResult, PortfolioHealth?)>(
        future: Future.wait([future, health]).then((r) => (r[0]! as MatchWeekResult, r[1] as PortfolioHealth?)),
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
          final (result, card) = snapshot.data!;
          return MatchWeekResultSheet(result: result, mode: mode, health: card, character: character);
        },
      ),
    );
  }

  String get _shareText {
    final week = result.week;
    final rank = result.rank == null ? '' : ', #${result.rank} of ${result.players}';
    final motm = result.manOfTheMatch == null ? '' : '. Man of the match: ${result.manOfTheMatch!.symbol}';
    return '${week.label} on Formation (${mode.label}): '
        '${formatSignedPoints(result.points)}$rank$motm. Beat the market, balance your team, stay consistent.';
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
                      Icon(mode.icon, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          goal.provisional
                              ? '${goal.symbol} · ${goal.label} (provisional)'
                              : '${goal.symbol} · ${goal.label}',
                          style: TextStyle(
                            fontStyle: goal.provisional ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ),
                      Text(
                        formatSignedPoints(goal.points),
                        style: AppTextStyles.mono(fontSize: 12, color: AppColors.success),
                      ),
                    ],
                  ),
                ),
            if (health != null) ...[
              const SizedBox(height: 20),
              _HealthCard(health: health!, character: character ?? presetCharacters.first),
            ],
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

/// "Your Assistant Manager's take": tier balance, sector concentration, who
/// carried and who dragged, and what that teaches. Beat the market, balance
/// your team, stay consistent.
class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.health, required this.character});

  final PortfolioHealth health;
  final AssistantCharacter character;

  static const _sectorColors = [
    Color(0xFFB8FF3C),
    Color(0xFF38BDF8),
    Color(0xFFF59E0B),
    Color(0xFFA78BFA),
    Color(0xFFF472B6),
    Color(0xFF34D399),
  ];

  @override
  Widget build(BuildContext context) {
    final pose = health.points < 0
        ? AssistantPose.concerned
        : health.isBalanced
            ? AssistantPose.celebrating
            : AssistantPose.thinking;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CharacterHead(character: character, pose: pose, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${character.name}'s take",
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Text(
                      'Portfolio health this week',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (health.isBalanced ? AppColors.primary : AppColors.textMuted).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  health.balanceEarned
                      ? 'Balance +${health.balanceBonus}'
                      : '${health.balanceSectors}/${health.balanceNeeded} sectors',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: health.isBalanced ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (health.sectors.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  for (final (i, s) in health.sectors.indexed)
                    Expanded(
                      flex: s.sharePct.clamp(1, 100),
                      child: Container(height: 8, color: _sectorColors[i % _sectorColors.length]),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                for (final (i, s) in health.sectors.indexed)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _sectorColors[i % _sectorColors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('${s.label} ${s.sharePct}%', style: const TextStyle(fontSize: 11)),
                    ],
                  ),
              ],
            ),
          ],
          if (health.tiers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tier in RiskTier.values)
                  if (health.tiers[tier.apiValue] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tier.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${tier.label} ×${health.tiers[tier.apiValue]}',
                        style: TextStyle(fontSize: 10, color: tier.color),
                      ),
                    ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          for (final lesson in health.lessons)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.lightbulb_outline, size: 14, color: AppColors.warning),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(lesson, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
        ],
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
