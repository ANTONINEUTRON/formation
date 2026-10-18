import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/extensions/context_extensions.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/widgets/adaptive_sheet.dart';
import 'package:formation/features/wallet/ui/cubits/wallet_cubit.dart';

/// How to get money into a Solana wallet to buy stocks: USDC to spend, and a
/// little SOL for network fees. Formation never holds funds, so this is a
/// guide, not a payment.
class FundWalletSheet extends StatelessWidget {
  const FundWalletSheet({super.key});

  static Future<void> show(BuildContext context) => showAdaptiveSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => BlocProvider.value(value: context.read<WalletCubit>(), child: const FundWalletSheet()),
      );

  @override
  Widget build(BuildContext context) {
    final address = context.select<WalletCubit, String?>((c) => c.state.walletAddress);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add money to your wallet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text(
              'Stocks are bought with USDC, a digital dollar, in your own wallet. Formation never holds your money.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            const _Step(
              number: 1,
              title: 'Get USDC on Solana',
              body: 'In your wallet app (Phantom, Solflare and others), tap Buy to pay by card or bank '
                  'through its payment partner. Or send USDC from an exchange such as Coinbase or Kraken, '
                  'and choose the Solana network when you withdraw.',
            ),
            const _Step(
              number: 2,
              title: 'Keep a little SOL for fees',
              body: 'Every trade pays the Solana network a fraction of a cent, and a stock you have never '
                  'held needs about 0.008 SOL once to open its account. Around 0.02 SOL covers plenty of '
                  'trades. Most wallets let you buy SOL the same way as USDC.',
            ),
            const _Step(
              number: 3,
              title: 'Come back and pick your stocks',
              body: 'Your balance shows under Profile > Balances; pull to refresh it. Buys of \$1 or more '
                  'work, so you can start small.',
            ),
            if (address != null) ...[
              const SizedBox(height: 8),
              const Text('Your wallet address', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(address, style: AppTextStyles.mono(fontSize: 12), overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      tooltip: 'Copy address',
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: address));
                        if (context.mounted) context.showSuccessToast(message: 'Address copied');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Only send Solana-network funds to this address. Funds sent on another network can be lost.',
                style: TextStyle(fontSize: 11, color: AppColors.warning, height: 1.4),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Got it')),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.body});

  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primary.withValues(alpha: 0.18),
            child: Text('$number', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
