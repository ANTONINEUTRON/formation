import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/core/widgets/stat_pill.dart';
import 'package:formation/features/shared/domain/models.dart';

/// The team's headline card: where the season is (season and match week, or
/// the pre-season), today's points front and centre, and the season total,
/// rank, team value and substitutions behind. The week's own points live on
/// the league board, and the transfer window arrives as a notification.
class ScoreHeader extends StatelessWidget {
  const ScoreHeader({
    required this.roster,
    required this.totalPlayers,
    this.onOpenResult,
    this.onRunTick,
    this.onShare,
    this.isBusy = false,
    super.key,
  });

  final Roster roster;
  final int totalPlayers;

  /// Opens the match week result card.
  final VoidCallback? onOpenResult;

  /// Debug builds only: forces a price tick so points move on demand.
  final VoidCallback? onRunTick;

  /// Shares a picture of the team; null hides the button.
  final Future<void> Function()? onShare;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final session = roster.session;
    final week = session?.matchWeek;
    final preSeason = week?.preSeason ?? false;
    final points = session?.points ?? 0;
    // There's no match week result until the season starts.
    final openResult = week == null || preSeason ? null : onOpenResult;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: openResult,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (week?.labelFor(roster.mode) ?? 'Points').toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.4,
                        color: preSeason ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (onShare != null) _ShareButton(onShare: onShare!),
                  if (onRunTick != null)
                    TextButton(
                      onPressed: isBusy ? null : onRunTick,
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      child: Text(isBusy ? 'Ticking…' : 'Tick'),
                    )
                  else if (openResult != null)
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                ],
              ),
              const SizedBox(height: 4),
              // Animates from the previous value whenever a tick lands.
              TweenAnimationBuilder<double>(
                tween: Tween(end: points),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => Text(
                  formatSignedPoints(value),
                  style: AppTextStyles.mono(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: pnlColor(points),
                  ),
                ),
              ),
              Text(
                session?.entered == false
                    // The backend enters a team on its next price tick, not instantly.
                    ? roster.holdsAny
                        ? 'Scoring starts on the next price update'
                        : 'Add a stock you own to start scoring'
                    : preSeason
                        ? "Banked today · ${roster.mode.preSeason.toLowerCase()}, doesn't count toward the season"
                        : 'Banked today',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatPill(label: 'SEASON', value: formatPoints(roster.classicPoints)),
                  StatPill(
                    label: 'RANK',
                    value: roster.classicRank == null ? '—' : '#${roster.classicRank} / $totalPlayers',
                  ),
                  StatPill(label: 'TEAM VALUE', value: formatUsd(roster.totalValueUsd)),
                  if (session != null)
                    StatPill(
                      label: 'FREE SUBS',
                      value: session.transferWindowOpen
                          ? 'Unlimited'
                          : session.freeSubstitutionsLeft > 0
                              ? '${session.freeSubstitutionsLeft} left'
                              : 'None (4 pts)',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Share my team": a spinner while the picture is made, and a quick white
/// flash, like a camera, so it's clear a picture was taken.
class _ShareButton extends StatefulWidget {
  const _ShareButton({required this.onShare});

  final Future<void> Function() onShare;

  @override
  State<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<_ShareButton> {
  var _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    _flash();
    try {
      await widget.onShare();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _flash() {
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.55, end: 0),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
          onEnd: () => entry.remove(),
          builder: (_, opacity, _) => ColoredBox(color: Colors.white.withValues(alpha: opacity)),
        ),
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Share my team',
      visualDensity: VisualDensity.compact,
      onPressed: _busy ? null : _share,
      icon: _busy
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.ios_share_rounded, size: 18, color: AppColors.textSecondary),
    );
  }
}
