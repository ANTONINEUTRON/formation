import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import 'package:formation/features/draft/ui/cubits/draft_cubit.dart';
import 'package:formation/features/draft/ui/widgets/buy_stock_sheet.dart';
import 'package:formation/features/shared/data/fixture_repository.dart';
import 'package:formation/features/shared/data/fixtures/xstock_fixtures.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/wallet/ui/cubits/wallet_cubit.dart';

const _wallet = 'TestWallet1111111111111111111111111111111';

/// Hydrated storage that lives only for the test.
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

void main() {
  setUpAll(() => HydratedBloc.storage = _MemoryStorage());

  /// Opens the real buy sheet the way the draft board does, at [size].
  Future<void> openBuySheet(WidgetTester tester, Size size, {double keyboard = 0}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);

    final repo = FixtureRepository(walletAddress: _wallet);
    final draft = DraftCubit(repository: repo, mode: SportMode.football);
    await tester.runAsync(draft.load);
    final stock = xStockFixtures.firstWhere((s) => s.symbol == 'AMDx');

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => WalletCubit()),
          BlocProvider.value(value: draft),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => BuyStockSheet.show(context, slotIndex: 0, stock: stock),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    // Fixture calls resolve on short timers; let the quote land.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  for (final entry in {
    'phone': (const Size(390, 844), BottomSheet),
    'desktop': (const Size(1440, 900), Dialog),
  }.entries) {
    testWidgets('the buy sheet opens and can be confirmed on a ${entry.key}', (tester) async {
      final (size, container) = entry.value;
      await openBuySheet(tester, size);

      expect(tester.takeException(), isNull);
      expect(find.text('Buy AMDx'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // A bottom sheet on a phone, a dialog on anything wider.
      expect(find.byType(container), findsOneWidget);

      final buy = find.widgetWithText(FilledButton, 'Buy & add to team');
      expect(buy, findsOneWidget);
      expect(tester.widget<FilledButton>(buy).onPressed, isNotNull,
          reason: 'with a quote in, the Buy button must be enabled');
    });
  }

  testWidgets('the Buy button stays above the keyboard on a phone', (tester) async {
    const phone = Size(390, 844);
    const keyboard = 336.0;
    await openBuySheet(tester, phone, keyboard: keyboard);

    expect(tester.takeException(), isNull);
    final button = find.widgetWithText(FilledButton, 'Buy & add to team');
    // Scroll it into view if the dialog had to shrink, as a player would.
    await tester.ensureVisible(button);
    await tester.pump();
    expect(tester.getRect(button).bottom, lessThanOrEqualTo(phone.height - keyboard),
        reason: 'the button the player came here to press must not sit under the keyboard');
  });
}
