import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/features/duel/ui/widgets/duel_countdown.dart';
import 'package:symbians/features/duel/ui/widgets/head_to_head_bar.dart';
import 'package:symbians/features/shared/domain/models.dart';

class DuelCard extends StatelessWidget {
  const DuelCard({
    required this.duel,
    required this.onTap,
    this.onAccept,
    this.onDecline,
    this.isBusy = false,
    super.key,
  });

  final Duel duel;
  final VoidCallback onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final invite = duel.awaitingMyResponse;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: invite ? AppColors.warning : AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sports_mma, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'vs ${duel.rival.username}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _Tag(text: formatDuelDuration(duel.duration), color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  _statusTag(),
                ],
              ),
              if (duel.status == DuelStatus.active) ...[
                const SizedBox(height: 12),
                HeadToHeadBar(
                  myReturnPct: duel.myReturnPct ?? 0,
                  rivalReturnPct: duel.rivalReturnPct ?? 0,
                  myLabel: 'You',
                  rivalLabel: duel.rival.username,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Ends in ', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    if (duel.endTime != null) DuelCountdown(endTime: duel.endTime!, fontSize: 12),
                  ],
                ),
              ],
              if (invite) ...[
                const SizedBox(height: 10),
                Text(
                  '${duel.challenger.username} challenged you to a ${formatDuelDuration(duel.duration)} duel.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isBusy ? null : onDecline,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: isBusy ? null : onAccept,
                        child: isBusy
                            ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusTag() => switch (duel.status) {
        DuelStatus.pending => _Tag(
            text: duel.awaitingMyResponse ? 'INVITE' : 'SENT',
            color: AppColors.warning,
          ),
        DuelStatus.active => const _Tag(text: 'LIVE', color: AppColors.success),
        DuelStatus.declined => const _Tag(text: 'DECLINED', color: AppColors.textMuted),
        DuelStatus.settled => duel.iWon
            ? const _Tag(text: 'WON', color: AppColors.success)
            : const _Tag(text: 'LOST', color: AppColors.error),
      };
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: AppTextStyles.mono(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
