import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/features/shared/domain/models.dart';

/// Today's session: points bank continuously, so this shows what has already
/// landed rather than a countdown to a window closing.
class SessionBar extends StatelessWidget {
  const SessionBar({
    required this.session,
    this.onRunTick,
    this.isBusy = false,
    super.key,
  });

  final Session? session;

  /// Debug builds only: forces a price tick so points move on demand.
  final VoidCallback? onRunTick;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final session = this.session;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session == null
                      ? 'Scoring starts when your team is complete'
                      : 'Banked today: ${formatSignedPoints(session.points)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (session != null)
                  Text(
                    session.freeSubstitutionsLeft > 0
                        ? '${session.freeSubstitutionsLeft} free subs left today'
                        : 'Further subs cost 4 points each',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          if (onRunTick != null)
            TextButton(
              onPressed: isBusy ? null : onRunTick,
              child: Text(isBusy ? 'Ticking…' : 'Tick'),
            ),
        ],
      ),
    );
  }
}
