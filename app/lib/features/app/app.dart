import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart';

import 'package:symbians/core/constants/app_constants.dart';
import 'package:symbians/core/route/app_route.dart';
import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/features/credits/ui/cubits/credits_cubit.dart';
import 'package:symbians/features/onboarding/ui/pages/onboarding_page.dart';
import 'package:symbians/features/wallet/ui/cubits/wallet_cubit.dart';
import 'package:symbians/features/wallet/ui/cubits/wallet_state.dart';

/// Main application widget.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<WalletCubit>(create: (_) => WalletCubit()),
        BlocProvider<CreditsCubit>(create: (_) => CreditsCubit()),
      ],
      child: _AppGate(appRouter: _appRouter),
    );
  }
}

/// Switches between the onboarding screen and the full app shell
/// based on [WalletState.isConnected].
class _AppGate extends StatelessWidget {
  const _AppGate({required this.appRouter});

  final AppRouter appRouter;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletCubit, WalletState>(
      buildWhen: (prev, curr) => prev.isConnected != curr.isConnected,
      builder: (context, walletState) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: walletState.isConnected
              ? _ConnectedApp(key: const ValueKey('connected'), appRouter: appRouter)
              : _OnboardingApp(key: const ValueKey('onboarding')),
        );
      },
    );
  }
}

/// Full router-based app shell — shown when wallet is connected.
class _ConnectedApp extends StatelessWidget {
  const _ConnectedApp({super.key, required this.appRouter});

  final AppRouter appRouter;

  @override
  Widget build(BuildContext context) {
    return StyledToast(
      textStyle: const TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
      backgroundColor: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      textPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      toastPositions: StyledToastPosition.bottom,
      toastAnimation: StyledToastAnimation.fade,
      duration: const Duration(seconds: 3),
      child: MaterialApp.router(
        title: AppConstants.appName,
        theme: AppTheme.darkTheme,
        routerConfig: appRouter.config(),
        debugShowCheckedModeBanner: false,
        scrollBehavior: kIsWeb ? _WebScrollBehavior() : null,
        builder: (context, child) {
          if (kIsWeb && child != null) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: child,
              ),
            );
          }
          return child!;
        },
      ),
    );
  }
}

/// Bare app showing the onboarding screen — shown when wallet is disconnected.
class _OnboardingApp extends StatelessWidget {
  const _OnboardingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const OnboardingPage(),
    );
  }
}

/// Custom scroll behavior for web to enable mouse dragging.
class _WebScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}
