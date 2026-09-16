import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/utils/format.dart';
import 'package:symbians/features/shared/domain/models.dart';
import 'package:symbians/features/shared/ui/widgets/armband_badge.dart';

/// One row of the lineup: position, stock, holding and share of team value.
class RosterSlotCard extends StatelessWidget {
  const RosterSlotCard({
    required this.slot,
    required this.teamValueUsd,
    this.armband,
    this.isSubstitute = false,
    super.key,
  });

  final RosterSlot slot;
  final double teamValueUsd;

  /// 'C' or 'V' badge, if any.
  final String? armband;

  /// Football substitutes are shown dimmed; they only score when auto-subbed.
  final bool isSubstitute;

  @override
  Widget build(BuildContext context) {
    final stock = slot.stock;
    final tier = slot.position.requiredTier;
    final tierColor = stock?.tier.color ?? tier?.color ?? AppColors.textMuted;

    return Opacity(
      opacity: isSubstitute ? 0.65 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
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
                style: AppTextStyles.mono(fontSize: 12, fontWeight: FontWeight.w700, color: tierColor),
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
                            Text(stock.symbol, style: const TextStyle(fontWeight: FontWeight.w700)),
                            if (armband != null) ...[
                              const SizedBox(width: 6),
                              ArmbandBadge(label: armband!, size: 16),
                            ],
                          ],
                        ),
                        Text(
                          '${stock.companyName} · ${formatShares(slot.balance)} sh',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
            ),
            if (stock != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatUsd(slot.valueUsd), style: AppTextStyles.mono(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(
                    teamValueUsd <= 0 ? '' : '${formatPct(slot.valueUsd / teamValueUsd, signed: false, decimals: 0)} of team',
                    style: AppTextStyles.mono(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
