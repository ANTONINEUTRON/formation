import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/features/credits/ui/cubits/credits_cubit.dart';
import 'package:symbians/features/credits/ui/cubits/credits_state.dart';
import 'package:symbians/features/credits/ui/widgets/buy_credits_modal.dart';
import 'package:symbians/features/profile/ui/widgets/action_tile.dart';
import 'package:symbians/features/profile/ui/widgets/profile_card.dart';
import 'package:symbians/features/profile/ui/widgets/section_header.dart';
import 'package:symbians/features/profile/ui/widgets/token_balance.dart';
import 'package:symbians/features/wallet/ui/cubits/wallet_cubit.dart';
import 'package:symbians/features/wallet/ui/cubits/wallet_state.dart';
import 'package:symbians/features/wallet/ui/widgets/connect_wallet_view.dart';
import 'package:symbians/features/wallet/ui/widgets/connected_wallet_view.dart';
import 'package:symbians/gen/assets.gen.dart';

/// Profile tab - displays user profile and wallet info.
class ProfileTabPage extends StatelessWidget {
  const ProfileTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Open settings
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16,16,16,85),
        children: [
          // Profile card
          ProfileCard(),
          const SizedBox(height: 24),

          // Wallet section
          SectionHeader(title: 'Wallet'),
          const SizedBox(height: 12),
          BlocBuilder<WalletCubit, WalletState>(
            builder: (context, walletState) {
              if (walletState.isConnected) {
                return ConnectedWalletView(
                  walletAddress: walletState.walletAddress!,
                  formattedAddress:
                      context.read<WalletCubit>().formattedAddress,
                  isLoading: walletState.isLoading,
                  onDisconnect: () =>
                      context.read<WalletCubit>().disconnectWallet(),
                  onRefresh: () =>
                      context.read<WalletCubit>().fetchBalances(),
                );
              }
              return ConnectWalletView(
                isLoading: walletState.isLoading,
                error: walletState.error,
                onConnect: () =>
                    context.read<WalletCubit>().connectWallet(),
              );
            },
          ),
          const SizedBox(height: 24),

          // Token balances
          SectionHeader(title: 'Balances'),
          const SizedBox(height: 12),
          BlocBuilder<WalletCubit, WalletState>(
            builder: (context, walletState) {
              String _bal(String currency, int decimals) {
                if (walletState.isLoadingBalances) return '…';
                final b = walletState.balances
                    .where((b) => b.currency == currency)
                    .firstOrNull;
                if (b == null) return '--';
                return b.amount.toStringAsFixed(decimals);
              }

              return Column(
                children: [
                  TokenBalance(
                    symbol: 'SOL',
                    name: 'Solana',
                    balance: _bal('SOL', 4),
                    assetImage: Assets.icons.solana,
                    color: const Color(0xFF9945FF),
                  ),
                  const SizedBox(height: 8),
                  TokenBalance(
                    symbol: 'USDC',
                    name: 'USD Coin',
                    balance: _bal('USDC', 2),
                    assetImage: Assets.icons.usdc,
                    color: const Color(0xFF2775CA),
                  ),
                  const SizedBox(height: 8),
                  TokenBalance(
                    symbol: 'SKR',
                    name: 'Seeker',
                    balance: _bal('SKR', 0),
                    assetImage: Assets.icons.seeker,
                    color: AppColors.primary,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Credits section
          SectionHeader(title: 'Credits'),
          const SizedBox(height: 12),
          BlocBuilder<CreditsCubit, CreditsState>(
            builder: (context, credits) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: credits.canSend
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.bolt_rounded,
                        color: credits.canSend
                            ? AppColors.primary
                            : AppColors.error,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${credits.balance} credits',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            credits.canSend
                                ? '1 credit per prompt'
                                : 'Out of credits — top up to continue',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: credits.canSend
                                      ? AppColors.textSecondary
                                      : AppColors.error,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => BuyCreditsModal.show(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textInverse,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Buy'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Actions
          SectionHeader(title: 'Account'),
          const SizedBox(height: 12),
          ActionTile(
            icon: Icons.security_outlined,
            title: 'Security',
            onTap: () {
              // TODO: Security settings
            },
          ),
          ActionTile(
            icon: Icons.delete_outline,
            title: 'Delete Account',
            isDestructive: true,
            onTap: () {
              _showDeleteConfirmation(context);
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete Account?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This action cannot be undone. All your data will be permanently deleted.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Delete account
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
