import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/extensions/context_extensions.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/core/widgets/adaptive_sheet.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/shared/domain/roster_shapes.dart';
import 'package:formation/features/shared/ui/widgets/sell_stock_sheet.dart';
import 'package:formation/features/team/ui/cubits/team_cubit.dart';

/// Substitutes, the way fantasy games show them: a row of bench spots under
/// the team (4 in football, 3 in basketball, 6 in American football). The
/// bench is the wallet: every held stock that isn't starting sits on it, the
/// best first, and "More" lists them all with a way to bring each one on.
class SubstitutesBench extends StatelessWidget {
  const SubstitutesBench({required this.roster, required this.onAddStock, super.key});

  final Roster roster;

  /// Opens the draft board to buy a stock for an empty spot.
  final VoidCallback onAddStock;

  @override
  Widget build(BuildContext context) {
    final bench = orderedBench(roster.bench);
    final spots = benchSpots(roster.mode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text('Substitutes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                bench.isEmpty ? 'Stocks you hold sit here' : '${bench.length} held, not starting',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
            if (bench.isNotEmpty)
              TextButton.icon(
                onPressed: () => SubstitutesSheet.show(context, roster: roster),
                icon: const Icon(Icons.unfold_more, size: 16),
                label: Text(bench.length > spots ? 'More (${bench.length})' : 'More'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < spots; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: i < bench.length
                    ? _BenchSpot(
                        number: i + 1,
                        slot: bench[i],
                        onTap: () => SubstitutesSheet.show(context, roster: roster, focus: bench[i].stock),
                      )
                    : _EmptySpot(number: i + 1, onTap: onAddStock),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Bench order: stocks that can come on first, then the most valuable.
List<BenchSlot> orderedBench(List<BenchSlot> bench) => [...bench]
  ..sort((a, b) {
    int ready(BenchSlot s) => s.eligibleSlots.isNotEmpty ? 0 : 1;
    final byReady = ready(a).compareTo(ready(b));
    return byReady != 0 ? byReady : b.valueUsd.compareTo(a.valueUsd);
  });

class _BenchSpot extends StatelessWidget {
  const _BenchSpot({required this.number, required this.slot, required this.onTap});

  final int number;
  final BenchSlot slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stock = slot.stock;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: stock.tier.color.withValues(alpha: 0.6)),
          ),
          child: Column(
            children: [
              Text(
                'SUB $number',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: stock.tier.color),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      stock.symbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.mono(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                formatUsd(slot.valueUsd),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySpot extends StatelessWidget {
  const _EmptySpot({required this.number, required this.onTap});

  final int number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              'SUB $number',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textMuted),
            ),
            const SizedBox(height: 4),
            const Icon(Icons.add, size: 16, color: AppColors.textMuted),
            const Text('Add', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// Every held stock on the bench, with where each can come on. A bottom
/// sheet on a phone, a dialog on a wider screen.
class SubstitutesSheet extends StatefulWidget {
  const SubstitutesSheet({required this.roster, this.focus, super.key});

  final Roster roster;

  /// The stock tapped on the bench, opened ready to bring on.
  final XStock? focus;

  static Future<void> show(BuildContext context, {required Roster roster, XStock? focus}) {
    final cubit = context.read<TeamCubit>();
    return showAdaptiveSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: SubstitutesSheet(roster: roster, focus: focus),
      ),
    );
  }

  @override
  State<SubstitutesSheet> createState() => _SubstitutesSheetState();
}

class _SubstitutesSheetState extends State<SubstitutesSheet> {
  late String? _open = widget.focus?.mint;
  String? _busy;

  Roster get _roster => widget.roster;

  /// What bringing someone on costs right now, in words.
  String _costFor(int slotIndex) {
    if (_roster.slots[slotIndex].stock == null) return 'Free: the spot is empty';
    final session = _roster.session;
    if (session == null) return 'Free';
    if (session.transferWindowOpen) return 'Free: the transfer window is open';
    if (session.freeSubstitutionsLeft > 0) {
      return 'Free (${session.freeSubstitutionsLeft} free sub${session.freeSubstitutionsLeft == 1 ? '' : 's'} left today)';
    }
    return 'Costs 4 points: no free subs left today';
  }

  Future<void> _bringOn(BenchSlot sub, int slotIndex) async {
    final off = _roster.slots[slotIndex].stock;
    setState(() => _busy = '${sub.stock.mint}:$slotIndex');
    try {
      await context.read<TeamCubit>().substitute(slotIndex, sub.stock);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.showSuccessToast(
        message: off == null
            ? '${sub.stock.symbol} is on at ${_roster.slots[slotIndex].position.label}'
            : '${sub.stock.symbol} on, ${off.symbol} off',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = null);
      context.showErrorToast(message: errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bench = orderedBench(_roster.bench);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text('Substitutes', style: Theme.of(context).textTheme.titleLarge),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Every stock you hold that isn\'t starting. Bring one on in any spot its tier fits.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                itemCount: bench.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final sub = bench[i];
                  final open = _open == sub.stock.mint;
                  return _SubRow(
                    sub: sub,
                    roster: _roster,
                    open: open,
                    busy: _busy,
                    onToggle: () => setState(() => _open = open ? null : sub.stock.mint),
                    onBringOn: (slot) => _bringOn(sub, slot),
                    costFor: _costFor,
                    onSell: () {
                      Navigator.of(context).pop();
                      SellStockSheet.show(context, stock: sub.stock, held: sub.balance);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubRow extends StatelessWidget {
  const _SubRow({
    required this.sub,
    required this.roster,
    required this.open,
    required this.busy,
    required this.onToggle,
    required this.onBringOn,
    required this.costFor,
    required this.onSell,
  });

  final BenchSlot sub;
  final Roster roster;
  final bool open;
  final String? busy;
  final VoidCallback onToggle;
  final ValueChanged<int> onBringOn;
  final String Function(int slotIndex) costFor;
  final VoidCallback onSell;

  @override
  Widget build(BuildContext context) {
    final stock = sub.stock;
    final canPlay = sub.eligibleSlots.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: canPlay ? onToggle : null,
          title: Row(
            children: [
              Text(stock.symbol, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: stock.tier.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(stock.tier.label, style: TextStyle(fontSize: 10, color: stock.tier.color)),
              ),
            ],
          ),
          subtitle: Text(
            [
              '${formatShares(sub.balance)} · ${formatUsd(sub.valueUsd)}',
              if (sub.eligibleSlots.isEmpty) 'no ${stock.tier.label.toLowerCase()} spot in this team',
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: onSell, child: const Text('Sell')),
              if (canPlay) Icon(open ? Icons.expand_less : Icons.expand_more, color: AppColors.textMuted),
            ],
          ),
        ),
        if (open && canPlay)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final slotIndex in sub.eligibleSlots)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _SlotChoice(
                      position: roster.slots[slotIndex].position.label,
                      current: roster.slots[slotIndex].stock,
                      cost: costFor(slotIndex),
                      busy: busy == '${stock.mint}:$slotIndex',
                      enabled: busy == null,
                      onTap: () => onBringOn(slotIndex),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// "Bring on at FWD for TSLAx · Free (2 free subs left today)".
class _SlotChoice extends StatelessWidget {
  const _SlotChoice({
    required this.position,
    required this.current,
    required this.cost,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final String position;
  final XStock? current;
  final String cost;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current == null ? 'Bring on at $position' : 'Bring on at $position for ${current!.symbol}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(cost, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (busy) const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }
}
