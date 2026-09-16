import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:symbians/core/extensions/context_extensions.dart';
import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/features/shared/domain/models.dart';

/// Grid of earned trophies; tapping one opens its transaction in an explorer.
class TrophyCase extends StatelessWidget {
  const TrophyCase({required this.trophies, super.key});

  final List<Trophy> trophies;

  Future<void> _open(BuildContext context, Trophy trophy) async {
    final sig = trophy.txSignature;
    if (sig == null) {
      context.showInfoToast(message: 'This trophy has not been recorded on-chain yet.');
      return;
    }
    await launchUrl(Uri.parse('https://explorer.solana.com/tx/$sig'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (trophies.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Win a duel to earn your first trophy.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.85,
      children: [
        for (final t in trophies)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _open(context, t),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFACC15).withValues(alpha: 0.35)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events, color: Color(0xFFFACC15), size: 32),
                  const SizedBox(height: 6),
                  Text(
                    t.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(t.mode.icon, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Icon(
                        t.txSignature == null ? Icons.schedule : Icons.verified,
                        size: 12,
                        color: t.txSignature == null ? AppColors.textMuted : AppColors.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
