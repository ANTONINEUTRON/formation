import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:symbians/core/route/app_route.dart';
import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/widgets/loading_indicator.dart';
import 'package:symbians/features/profile/ui/cubits/profile_cubit.dart';
import 'package:symbians/features/profile/ui/cubits/profile_state.dart';
import 'package:symbians/features/profile/ui/widgets/action_tile.dart';
import 'package:symbians/features/profile/ui/widgets/profile_card.dart';
import 'package:symbians/features/profile/ui/widgets/record_summary.dart';
import 'package:symbians/features/profile/ui/widgets/section_header.dart';
import 'package:symbians/features/profile/ui/widgets/token_balance.dart';
import 'package:symbians/features/profile/ui/widgets/trophy_case.dart';
import 'package:symbians/features/shared/data/formation_repository.dart';
import 'package:symbians/features/shared/domain/load_status.dart';
import 'package:symbians/features/wallet/ui/cubits/wallet_cubit.dart';
import 'package:symbians/features/wallet/ui/cubits/wallet_state.dart';
import 'package:symbians/features/wallet/ui/widgets/connect_wallet_view.dart';
import 'package:symbians/features/wallet/ui/widgets/connected_wallet_view.dart';
import 'package:symbians/gen/assets.gen.dart';

/// Profile: record across sports, trophy case, wallet and balances.
/// Opened from the avatar in the sport pages' app bar.
@RoutePage()
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProfileCubit(repository: context.read<FormationRepository>())..load(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Profile')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            ProfileCard(walletAddress: context.select<WalletCubit, String>((c) => c.state.walletAddress ?? '')),
            const SizedBox(height: 24),

            BlocBuilder<ProfileCubit, ProfileState>(
              builder: (context, state) {
                if (state.status != LoadStatus.success) {
                  return SizedBox(
                    height: 120,
                    child: state.status == LoadStatus.failure
                        ? Center(child: Text(state.error ?? 'Could not load record'))
                        : const LoadingIndicator(),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(title: 'Record'),
                    const SizedBox(height: 12),
                    RecordSummary(records: state.records),
                    const SizedBox(height: 24),
                    SectionHeader(title: 'Trophies'),
                    const SizedBox(height: 12),
                    TrophyCase(trophies: state.trophies),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Wallet section
            SectionHeader(title: 'Wallet'),
            const SizedBox(height: 12),
            BlocBuilder<WalletCubit, WalletState>(
              builder: (context, walletState) {
                if (walletState.isConnected) {
                  return ConnectedWalletView(
                    walletAddress: walletState.walletAddress!,
                    formattedAddress: context.read<WalletCubit>().formattedAddress,
                    isLoading: walletState.isLoading,
                    onDisconnect: () => context.read<WalletCubit>().disconnectWallet(),
                    onRefresh: () => context.read<WalletCubit>().fetchBalances(),
                  );
                }
                return ConnectWalletView(
                  isLoading: walletState.isLoading,
                  error: walletState.error,
                  onConnect: () => context.read<WalletCubit>().connectWallet(),
                );
              },
            ),
            const SizedBox(height: 24),

            // Token balances
            SectionHeader(title: 'Balances'),
            const SizedBox(height: 12),
            BlocBuilder<WalletCubit, WalletState>(
              builder: (context, walletState) {
                String bal(String currency, int decimals) {
                  if (walletState.isLoadingBalances) return '…';
                  final b = walletState.balances.where((b) => b.currency == currency).firstOrNull;
                  if (b == null) return '--';
                  return b.amount.toStringAsFixed(decimals);
                }

                return Column(
                  children: [
                    TokenBalance(
                      symbol: 'SOL',
                      name: 'Solana',
                      balance: bal('SOL', 4),
                      assetImage: Assets.icons.solana,
                      color: const Color(0xFF9945FF),
                    ),
                    const SizedBox(height: 8),
                    TokenBalance(
                      symbol: 'USDC',
                      name: 'USD Coin',
                      balance: bal('USDC', 2),
                      assetImage: Assets.icons.usdc,
                      color: const Color(0xFF2775CA),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            SectionHeader(title: 'Account'),
            const SizedBox(height: 12),
            ActionTile(
              icon: Icons.receipt_long_outlined,
              title: 'Transaction history',
              onTap: () => context.router.push(const TransactionHistoryRoute()),
            ),
          ],
        ),
      ),
    );
  }
}
