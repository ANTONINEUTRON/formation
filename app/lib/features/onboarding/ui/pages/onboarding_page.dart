import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/constants/app_constants.dart';
import 'package:formation/core/layout/breakpoints.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/assistant_manager/domain/assistant_models.dart';
import 'package:formation/features/assistant_manager/ui/widgets/character_view.dart';
import 'package:formation/features/onboarding/data/onboarding_prefs.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/wallet/ui/cubits/wallet_cubit.dart';
import 'package:formation/features/wallet/ui/cubits/wallet_state.dart';
import 'package:formation/features/wallet/ui/widgets/connect_wallet_view.dart';
import 'package:formation/gen/assets.gen.dart';

/// Full-screen onboarding page shown when no wallet is connected.
///
/// The first time, it's three short intro screens ending on the connect
/// button, the last of which lets the Manager pick their Assistant Manager.
/// After that, someone reconnecting a wallet sees only the connect screen.
///
/// Not part of the auto_route router — rendered directly by [_AppGate]
/// in `app.dart` when [WalletState.isConnected] is false.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.prefs});

  /// Injectable for tests.
  final OnboardingPrefs? prefs;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final OnboardingPrefs _prefs = widget.prefs ?? OnboardingPrefs();
  final _pages = PageController();
  bool? _introSeen;
  int _page = 0;
  String _character = 'mentor';

  @override
  void initState() {
    super.initState();
    _prefs.introSeen().then((seen) {
      if (mounted) setState(() => _introSeen = seen);
    });
    _prefs.pendingCharacter().then((id) {
      if (mounted && id != null) setState(() => _character = id);
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _pickCharacter(String id) {
    setState(() => _character = id);
    _prefs.setPendingCharacter(id);
  }

  Future<void> _connect(String? walletName) async {
    if (_introSeen == false) {
      await _prefs.setPendingCharacter(_character);
      await _prefs.markIntroSeen();
    }
    if (mounted) await context.read<WalletCubit>().connectWallet(walletName: walletName);
  }

  @override
  Widget build(BuildContext context) {
    final seen = _introSeen;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: seen == null
            ? const SizedBox.shrink()
            : seen
            ? _ConnectOnly(onConnect: _connect)
            : context.layoutSize.isCompact
            ? _Carousel(
                controller: _pages,
                page: _page,
                onPage: (p) => setState(() => _page = p),
                character: _character,
                onCharacter: _pickCharacter,
                onConnect: _connect,
              )
            : _Wide(character: _character, onCharacter: _pickCharacter, onConnect: _connect),
      ),
    );
  }
}

/// Phone: one intro screen at a time, Skip / Next, connect on the last.
class _Carousel extends StatelessWidget {
  const _Carousel({
    required this.controller,
    required this.page,
    required this.onPage,
    required this.character,
    required this.onCharacter,
    required this.onConnect,
  });

  final PageController controller;
  final int page;
  final ValueChanged<int> onPage;
  final String character;
  final ValueChanged<String> onCharacter;
  final Future<void> Function(String?) onConnect;

