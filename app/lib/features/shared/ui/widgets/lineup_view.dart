import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/features/draft/ui/widgets/formation_board.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/shared/ui/widgets/armband_badge.dart';
import 'package:formation/features/shared/ui/widgets/not_scoring_badge.dart';
import 'package:formation/features/team/ui/widgets/roster_slot_card.dart';

/// A button in the lineup's header, e.g. "Pick team".
typedef LineupAction = ({String label, IconData icon, VoidCallback onPressed});

/// The one way a team is shown: on the pitch in its jerseys by default, or as
/// a list. The Team tab, Manager profiles and the starter squad all use it;
/// the draft board is the same pitch, made editable.
class LineupView extends StatefulWidget {
  const LineupView({
    required this.roster,
    this.title,
    this.action,
    this.onSlotTap,
    this.ownTeam = false,
    this.pitchOnly = false,
    super.key,
  });

  final Roster roster;

  /// Defaults to "Starting XI" for football and "Lineup" otherwise.
  final String? title;
  final LineupAction? action;

  /// Tapping a jersey; null leaves the pitch read-only.
  final ValueChanged<int>? onSlotTap;

  /// The signed-in Manager's own team: the list shows holdings, today's score
  /// and live events, and includes empty slots to fill.
  final bool ownTeam;

  /// Just the pitch, for screens that list the picks their own way.
  final bool pitchOnly;

  @override
  State<LineupView> createState() => _LineupViewState();
}

class _LineupViewState extends State<LineupView> {
  /// Kept for the app session, so the Team tab and profiles open the same way
  /// the Manager last chose.
  static bool _showPitch = true;

  @override
  Widget build(BuildContext context) {
    final roster = widget.roster;
    final isFootball = roster.mode == SportMode.football;
    final pitch = widget.pitchOnly || _showPitch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                widget.title ?? (isFootball ? 'Starting XI' : 'Lineup'),
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (isFootball && roster.formation != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  roster.formation!,
                  style: AppTextStyles.mono(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
            ],
            const Spacer(),
            if (!widget.pitchOnly)
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(value: true, icon: Icon(Icons.stadium_outlined, size: 16), tooltip: 'Pitch'),
                  ButtonSegment(value: false, icon: Icon(Icons.format_list_bulleted, size: 16), tooltip: 'List'),
                ],
                selected: {pitch},
                onSelectionChanged: (s) => setState(() => _showPitch = s.first),
              ),
            if (widget.action != null) ...[
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: widget.action!.onPressed,
                icon: Icon(widget.action!.icon, size: 16),
                label: Text(widget.action!.label),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (pitch)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: FormationBoard(roster: roster, onSlotTap: widget.onSlotTap),
            ),
          )
        else if (widget.ownTeam)
          ..._ownList(roster)
        else
          for (final (i, slot) in roster.slots.indexed)
            if (slot.stock != null) _CompactRow(slot: slot, armband: roster.armband(i)),
      ],
    );
  }

  List<Widget> _ownList(Roster roster) {
    final session = roster.session;
    return [
      for (var i = 0; i < roster.slots.length; i++) ...[
        RosterSlotCard(
          slot: roster.slots[i],
          teamValueUsd: roster.totalValueUsd,
          score: session?.scoreFor(i),
          live: session?.liveFor(i) ?? const [],
          armband: roster.armband(i),
        ),
        const SizedBox(height: 8),
      ],
      if (session != null)
        for (final event in session.teamEvents)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.group, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  '${event.label} ${formatSignedPoints(event.points)}',
                  style: AppTextStyles.mono(fontSize: 12, color: pnlColor(event.points)),
                ),
              ],
            ),
          ),
    ];
  }
}

/// Another Manager's pick: position, stock and today's move. Share counts
/// stay private.
class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.slot, this.armband});

  final RosterSlot slot;
  final String? armband;

  @override
  Widget build(BuildContext context) {
    final stock = slot.stock!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              slot.position.label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: stock.tier.color),
            ),
          ),
          Text(stock.symbol, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          if (armband != null) ...[
            const SizedBox(width: 6),
            ArmbandBadge(label: armband!, size: 16),
          ],
          if (stock.notScoring != null) ...[
            const SizedBox(width: 6),
            Flexible(child: NotScoringBadge(reason: stock.notScoring!, compact: true)),
          ],
          const Spacer(),
          Text(
            formatPct(stock.change24hPct / 100),
            style: TextStyle(fontSize: 12, color: pnlColor(stock.change24hPct)),
          ),
        ],
      ),
    );
  }
}
