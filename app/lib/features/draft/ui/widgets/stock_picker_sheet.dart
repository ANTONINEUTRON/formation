import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/extensions/context_extensions.dart';
import 'package:formation/core/layout/breakpoints.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/widgets/adaptive_sheet.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/features/draft/ui/cubits/draft_cubit.dart';
import 'package:formation/features/draft/ui/cubits/draft_state.dart';
import 'package:formation/features/draft/ui/widgets/buy_stock_sheet.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/shared/ui/widgets/paused_info_button.dart';
import 'package:formation/features/shared/ui/widgets/sell_stock_sheet.dart';

/// Searchable, tier-filtered list of xStocks for one roster slot.
///
/// Scoring stocks come first. Paused ones (not scoring) sit in a collapsed
/// section below: they can be bought, but not placed until they score again,
/// and each says why with a tap through to the Assistant Manager.
class StockPickerSheet extends StatefulWidget {
  const StockPickerSheet({required this.slotIndex, required this.onBuy, this.parentContext, super.key});

  final int slotIndex;
  final ValueChanged<XStock> onBuy;

  /// The screen that opened the picker, for sheets opened after it closes.
  final BuildContext? parentContext;

  static Future<void> show(BuildContext context, {required int slotIndex}) {
    final cubit = context.read<DraftCubit>();
    return showAdaptiveSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => BlocProvider.value(
        value: cubit,
        child: StockPickerSheet(
          slotIndex: slotIndex,
          parentContext: context,
          onBuy: (stock) {
            Navigator.of(sheetContext).pop();
            BuyStockSheet.show(context, slotIndex: slotIndex, stock: stock);
          },
        ),
      ),
    );
  }

  @override
  State<StockPickerSheet> createState() => _StockPickerSheetState();
}

class _StockPickerSheetState extends State<StockPickerSheet> {
  String _query = '';
  String? _adding;

  Future<void> _add(XStock stock) async {
    setState(() => _adding = stock.mint);
    try {
      await context.read<DraftCubit>().pick(widget.slotIndex, stock);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        context.showErrorToast(message: errorText(e));
        setState(() => _adding = null);
      }
    }
  }

  void _whyPaused(XStock stock) => whyPaused(context, stock, context.read<DraftCubit>().mode, screen: 'draft');

  bool _matches(XStock s) {
    final q = _query.toLowerCase();
    return q.isEmpty || s.symbol.toLowerCase().contains(q) || s.companyName.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    // On a phone this is a sheet you can drag taller. In a dialog there is
    // nothing to drag against, and DraggableScrollableSheet needs the
    // unbounded parent that only showModalBottomSheet gives it — inside a
    // dialog it cannot lay out, and the picker never appears.
    if (!context.layoutSize.isCompact) return _body(context, null);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) => _body(context, scrollController),
    );
  }

  Widget _body(BuildContext context, ScrollController? scrollController) {
    final cubit = context.read<DraftCubit>();

    return BlocBuilder<DraftCubit, DraftState>(
      builder: (context, state) {
        final position = state.roster!.slots[widget.slotIndex].position;
        final stocks = cubit.eligible(widget.slotIndex).where(_matches).toList();

        final current = state.roster!.slots[widget.slotIndex].stock;
        final currentHeld = current == null ? 0.0 : state.heldBalance(current);

        final rows = <Widget>[
          if (current != null && currentHeld > 0)
            _CurrentPick(
              stock: current,
              held: currentHeld,
              onSell: () {
                Navigator.of(context).pop();
                // The draft board doesn't follow wallet changes by itself.
                SellStockSheet.show(widget.parentContext ?? context, stock: current, held: currentHeld, inTeam: true)
                    .then((_) => cubit.load());
              },
            ),
          for (final stock in stocks)
            _StockRow(
              stock: stock,
              held: state.heldBalance(stock),
              showTierDot: position.alsoAccepts.isNotEmpty,
              adding: _adding,
              onAdd: () => _add(stock),
              onBuy: () => widget.onBuy(stock),
              onWhyPaused: stock.isScoring ? null : () => _whyPaused(stock),
            ),
          if (stocks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No eligible stocks', style: TextStyle(color: AppColors.textMuted))),
            ),
        ];

        return Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Text('Pick your ${position.label}', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  if (position.requiredTier == null)
                    const _TierBadge(tier: null)
                  else
                    for (final tier in position.tiers) ...[
                      const SizedBox(width: 6),
                      _TierBadge(tier: tier),
                    ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(hintText: 'Search ticker or company', prefixIcon: Icon(Icons.search)),
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => rows[i],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The stock already in this slot, with a way to sell it.
class _CurrentPick extends StatelessWidget {
  const _CurrentPick({required this.stock, required this.held, required this.onSell});

  final XStock stock;
  final double held;
  final VoidCallback onSell;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.person_pin_outlined, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'In this slot: ${stock.symbol} · ${formatShares(held)} held',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          TextButton(onPressed: onSell, child: const Text('Sell')),
        ],
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({
    required this.stock,
    required this.held,
    required this.showTierDot,
    required this.adding,
    required this.onBuy,
    required this.onAdd,
    this.onWhyPaused,
  });

  final XStock stock;
  final double held;
  final bool showTierDot;

  /// The mint being added right now, if any; every button waits for it.
  final String? adding;
  final VoidCallback onBuy;
  final VoidCallback onAdd;

  /// Set for a paused stock: the little orange ⓘ, which explains why.
  final VoidCallback? onWhyPaused;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Text(stock.symbol, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (onWhyPaused != null) PausedInfoButton(onPressed: onWhyPaused!),
          // A role that takes two tiers mixes them; say which is which.
          if (showTierDot) ...[
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: stock.tier.color, shape: BoxShape.circle),
            ),
          ],
        ],
      ),
      subtitle: Text(
        held > 0 ? '${stock.companyName} · held ${formatShares(held)} sh' : stock.companyName,
        style: TextStyle(color: held > 0 ? AppColors.success : AppColors.textSecondary, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatUsd(stock.priceUsd), style: AppTextStyles.mono(fontSize: 13)),
              Text(
                formatPct(stock.change24hPct / 100),
                style: AppTextStyles.mono(fontSize: 11, color: pnlColor(stock.change24hPct)),
              ),
            ],
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            child: held > 0
                ? FilledButton(
                    onPressed: adding == null ? onAdd : null,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.success, padding: EdgeInsets.zero),
                    child: adding == stock.mint
                        ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Add'),
                  )
                : OutlinedButton(
                    onPressed: adding == null ? onBuy : null,
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                    child: const Text('Buy'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier});

  final RiskTier? tier;

  @override
  Widget build(BuildContext context) {
    final color = tier?.color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(tier?.label ?? 'Any tier', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