  @override
  Widget build(BuildContext context) {
    final last = page == 2;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: AnimatedOpacity(
            opacity: last ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: TextButton(
              onPressed: last
                  ? null
                  : () => controller.animateToPage(
                      2,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                    ),
              child: const Text('Skip'),
            ),
          ),
        ),
        Expanded(
          child: PageView(
            controller: controller,
            onPageChanged: onPage,
            children: [
              const _IntroPlayers(),
              const _IntroScoring(),
              _IntroAssistant(selected: character, onSelected: onCharacter),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == page ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
          child: last
              ? _Connect(onConnect: onConnect)
              : SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => controller.nextPage(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                    ),
                    child: const Text('Next'),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Desktop: all three side by side, connect underneath.
class _Wide extends StatelessWidget {
  const _Wide({required this.character, required this.onCharacter, required this.onConnect});

  final String character;
  final ValueChanged<String> onCharacter;
  final Future<void> Function(String?) onConnect;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            children: [
              const _Brand(),
              const SizedBox(height: 32),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Expanded(child: _Panel(child: _IntroPlayers())),
                    const SizedBox(width: 16),
                    const Expanded(child: _Panel(child: _IntroScoring())),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _Panel(
                        child: _IntroAssistant(selected: character, onSelected: onCharacter),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _Connect(onConnect: onConnect),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// The original screen, for a Manager who has seen the intro.
class _ConnectOnly extends StatelessWidget {
  const _ConnectOnly({required this.onConnect});

  final Future<void> Function(String?) onConnect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),
          const _Brand(),
          const Spacer(flex: 2),
          _Connect(onConnect: onConnect),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Assets.brand.formationLogoNobg.image(width: 88, height: 88, fit: BoxFit.contain),
        const SizedBox(height: 24),
        Text(
          AppConstants.appName,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppConstants.appTagline,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.5),
        ),
      ],
    );
  }
}

class _Connect extends StatelessWidget {
  const _Connect({required this.onConnect});

  final Future<void> Function(String?) onConnect;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletCubit, WalletState>(
      builder: (context, wallet) => ConnectWalletView(
        isLoading: wallet.isLoading,
        error: wallet.error,
        wallets: wallet.wallets,
        onConnect: onConnect,
      ),
    );
  }
}

// ── The three screens ─────────────────────────────────────────────────────────

class _IntroScreen extends StatelessWidget {
  const _IntroScreen({required this.visual, required this.title, required this.body});

  final Widget visual;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          visual,
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _IntroPlayers extends StatelessWidget {
  const _IntroPlayers();

  @override
  Widget build(BuildContext context) {
    return _IntroScreen(
      visual: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final (position, tier, symbol) in [
              ('GK', RiskTier.blueChip, 'AAPLx'),
              ('DEF', RiskTier.stable, 'KOx'),
              ('MID', RiskTier.balanced, 'JPMx'),
              ('FWD', RiskTier.momentum, 'TSLAx'),
            ])
              Container(
                width: 70,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tier.color.withValues(alpha: 0.7)),
                  color: AppColors.surfaceElevated,
                ),
                child: Column(
                  children: [
                    Text(
                      position,
                      style: TextStyle(fontSize: 10, color: tier.color, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(symbol, style: AppTextStyles.mono(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
      ),
      title: 'Your stocks are your players',
      body:
          'Pick real tokenized stocks for each position in your team. Every position suits one kind '
          'of stock: steady names at the back, bolder ones up front.',
    );
  }
}

class _IntroScoring extends StatelessWidget {
  const _IntroScoring();

  @override
  Widget build(BuildContext context) {
    return const _IntroScreen(
      visual: Padding(
        padding: EdgeInsets.only(top: 40),
        child: Icon(Icons.trending_up, size: 88, color: AppColors.primary),
      ),
      title: 'You score when they beat the market',
      body:
          'Points come from beating the S&P 500, not just rising with it. Name a captain for bonus '
          'points, make 3 free substitutions a day, and climb the table or take on your friends.',
    );
  }
}

class _IntroAssistant extends StatelessWidget {
  const _IntroAssistant({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final current = presetCharacters.firstWhere(
      (c) => c.id == selected,
      orElse: () => presetCharacters.first,
    );
    return _IntroScreen(
      visual: Column(
        children: [
          CharacterFigure(character: current, pose: AssistantPose.celebrating, height: 170),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final c in presetCharacters)
                Semantics(
                  button: true,
                  selected: c.id == selected,
                  label: c.name,
                  child: GestureDetector(
                    onTap: () => onSelected(c.id),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: c.id == selected ? 1 : 0.5,
                      child: CharacterHead(
                        character: c,
                        pose: AssistantPose.neutral,
                        size: c.id == selected ? 48 : 40,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            current.name,
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          Text(current.tagline, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
      title: 'Pick your Assistant Manager',
      body:
          'They review your squad, answer your questions and suggest moves. You always make the '
          'call. Your first squad is on them.',
    );
  }
}
