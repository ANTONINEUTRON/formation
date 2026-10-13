import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/shared/ui/widgets/armband_badge.dart';
import 'package:formation/features/shared/ui/widgets/not_scoring_badge.dart';

/// One row of the team: position, stock, holding, and how it is scoring.
class RosterSlotCard extends StatelessWidget {
  const RosterSlotCard({
    required this.slot,
    required this.teamValueUsd,
    this.score,
    this.live = const [],
    this.armband,
    super.key,
  });

  final RosterSlot slot;
  final double teamValueUsd;

  /// This pick's session score, when the team is being scored.
  final SlotScore? score;

  /// Today's role events as they happen: provisional until the daily rollup.
  final List<LiveEvent> live;

  /// 'C' or 'V' badge, if any.
  final String? armband;

  @override
  Widget build(BuildContext context) {
    final stock = slot.stock;
    final tier = slot.position.requiredTier;
    final tierColor = stock?.tier.color ?? tier?.color ?? AppColors.textMuted;
    final score = this.score;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  slot.position.label,
                  style: AppTextStyles.mono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tierColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: stock == null
                    ? Text(
                        'Empty · ${tier == null ? 'Any tier' : slot.position.tierLabel}',
                        style: const TextStyle(color: AppColors.textMuted),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(stock.symbol,
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              if (armband != null) ...[
                                const SizedBox(width: 6),
                                ArmbandBadge(label: armband!, size: 16),
                              ],
                            ],
                          ),
                          Text(
                            '${formatShares(slot.balance)} sh · ${formatUsd(slot.valueUsd)}'
                            '${teamValueUsd <= 0 ? '' : ' · ${formatPct(slot.valueUsd / teamValueUsd, signed: false, decimals: 0)} of team'}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          if ((score?.notScoring ?? stock.notScoring) != null) ...[
                            const SizedBox(height: 4),
                            NotScoringBadge(reason: (score?.notScoring ?? stock.notScoring)!),
                          ] else if (score?.held ?? false) ...[
                            const SizedBox(height: 4),
                            const Tooltip(
                              message: 'Its price jumped more than 10% against the market. '
                                  'Nothing banks until the next tick confirms the move.',
                              child: Text(
                                'Big move: checking next tick',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              if (score != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatSignedPoints(score.total),
                      style: AppTextStyles.mono(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: pnlColor(score.total),
                      ),
                    ),
                    Text(
                      score.counted ? formatPct(score.ownReturn) : 'not held',
                      style: AppTextStyles.mono(
                        fontSize: 11,
                        color: score.counted ? pnlColor(score.ownReturn) : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if ((score != null && (score.events.isNotEmpty || score.multiplier > 1)) || live.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (score != null && score.multiplier > 1)
                    _EventChip(
                      label: '${formatPoints(score.multiplier)}× captain',
                      color: const Color(0xFFFACC15),
                    ),
                  for (final event in score?.events ?? const <ScoreEvent>[])
                    _EventChip(
                      label: '${event.label} ${formatSignedPoints(event.points)}',
                      color: pnlColor(event.points),
                    ),
                  // Live: dotted while provisional, struck through if disallowed.
                  for (final event in live)
                    _EventChip(
                      label: event.isDisallowed
                          ? '${event.label} · disallowed'
                          : '${event.label} ${formatSignedPoints(event.points)} · live',
                      color: event.isDisallowed ? AppColors.textMuted : pnlColor(event.points),
                      provisional: event.isProvisional,
                      struck: event.isDisallowed,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EventChip extends StatelessWidget {
  const _EventChip({
    required this.label,
    required this.color,
    this.provisional = false,
    this.struck = false,
  });

  final String label;
  final Color color;

  /// Not banked yet: drawn with a dotted outline.
  final bool provisional;

  /// Disallowed: the price fell back.
  final bool struck;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: AppTextStyles.mono(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
      ).copyWith(decoration: struck ? TextDecoration.lineThrough : null),
    );
    if (provisional) {
      return CustomPaint(
        painter: _DottedOutline(color: color.withValues(alpha: 0.8)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: text,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: text,
    );
  }
}

class _DottedOutline extends CustomPainter {
  _DottedOutline({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6)));
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 5) {
        canvas.drawPath(metric.extractPath(d, d + 2.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DottedOutline old) => old.color != color;
}
