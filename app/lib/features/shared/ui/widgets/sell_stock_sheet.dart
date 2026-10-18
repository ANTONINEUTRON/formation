import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/extensions/context_extensions.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/core/widgets/adaptive_sheet.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/shared/ui/widgets/thin_market_warning.dart';

/// Sells held shares of a stock for USDC through Jupiter, signed in the
/// Manager's own wallet. Selling a pick that's on the team takes it off at
/// the points it has banked; it's never charged a substitution.
class SellStockSheet extends StatefulWidget {
  const SellStockSheet({required this.stock, required this.held, this.inTeam = false, super.key});

  final XStock stock;

  /// Shares the wallet holds.
  final double held;

  /// Whether the stock is in the starting lineup.
  final bool inTeam;

  static Future<void> show(BuildContext context, {required XStock stock, required double held, bool inTeam = false}) =>
      showAdaptiveSheet<void>(
        context: context,
        builder: (_) => RepositoryProvider.value(
          value: context.read<FormationRepository>(),
          child: SellStockSheet(stock: stock, held: held, inTeam: inTeam),
        ),
      );

  @override
  State<SellStockSheet> createState() => _SellStockSheetState();
}

class _SellStockSheetState extends State<SellStockSheet> {
  late final _controller = TextEditingController(text: _format(widget.held));
  Timer? _debounce;
  late double _shares = widget.held;
  SellQuote? _quote;
  String? _quoteError;
  bool _selling = false;
  int _request = 0;

  static String _format(double shares) => shares.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');

  @override
  void initState() {
    super.initState();
    _fetchQuote();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String? get _amountError {
    final value = double.tryParse(_controller.text.trim());
    if (value == null) return 'Enter a number';
    if (value <= 0) return 'Enter an amount greater than zero';
    if (value > widget.held + 1e-9) return 'You hold ${formatShares(widget.held)}';
    return null;
  }

  void _setShares(double shares) {
    _controller.text = _format(shares);
    _onChanged(_controller.text);
  }

  void _onChanged(String raw) {
    _debounce?.cancel();
    setState(() {
      _quote = null;
      _quoteError = null;
    });
    if (_amountError != null) return;
    _shares = double.parse(raw.trim());
    _debounce = Timer(const Duration(milliseconds: 500), _fetchQuote);
  }

  Future<void> _fetchQuote() async {
    if (_amountError != null) return;
    final request = ++_request;
    try {
      final quote = await context.read<FormationRepository>().getSellQuote(widget.stock, _shares);
      if (mounted && request == _request) setState(() => _quote = quote);
    } catch (e) {
      if (mounted && request == _request) setState(() => _quoteError = errorText(e));
    }
  }

  String? _thinMarketMessage(SellQuote quote) {
    final loss = quote.roundTripLoss;
    if (loss == null || loss <= thinMarketWarnAt) return null;
    return "Thin market: if you bought back straight after selling, you'd get about "
        '${formatShares(quote.buyBackShares!)} of your ${formatShares(quote.shares)} ${widget.stock.symbol} '
        '(${(loss * 100).round()}% less). Very little money trades it right now.';
  }

  Future<void> _sell() async {
    final quote = _quote;
    if (quote == null) return;
    final thin = _thinMarketMessage(quote);
    if (thin != null && (quote.roundTripLoss ?? 0) > thinMarketConfirmAt) {
      if (!await confirmThinMarket(context, message: thin) || !mounted) return;
    }
    setState(() => _selling = true);
    try {
      final usdc = await context.read<FormationRepository>().executeSell(quote);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.showSuccessToast(
        message: 'Sold ${formatShares(quote.shares)} ${widget.stock.symbol} for about ${formatUsd(usdc)}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _selling = false);
      context.showErrorToast(message: errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    final sellingAll = (_shares - widget.held).abs() < 1e-9;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sell ${widget.stock.symbol}', style: Theme.of(context).textTheme.titleLarge),
            Text(
              '${widget.stock.companyName} · you hold ${formatShares(widget.held)}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              enabled: !_selling,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,8}'))],
              style: AppTextStyles.mono(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Shares',
                suffixText: widget.stock.symbol,
                errorText: _controller.text.isEmpty ? null : _amountError,
              ),
              onChanged: _onChanged,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final (label, share) in const [('25%', 0.25), ('50%', 0.5), ('Max', 1.0)])
                  ActionChip(
                    label: Text(label),
                    onPressed: _selling ? null : () => _setShares(widget.held * share),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(12)),
              child: quote == null
                  ? SizedBox(
                      height: 90,
                      child: Center(
                        child: _quoteError != null
                            ? Text(_quoteError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error))
                            : const CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Column(
                      children: [
                        _Row('You sell', '${formatShares(quote.shares)} ${widget.stock.symbol}'),
                        _Row('You receive (est.)', '${formatAmount(quote.estimatedUsdc)} USDC'),
                        if (quote.platformFeeBps > 0)
                          _Row('Fee (${(quote.platformFeeBps / 100).toStringAsFixed(1)}%)', '${formatAmount(quote.platformFee)} USDC'),
                        const _Row('Route', 'Jupiter'),
                      ],
                    ),
            ),
            if (quote != null && _thinMarketMessage(quote) != null) ...[
              const SizedBox(height: 12),
              ThinMarketWarning(message: _thinMarketMessage(quote)!),
            ],
            if (widget.inTeam && sellingAll) ...[
              const SizedBox(height: 12),
              Text(
                '${widget.stock.symbol} is in your team. Selling all of it takes it off at the points it has '
                "banked. It isn't charged as a substitution.",
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'You sign this swap in your own wallet. Formation never holds your funds.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: quote == null || _selling || _amountError != null ? null : _sell,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: _selling
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('Confirm in wallet…'),
                      ],
                    )
                  : const Text('Sell'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.mono(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
