import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:symbians/core/constants/app_constants.dart';
import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/features/wallet/ui/cubits/wallet_cubit.dart';
import 'package:symbians/features/wallet/ui/cubits/wallet_state.dart';
import 'package:symbians/features/wallet/ui/widgets/connect_wallet_view.dart';
import 'package:symbians/gen/assets.gen.dart';

/// Full-screen onboarding page shown when no wallet is connected.
///
/// Not part of the auto_route router — rendered directly by [_AppGate]
/// in `app.dart` when [WalletState.isConnected] is false.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: BlocBuilder<WalletCubit, WalletState>(
            builder: (context, walletState) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Logo
                  Assets.brand.symbiansLogoNobg.image(
                    width: 88,
                    height: 88,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),

                  // App name
                  Text(
                    AppConstants.appName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 8),

                  // Tagline
                  Text(
                    AppConstants.appTagline,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                  ),

                  const Spacer(flex: 2),

                  // Connect wallet CTA
                  ConnectWalletView(
                    isLoading: walletState.isLoading,
                    error: walletState.error,
                    onConnect: () =>
                        context.read<WalletCubit>().connectWallet(),
                  ),

                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
