import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:auto_route/auto_route.dart';
import 'package:symbians/core/route/app_route.dart';
import 'package:symbians/core/theme/theme.dart';

/// Shown in the profile tab when a wallet is connected.
class ConnectedWalletView extends StatelessWidget {
  const ConnectedWalletView({
    super.key,
    required this.walletAddress,
    required this.formattedAddress,
    required this.onDisconnect,
    required this.onRefresh,
    this.isLoading = false,
  });

  final String walletAddress;

  /// Pre-truncated address, e.g. `ABCDEF...WXYZ`, from [WalletCubit.formattedAddress].
  final String formattedAddress;

  final VoidCallback onDisconnect;
  final VoidCallback onRefresh;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Address row
          Row(
            children: [
              // Wallet icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Label + address
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connected Wallet',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedAddress,
                      style: AppTextStyles.mono(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // Copy button
              IconButton(
                icon: const Icon(Icons.copy_outlined, size: 18),
                color: AppColors.textMuted,
                tooltip: 'Copy address',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: walletAddress));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Address copied'),
                      backgroundColor: AppColors.surface,
                    ),
                  );
                },
              ),

              // Refresh button
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  color: AppColors.textMuted,
                  tooltip: 'Refresh balances',
                  onPressed: onRefresh,
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.router.push(const TransactionHistoryRoute()),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('History'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : onDisconnect,
                  icon: const Icon(Icons.link_off, size: 18),
                  label: const Text('Disconnect'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
