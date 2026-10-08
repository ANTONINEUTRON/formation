import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/extensions/context_extensions.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/widgets/adaptive_sheet.dart';
import 'package:formation/core/utils/app_log.dart';
import 'package:formation/core/widgets/pay_token_picker.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/features/draft/ui/cubits/draft_cubit.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/wallet/ui/cubits/wallet_cubit.dart';

/// Quote preview and confirm for buying an xStock with USDC via Jupiter.
class BuyStockSheet extends StatefulWidget {
  const BuyStockSheet({required this.slotIndex, required this.stock, super.key});

  final int slotIndex;
  final XStock stock;

  static Future<void> show(BuildContext context, {required int slotIndex, required XStock stock}) {
    final cubit = context.read<DraftCubit>();
    // A bottom sheet on a phone, a dialog on anything wider.
    return showAdaptiveSheet<void>(
      context: context,
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
  final _controller = TextEditingController(text: '10');
  Timer? _debounce;

  double _amount = 10;
  SwapQuote? _quote;
  bool _buying = false;
  int _quoteRequest = 0;

  /// What the server accepts. Starts with USDC alone so the field is usable
  /// before the list arrives.
  List<PayToken> _payTokens = const [PayToken.usdc];
  PayToken _payWith = PayToken.usdc;

  @override
  void initState() {
    super.initState();
    _loadPayTokens();
    _fetchQuote();
  }

  Future<void> _loadPayTokens() async {
    try {
      final tokens = await context.read<DraftCubit>().payTokens();
      if (mounted && tokens.isNotEmpty) setState(() => _payTokens = tokens);
    } catch (e) {
      // Paying in USDC still works, so this is not worth interrupting for.
      AppLog.warn('Could not load pay tokens', e);
    }
  }

  void _setPayWith(PayToken token) {
    if (token == _payWith) return;
    setState(() {
      _payWith = token;
      _quote = null;
    });
    _fetchQuote();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// SOL a buy needs on hand beyond the trade itself.
  ///
  /// Rent for an associated token account the player does not have yet
  /// (~0.00204), the base fee, and Jupiter's `auto` priority fee, which it
  /// caps at 0.005 SOL. Rounded up, because the cost of overstating this is a
  /// warning the player did not need and the cost of understating it is a
  /// failed signature.
  static const double _solHeadroom = 0.008;

  /// True when the wallet cannot cover the fees, whatever it is paying with.
  ///
  /// Easy to hit and confusing when you do: a wallet funded only with USDC has
  /// everything it needs to buy a stock except the SOL to pay for the
  /// transaction. The wallet's own message for this is "couldn't be
  /// simulated", which says nothing about SOL.
  bool get _lowOnSol {
    final balances = context.read<WalletCubit>().state.balances;
    final sol = balances.where((b) => b.currency == 'SOL').firstOrNull;
    // No balance yet means the fetch has not landed; stay quiet rather than
    // warn on missing data.
    if (sol == null) return false;
    return sol.amount < _solHeadroom;
  }

  /// Null while the amount is usable; otherwise why it isn't.
  ///
  /// There is no ceiling: it's the player's own wallet, and Jupiter rejects
  /// anything it cannot route. Only an unusable number is refused here.
  String? get _amountError {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return 'Enter an amount';
    final value = double.tryParse(raw);
    if (value == null) return 'Enter a number';
    if (value <= 0) return 'Enter an amount greater than zero';
    // Caught here as well as on the server, so a too-small amount reads as a
    // field error rather than a failed request — and so we do not ask Jupiter
    // to price a trade we already know will be refused.
    if (value < _payWith.minAmount) {
      return 'At least ${formatAmount(_payWith.minAmount)} ${_payWith.symbol}';
    }
    return null;
  }

  /// Re-quotes once the user stops typing, so each keystroke isn't a request.
  void _onAmountChanged(String raw) {
    _debounce?.cancel();
    setState(() => _quote = null);
    if (_amountError != null) return;
    _amount = double.parse(raw.trim());
    _debounce = Timer(const Duration(milliseconds: 500), _fetchQuote);
  }

  Future<void> _fetchQuote() async {
    if (_amountError != null) return;
    final request = ++_quoteRequest;
    setState(() => _quote = null);
    try {
      final quote =
          await context.read<DraftCubit>().quote(widget.stock, _amount, payWith: _payWith);
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
      // The amount field autofocuses, so the keyboard is up before the player
      // has done anything. showAdaptiveSheet lifts the sheet clear of it; this
      // scrolls when even the lifted sheet does not fit, which is the case on
      // a short phone once the quote rows appear.
      child: SingleChildScrollView(
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
            TextField(
              controller: _controller,
              enabled: !_buying,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: AppTextStyles.mono(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Amount',
                errorText: _controller.text.isEmpty ? null : _amountError,
                // The picker sits inside the field, so the amount and the
                // token it is denominated in read as one control.
                suffixIcon: PayTokenPicker(
                  tokens: _payTokens,
                  selected: _payWith,
                  onChanged: _buying ? null : _setPayWith,
                ),
                suffixIconConstraints: const BoxConstraints(minWidth: 108),
              ),
              onChanged: _onAmountChanged,
              onSubmitted: (_) => _fetchQuote(),
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
                        _QuoteRow(
                          'You pay',
                          '${formatAmount(quote.inputAmount)} ${quote.payWith}',
                        ),
                        _QuoteRow('You receive (est.)', '${formatShares(quote.estimatedShares)} ${widget.stock.symbol}'),
                        
                        const _QuoteRow('Route', 'Jupiter'),
                      ],
                    ),
            ),
            if (_lowOnSol) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_gas_station_outlined,
                        size: 18, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Low on SOL. Every swap costs network fees, and a stock '
                        'you have never held needs about ${formatAmount(_solHeadroom)} SOL '
                        'to open its account. Without it your wallet will say it '
                        "can't simulate the transaction, and signing would fail.",
                        style: const TextStyle(fontSize: 12, color: AppColors.warning, height: 1.4),
                      ),
                    ),
                  ],
                ),
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
              onPressed: quote == null || _buying || _amountError != null ? null : _confirm,
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
          const SizedBox(width: 12),
          // A long amount on a narrow screen ("12,345.6789 SPYx") used to
          // push the row past its width and throw; it now gives way instead.
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
