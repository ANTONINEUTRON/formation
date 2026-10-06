import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/wallet/data/wallet_connector.dart';
import 'package:formation/gen/assets.gen.dart';

/// Shown in the profile tab when no wallet is connected.
///
/// The parent passes [onConnect] and [isLoading] based on [WalletCubit] state
/// instead of this widget accessing the cubit directly. This keeps it
/// independently testable.
class ConnectWalletView extends StatelessWidget {
  const ConnectWalletView({
    super.key,
    required this.onConnect,
    this.isLoading = false,
    this.error,
    this.wallets = const [],
  });

  /// Connects to the named wallet, or lets the platform choose when null.
  final void Function(String? walletName) onConnect;
  final bool isLoading;
  final String? error;

  /// Wallets detected in this browser.
  ///
  /// Empty on Android, where the system picker does the choosing and a single
  /// Connect button is the whole interaction.
  final List<WalletOption> wallets;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF9945FF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Assets.icons.solana.image(fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            wallets.length > 1 ? 'Choose a Wallet' : 'No Wallet Connected',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            wallets.length > 1
                ? 'Pick the wallet holding your xStocks'
                : 'Connect your Solana wallet to get started',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 20),

          // Error message
          if (error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                    ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // One button per detected wallet, or a single generic one where the
          // platform picks (Android) or nothing was detected.
          if (wallets.length > 1)
            for (final wallet in wallets) ...[
              _connectButton(
                label: wallet.name,
                icon: wallet.icon,
                onPressed: () => onConnect(wallet.name),
                filled: wallet == wallets.first,
              ),
              if (wallet != wallets.last) const SizedBox(height: 10),
            ]
          else
            _connectButton(
              label: isLoading ? 'Connecting…' : 'Connect Wallet',
              onPressed: () => onConnect(wallets.firstOrNull?.name),
              filled: true,
              showSpinner: isLoading,
            ),
        ],
      ),
    );
  }

  Widget _connectButton({
    required String label,
    required VoidCallback onPressed,
    required bool filled,
    String? icon,
    bool showSpinner = false,
  }) {
    // The icon is a data URI the wallet itself supplies, so it gets a fixed
    // box and is allowed to fail quietly rather than shifting the layout.
    final leading = showSpinner
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textInverse,
            ),
          )
        : icon != null
            ? Image.network(
                icon,
                width: 20,
                height: 20,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.account_balance_wallet_outlined, size: 20),
              )
            : const Icon(Icons.link_rounded, size: 20);

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: leading,
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: filled ? AppColors.primary : AppColors.background,
          foregroundColor: filled ? AppColors.textInverse : AppColors.textPrimary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: filled ? null : const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
