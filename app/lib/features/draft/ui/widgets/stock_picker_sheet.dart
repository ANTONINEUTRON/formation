import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/extensions/context_extensions.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/features/draft/ui/cubits/draft_cubit.dart';
import 'package:formation/features/draft/ui/cubits/draft_state.dart';
import 'package:formation/features/draft/ui/widgets/buy_stock_sheet.dart';
import 'package:formation/features/shared/domain/models.dart';

/// Searchable, tier-filtered list of xStocks for one roster slot.
class StockPickerSheet extends StatefulWidget {
  const StockPickerSheet({required this.slotIndex, required this.onBuy, super.key});

  final int slotIndex;
  final ValueChanged<XStock> onBuy;

  static Future<void> show(BuildContext context, {required int slotIndex}) {
    final cubit = context.read<DraftCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => BlocProvider.value(
        value: cubit,
        child: StockPickerSheet(
          slotIndex: slotIndex,
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

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DraftCubit>();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) => BlocBuilder<DraftCubit, DraftState>(
        builder: (context, state) {
          final position = state.roster!.slots[widget.slotIndex].position;
          final q = _query.toLowerCase();
          final stocks = cubit
              .eligible(widget.slotIndex)
              .where((s) => q.isEmpty || s.symbol.toLowerCase().contains(q) || s.companyName.toLowerCase().contains(q))
              .toList();

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
                    _TierBadge(tier: position.requiredTier),
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
                child: stocks.isEmpty
                    ? const Center(child: Text('No eligible stocks', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount: stocks.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final stock = stocks[i];
                          final held = state.heldBalance(stock);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(stock.symbol, style: const TextStyle(fontWeight: FontWeight.w700)),
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
                                          onPressed: _adding == null ? () => _add(stock) : null,
                                          style: FilledButton.styleFrom(backgroundColor: AppColors.success, padding: EdgeInsets.zero),
                                          child: _adding == stock.mint
                                              ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                              : const Text('Add'),
                                        )
                                      : OutlinedButton(
                                          onPressed: _adding == null ? () => widget.onBuy(stock) : null,
                                          style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                                          child: const Text('Buy'),
                                        ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
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
