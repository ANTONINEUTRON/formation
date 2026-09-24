import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/utils/format.dart';
import 'package:symbians/features/shared/domain/models.dart';
import 'package:symbians/features/shared/ui/widgets/armband_badge.dart';

/// One row of the team: position, stock, holding, and how it is scoring.
class RosterSlotCard extends StatelessWidget {
  const RosterSlotCard({
    required this.slot,
    required this.teamValueUsd,
    this.score,
    this.armband,
    super.key,
  });

  final RosterSlot slot;
  final double teamValueUsd;

  /// This pick's gameweek score, when the team is entered.
  final SlotScore? score;

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
                        'Empty · ${tier?.label ?? 'Any tier'}',
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
          if (score != null && (score.events.isNotEmpty || score.multiplier > 1)) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (score.multiplier > 1)
                    _EventChip(
                      label: '${formatPoints(score.multiplier)}× captain',
                      color: const Color(0xFFFACC15),
                    ),
                  for (final event in score.events)
                    _EventChip(
                      label: '${event.label} ${formatSignedPoints(event.points)}',
                      color: pnlColor(event.points),
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
  const _EventChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTextStyles.mono(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
