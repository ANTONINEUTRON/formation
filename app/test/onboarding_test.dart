import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import 'package:formation/features/assistant_manager/domain/assistant_models.dart';
import 'package:formation/features/onboarding/data/onboarding_prefs.dart';
import 'package:formation/features/onboarding/ui/pages/onboarding_page.dart';
import 'package:formation/features/shared/data/fixture_repository.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/wallet/ui/cubits/wallet_cubit.dart';

/// Hydrated storage that lives only for the test (WalletCubit persists itself).
class _MemoryStorage implements Storage {
  final _values = <String, dynamic>{};
  @override
  dynamic read(String key) => _values[key];
  @override
  Future<void> write(String key, dynamic value) async => _values[key] = value;
  @override
  Future<void> delete(String key) async => _values.remove(key);
  @override
  Future<void> clear() async => _values.clear();
  @override
  Future<void> close() async {}
}

/// In-memory prefs, so tests don't touch the device.
class _Prefs extends OnboardingPrefs {
  _Prefs({this.seen = false});

  bool seen;
  String? character;

  @override
  Future<bool> introSeen() async => seen;
  @override
  Future<void> markIntroSeen() async => seen = true;
  @override
  Future<String?> pendingCharacter() async => character;
  @override
  Future<void> setPendingCharacter(String id) async => character = id;
}

Future<void> _pump(WidgetTester tester, _Prefs prefs) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    BlocProvider(
      create: (_) => WalletCubit(),
      child: MaterialApp(
        // Reduced motion: the character's idle bob would otherwise never settle.
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: OnboardingPage(prefs: prefs),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() => HydratedBloc.storage = _MemoryStorage());

  testWidgets('a first visit walks through three screens to the connect button', (tester) async {
    final prefs = _Prefs();
    await _pump(tester, prefs);

    expect(find.text('Your stocks are your players'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Beat the market, score points'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Meet your Assistant Manager'), findsOneWidget);

    // Picking a character is remembered until there's a session to save it to.
    await tester.tap(find.bySemanticsLabel('The Maverick'));
    await tester.pumpAndSettle();
    expect(prefs.character, 'maverick');
    expect(find.text('Bold, playful, backs momentum.'), findsOneWidget);
  });

  testWidgets('a returning Manager goes straight to connecting', (tester) async {
    await _pump(tester, _Prefs(seen: true));
    expect(find.text('Your stocks are your players'), findsNothing);
    expect(find.text('Next'), findsNothing);

    // The rules are readable before connecting, without an Assistant Manager.
    await tester.ensureVisible(find.text('How the game works'));
    await tester.tap(find.text('How the game works'));
    await tester.pumpAndSettle();
    expect(find.text('How to play'), findsOneWidget);
    expect(find.text('Ask your Assistant Manager'), findsNothing);
  });

  test('"Use what I hold" fields an empty team from the wallet, once', () async {
    final repository = FixtureRepository(walletAddress: 'w');
    final team = await repository.fillFromHoldings(SportMode.basketball);
    expect(team.slots.where((s) => s.isFilled), isNotEmpty);
    expect(team.captainSlot, isNotNull);
    await expectLater(repository.fillFromHoldings(SportMode.basketball), throwsA(isA<Exception>()));
  });

  group('starter squad (fixture backend)', () {
    test('pays every draft from the one credit balance', () async {
      final repository = FixtureRepository(walletAddress: 'w');
      final welcome = await repository.getAssistant();
      expect(welcome.credits, 11);
      expect(welcome.canAffordDraft, isTrue);

      final first = await repository.draftStarterSquad(SportMode.basketball, budgetUsd: 10);
      expect(first.picks, hasLength(5));
      expect(first.picks.map((p) => p.mint).toSet(), hasLength(5));
      expect(first.draftsLeft, 2); // 8 credits left
      // Held stocks cost nothing; the budget is shared by the rest.
      expect(first.picks.where((p) => !p.needsPurchase).every((p) => p.amountUsd == 0), isTrue);

      await repository.draftStarterSquad(SportMode.basketball, budgetUsd: 10);
      final third = await repository.draftStarterSquad(SportMode.basketball, budgetUsd: 10);
      expect(third.draftsLeft, 0);
      final after = await repository.getAssistant();
      expect(after.credits, 2);
      expect(after.canAffordDraft, isFalse);
      expect(
        () => repository.draftStarterSquad(SportMode.basketball, budgetUsd: 10),
        throwsA(isA<Exception>()),
      );
    });

    test('parses the backend squad', () {
      final squad = StarterSquad.fromJson({
        'mode': 'football',
        'formation': '4-3-3',
        'captainSlot': 9,
        'viceCaptainSlot': 0,
        'picks': [
          {
            'slotIndex': 0,
            'position': 'GK',
            'mint': 'm',
            'symbol': 'AAPLx',
            'name': 'Apple',
            'tier': 'balanced',
            'priceUsd': 230,
            'reason': 'Steady hands',
            'needsPurchase': true,
            'amountUsd': 2.5,
          },
        ],
        'text': 'Welcome.',
        'budgetUsd': 30,
        'skrUsd': 0.02,
        'draftsLeft': 1,
      });
      expect(squad.mode, SportMode.football);
      expect(squad.picks.single.tier, RiskTier.balanced);
      expect(squad.toSpendUsd, 2.5);
    });
  });
}
