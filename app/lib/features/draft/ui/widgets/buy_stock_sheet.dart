import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:symbians/core/extensions/context_extensions.dart';
import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/utils/format.dart';
import 'package:symbians/features/draft/ui/cubits/draft_cubit.dart';
import 'package:symbians/features/shared/domain/models.dart';

/// Quote preview and confirm for buying an xStock with USDC via Jupiter.
class BuyStockSheet extends StatefulWidget {
  const BuyStockSheet({required this.slotIndex, required this.stock, super.key});

  final int slotIndex;
  final XStock stock;

  static Future<void> show(BuildContext context, {required int slotIndex, required XStock stock}) {
    final cubit = context.read<DraftCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: BuyStockSheet(slotIndex: slotIndex, stock: stock),
      ),
    );
  }

  @override
  State<BuyStockSheet> createState() => _BuyStockSheetState();
}

class _BuyStockSheetState extends State<BuyStockSheet> {
  static const _amounts = [5.0, 10.0, 25.0, 50.0];

  double _amount = _amounts[1];
  SwapQuote? _quote;
  bool _buying = false;
  int _quoteRequest = 0;

  @override
  void initState() {
    super.initState();
    _fetchQuote();
  }

  Future<void> _fetchQuote() async {
    final request = ++_quoteRequest;
    setState(() => _quote = null);
    try {
      final quote = await context.read<DraftCubit>().quote(widget.stock, _amount);
      if (mounted && request == _quoteRequest) setState(() => _quote = quote);
    } catch (e) {
      if (mounted) context.showErrorToast(message: errorText(e));
    }
  }

  Future<void> _confirm() async {
    final quote = _quote;
    if (quote == null) return;
    setState(() => _buying = true);
    try {
      final shares = await context.read<DraftCubit>().buyAndFill(widget.slotIndex, quote);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.showSuccessToast(message: 'Bought ${formatShares(shares)} ${widget.stock.symbol}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _buying = false);
      context.showErrorToast(message: errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Buy ${widget.stock.symbol}', style: Theme.of(context).textTheme.titleLarge),
            Text(
              '${widget.stock.companyName} · ${formatUsd(widget.stock.priceUsd)}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              children: [
                for (final a in _amounts)
                  ChoiceChip(
                    label: Text(formatUsd(a).replaceAll('.00', '')),
                    selected: a == _amount,
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: a == _amount ? AppColors.textInverse : AppColors.textPrimary),
                    onSelected: _buying
                        ? null
                        : (_) {
                            setState(() => _amount = a);
                            _fetchQuote();
                          },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: quote == null
                  ? const SizedBox(height: 110, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                  : Column(
                      children: [
                        _QuoteRow('You pay', '${formatUsd(quote.inputUsdc)} USDC'),
                        _QuoteRow('You receive (est.)', '${formatShares(quote.estimatedShares)} ${widget.stock.symbol}'),
                        _QuoteRow('Price impact', formatPct(quote.priceImpactPct, signed: false)),
                        _QuoteRow(
                          'Platform fee (${formatPct(quote.platformFeeBps / 10000, signed: false)})',
                          formatUsd(quote.platformFeeUsdc),
                        ),
                        const _QuoteRow('Route', 'Jupiter'),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            const Text(
              'You sign this swap in your own wallet. Formation never holds your funds.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: quote == null || _buying ? null : _confirm,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: _buying
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('Confirm in wallet…'),
                      ],
                    )
                  : const Text('Buy & add to team'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteRow extends StatelessWidget {
  const _QuoteRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Text(value, style: AppTextStyles.mono(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
