import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/wallet/ui/cubits/wallet_cubit.dart';
import 'package:formation/features/wallet/ui/cubits/wallet_state.dart';

/// Asks for the tap that mobile Chrome needs before it will open the wallet.
///
/// Shown over [child] while [WalletState.needsTap] is up. That happens on
/// mobile web when a wallet action was not started directly by the player —
/// signing in again after a session expires, or a buy whose transaction took
/// a moment to build. Chrome only lets a tap switch to the wallet app, so the
/// "Open wallet" button's own tap is what carries the action through.
///
/// It sits above the router rather than being pushed onto it, so it works
/// whichever screen the waiting action came from.
class WalletTapGate extends StatelessWidget {
  const WalletTapGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletCubit, WalletState>(
      buildWhen: (a, b) => a.needsTap != b.needsTap,
      builder: (context, state) => Stack(
        children: [
          child,
          if (state.needsTap) const Positioned.fill(child: _TapPrompt()),
        ],
      ),
    );
  }
}

class _TapPrompt extends StatelessWidget {
  const _TapPrompt();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WalletCubit>();

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        size: 32, color: AppColors.primary),
                    const SizedBox(height: 14),
                    Text(
                      'Continue in your wallet',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your browser needs a tap before it can open your wallet app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: cubit.continueInWallet,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textInverse,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Open wallet'),
                    ),
                    TextButton(
                      onPressed: cubit.cancelWalletAction,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
