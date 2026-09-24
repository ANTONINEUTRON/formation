import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
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
  });

  final VoidCallback onConnect;
  final bool isLoading;
  final String? error;

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
            'No Wallet Connected',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            'Connect your Solana wallet to get started',
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

          // Connect button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isLoading ? null : onConnect,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textInverse,
                      ),
                    )
                  : const Icon(Icons.link_rounded, size: 20),
              label: Text(isLoading ? 'Connecting…' : 'Connect Wallet'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textInverse,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
