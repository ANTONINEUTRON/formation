import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/features/shared/domain/models.dart';

/// The match week and today's session. Points bank continuously, so this shows
/// what has already landed rather than a countdown to a window closing; the
/// match week frames it, and the weekend transfer window makes substitutions
/// free.
class SessionBar extends StatelessWidget {
  const SessionBar({
    required this.session,
    this.onRunTick,
    this.onOpenResult,
    this.isBusy = false,
    super.key,
  });

  final Session? session;

  /// Debug builds only: forces a price tick so points move on demand.
  final VoidCallback? onRunTick;

  /// Opens the match week result card.
  final VoidCallback? onOpenResult;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final session = this.session;
    final week = session?.matchWeek;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: week == null ? null : onOpenResult,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: session?.transferWindowOpen ?? false
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                session?.transferWindowOpen ?? false ? Icons.swap_horiz : Icons.bolt,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (week != null)
                      Text(
                        '${week.label} · ${formatSignedPoints(week.points)} this week',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    Text(
                      session == null
                          ? 'Scoring starts when your team is complete'
                          : 'Banked today: ${formatSignedPoints(session.points)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (session != null)
                      Text(
                        session.transferWindowOpen
                            ? 'Transfer window open: substitutions are free until Monday 9:30am ET'
                            : session.freeSubstitutionsLeft > 0
                                ? '${session.freeSubstitutionsLeft} free subs left today'
                                : 'Further subs cost 4 points each',
                        style: TextStyle(
                          fontSize: 11,
                          color: session.transferWindowOpen ? AppColors.primary : AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (onRunTick != null)
                TextButton(
                  onPressed: isBusy ? null : onRunTick,
                  child: Text(isBusy ? 'Ticking…' : 'Tick'),
                )
              else if (week != null && onOpenResult != null)
                const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
