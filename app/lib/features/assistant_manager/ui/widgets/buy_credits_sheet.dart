import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/extensions/context_extensions.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/core/widgets/adaptive_sheet.dart';
import 'package:formation/features/assistant_manager/domain/assistant_models.dart';
import 'package:formation/features/assistant_manager/ui/cubits/assistant_cubit.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/wallet/ui/cubits/wallet_cubit.dart';

/// Buy Assistant Manager credits with SKR.
///
/// Pick a pack, see its price in SKR at the live rate, then approve the
/// transfer in the wallet. Credits arrive once the payment is confirmed
/// on-chain, never before.
class BuyCreditsSheet extends StatefulWidget {
  const BuyCreditsSheet({required this.packs, super.key});

  final List<CreditPack> packs;

  static Future<void> show(BuildContext context, List<CreditPack> packs) {
    final cubit = context.read<AssistantCubit>();
    final repository = context.read<FormationRepository>();
    final wallet = context.read<WalletCubit>();
    return showAdaptiveSheet<void>(
      context: context,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cubit),
          BlocProvider.value(value: wallet),
        ],
        child: RepositoryProvider.value(
          value: repository,
          child: BuyCreditsSheet(packs: packs),
        ),
      ),
    );
  }

  @override
  State<BuyCreditsSheet> createState() => _BuyCreditsSheetState();
}

class _BuyCreditsSheetState extends State<BuyCreditsSheet> {
  CreditPack? _pack;
  CreditQuote? _quote;
  bool _quoting = false;
  bool _buying = false;
  String? _error;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _select(CreditPack pack) async {
    setState(() {
      _pack = pack;
      _quote = null;
      _quoting = true;
      _error = null;
    });
    try {
      final quote = await context.read<FormationRepository>().quoteCredits(pack);
      if (!mounted || _pack != pack) return;
      setState(() => _quote = quote);
      // Re-render each second so the expiry counts down and the button
      // switches to "Refresh price" once the quote lapses.
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _buy(CreditQuote quote) async {
    setState(() {
      _buying = true;
      _error = null;
    });
    try {
      final balance = await context.read<FormationRepository>().buyCredits(quote);
      if (!mounted) return;
      context.read<AssistantCubit>().creditsBought(balance);
      context.read<WalletCubit>().fetchBalances().ignore();
      Navigator.of(context).pop();
      context.showSuccessToast(
        message: '${quote.pack.credits} credits added. Your Assistant Manager is ready.',
      );
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    final expired = quote != null && quote.expiresAt.isBefore(DateTime.now());
    final skrHeld = context
        .watch<WalletCubit>()
        .state
        .balances
        .where((b) => b.currency == 'SKR')
        .firstOrNull
        ?.amount;
    final short = quote != null && skrHeld != null && skrHeld < quote.skrAmount;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Buy credits',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'One credit is one reply from your Assistant Manager. Paid in SKR from your wallet.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            for (final pack in widget.packs) ...[
              _PackTile(
                pack: pack,
                selected: pack == _pack,
                best: pack == widget.packs.last && widget.packs.length > 1,
                // Discounts are against the smallest pack's rate.
                baseRate: widget.packs.first.usd / widget.packs.first.credits,
                onTap: _buying ? null : () => _select(pack),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            if (_quoting)
              const Center(child: CircularProgressIndicator(color: AppColors.primary))
            else if (quote != null) ...[
              Text(
                expired
                    ? 'That price expired.'
                    : 'Price held for ${quote.expiresAt.difference(DateTime.now()).inSeconds}s',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              if (short)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'You hold ${formatAmount(skrHeld)} SKR — not enough for this pack. '
                    'Top up SKR in your wallet, or pick a smaller pack.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.warning),
                  ),
                ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _buying
                    ? null
                    : expired
                    ? () => _select(quote.pack)
                    : () => _buy(quote),
                child: Text(
                  _buying
                      ? 'Confirm in your wallet…'
                      : expired
                      ? 'Refresh price'
                      : 'Pay ${formatAmount(quote.skrAmount)} SKR',
                ),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PackTile extends StatelessWidget {
  const _PackTile({
    required this.pack,
    required this.selected,
    required this.best,
    required this.baseRate,
    required this.onTap,
  });

  final CreditPack pack;
  final bool selected;
  final bool best;

  /// Dollars a credit in the smallest pack.
  final double baseRate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final perReply = pack.usd / pack.credits * 100;
    final saving = ((1 - (pack.usd / pack.credits) / baseRate) * 100).round();
    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.toll_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${pack.credits} credits',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        if (best) ...[
                          const SizedBox(width: 8),
                          const Text(
                            'BEST VALUE',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text.rich(
                      TextSpan(
                        text: '${perReply.toStringAsFixed(perReply % 1 == 0 ? 0 : 1)}¢ per reply',
                        children: [
                          if (saving > 0)
                            TextSpan(
                              text: '  ·  save $saving%',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                '\$${pack.usd.toStringAsFixed(pack.usd % 1 == 0 ? 0 : 2)}',
                style: AppTextStyles.mono(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
