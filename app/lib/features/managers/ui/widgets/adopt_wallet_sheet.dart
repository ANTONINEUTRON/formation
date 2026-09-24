import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:formation/core/extensions/context_extensions.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/domain/models.dart';

/// Buy the same stocks a manager holds, with your own money.
///
/// Nothing is transferred and the manager is not involved: their wallet is
/// public, and each purchase is an ordinary Jupiter swap you sign yourself.
/// Everything starts selected; unticking is how you take only part of it.
class AdoptWalletSheet extends StatefulWidget {
  const AdoptWalletSheet({
    required this.manager,
    required this.repository,
    super.key,
  });

  final Manager manager;
  final FormationRepository repository;

  static Future<void> show(
    BuildContext context, {
    required Manager manager,
    required FormationRepository repository,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => AdoptWalletSheet(manager: manager, repository: repository),
      );

  @override
  State<AdoptWalletSheet> createState() => _AdoptWalletSheetState();
}

class _AdoptWalletSheetState extends State<AdoptWalletSheet> {
  late final Set<String> _selected = {
    for (final h in widget.manager.holdings) h.stock.mint,
  };
  final _budget = TextEditingController(text: '100');

  /// Index into the selected list while buying, so progress is visible.
  int _boughtCount = 0;
  bool _buying = false;
  String? _failure;

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  List<ManagerHolding> get _picked => widget.manager.holdings
      .where((h) => _selected.contains(h.stock.mint))
      .toList();

  double? get _total => double.tryParse(_budget.text.trim());

  /// The budget is split evenly, so the sheet buys picks rather than copying
  /// someone else's position sizes.
  double get _perStock =>
      _picked.isEmpty || _total == null ? 0 : _total! / _picked.length;

  String? get _error {
    if (_picked.isEmpty) return 'Select at least one stock';
    final total = _total;
    if (total == null) return 'Enter a budget';
    if (_perStock < 1) {
      return 'That is under \$1 per stock — raise the budget or pick fewer';
    }
    return null;
  }

  Future<void> _adopt() async {
    setState(() {
      _buying = true;
      _boughtCount = 0;
      _failure = null;
    });

    // Sequential on purpose: each swap is signed separately in the wallet.
    for (final holding in _picked) {
      try {
        final quote = await widget.repository.getSwapQuote(holding.stock, _perStock);
        await widget.repository.executeSwap(quote);
        if (!mounted) return;
        setState(() => _boughtCount++);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _buying = false;
          _failure = '${holding.stock.symbol}: ${errorText(e)}';
        });
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    context.showSuccessToast(
      message: 'Bought $_boughtCount of ${_picked.length} from '
          '${widget.manager.username}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final holdings = widget.manager.holdings;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Adopt ${widget.manager.username}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Buy the same stocks with your own money. Nothing moves between '
              'wallets — you sign every purchase.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _budget,
              enabled: !_buying,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: AppTextStyles.mono(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Total budget',
                prefixText: r'$ ',
                suffixText: 'USDC',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: holdings.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final holding = holdings[i];
                  final on = _selected.contains(holding.stock.mint);
                  return CheckboxListTile(
                    value: on,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: _buying
                        ? null
                        : (v) => setState(() {
                              v == true
                                  ? _selected.add(holding.stock.mint)
                                  : _selected.remove(holding.stock.mint);
                            }),
                    title: Row(
                      children: [
                        Text(
                          holding.stock.symbol,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (holding.starting) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star, size: 12, color: AppColors.warning),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      '${holding.stock.tier.label} · ${formatUsd(holding.stock.priceUsd)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    secondary: on && _perStock > 0
                        ? Text(
                            formatUsd(_perStock),
                            style: AppTextStyles.mono(fontSize: 12),
                          )
                        : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (_failure != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Stopped at $_failure',
                  style: const TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ),
            Text(
              _buying
                  ? 'Bought $_boughtCount of ${_picked.length} — approve each in your wallet'
                  : '${_picked.length} stock${_picked.length == 1 ? '' : 's'} · '
                      '${formatUsd(_perStock)} each',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _buying || _error != null ? null : _adopt,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: Text(_buying ? 'Buying…' : _error ?? 'Copy wallet'),
            ),
          ],
        ),
      ),
    );
  }
}
