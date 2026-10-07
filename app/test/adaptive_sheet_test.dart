import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:formation/core/widgets/adaptive_sheet.dart';

/// The shapes the real sheets actually have.
///
/// Every one of these opened fine as a bottom sheet and then silently failed
/// as a dialog, because the dialog wrapped them in an `IntrinsicHeight` —
/// which asks a scrollable for a height it cannot answer. The sheet threw
/// during layout instead of appearing, so tapping a player or Edit profile
/// did nothing at all on desktop. These cases exist so that cannot come back.
void main() {
  Future<void> pumpAndOpen(
    WidgetTester tester, {
    required Size size,
    required Widget child,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showAdaptiveSheet<void>(
                  context: context,
                  builder: (_) => child,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  const phone = Size(390, 844);
  const desktop = Size(1440, 900);

  /// A Column with mainAxisSize.min — SlotActionsSheet.
  const minColumn = Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [Text('sheet content'), ListTile(title: Text('an action'))],
  );

  /// A scroll view that sizes to its content — EditProfileSheet, BuyStockSheet.
  const scrollView = SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Text('sheet content'), TextField()],
    ),
  );

  /// A header over a flexible list — StockPickerSheet's body.
  final flexibleList = Column(
    children: [
      const Text('sheet content'),
      Expanded(
        child: ListView(
          children: List.generate(40, (i) => ListTile(title: Text('row $i'))),
        ),
      ),
    ],
  );

  final shapes = <String, Widget>{
    'a Column with mainAxisSize.min': minColumn,
    'a SingleChildScrollView': scrollView,
    'a header over a flexible list': flexibleList,
  };

  for (final entry in shapes.entries) {
    testWidgets('opens ${entry.key} on a phone', (tester) async {
      await pumpAndOpen(tester, size: phone, child: entry.value);

      expect(tester.takeException(), isNull);
      expect(find.text('sheet content'), findsOneWidget);
      // Bottom sheet on a phone: the thumb is at the bottom of the screen.
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('opens ${entry.key} on a desktop window', (tester) async {
      await pumpAndOpen(tester, size: desktop, child: entry.value);

      expect(tester.takeException(), isNull);
      expect(find.text('sheet content'), findsOneWidget);
      // Centred dialog on a wide window, not a strip pinned to the bottom
      // edge of a tall window miles from the pointer.
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    });
  }

  testWidgets('a desktop dialog stays within a readable width', (tester) async {
    await pumpAndOpen(tester, size: desktop, child: minColumn);

    // The card itself, not the Dialog's own box — that one fills the window
    // and centres the card inside it.
    final card = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(Material),
    );

    // Wide enough for the content, nowhere near the 1440 the window offers:
    // these sheets were laid out for a phone and stretching them only spreads
    // their rows apart.
    expect(tester.getSize(card.first).width, lessThanOrEqualTo(460));
  });

  testWidgets('a phone sheet lifts clear of the keyboard', (tester) async {
    const keyboard = 336.0;

    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1.0;
    // Set on the view, not in a MediaQuery around the Scaffold: the sheet is
    // pushed onto the Navigator, which sits above anything the home widget
    // wraps, so it only sees insets that come from the view itself.
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showAdaptiveSheet<void>(
                  context: context,
                  // The buy sheet autofocuses its amount field, so the
                  // keyboard is up before the player has done anything — and
                  // the Buy button is the thing at the bottom.
                  builder: (_) => const SizedBox(
                    height: 200,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Text('buy button'),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final bottom = tester.getRect(find.text('buy button')).bottom;
    expect(bottom, lessThanOrEqualTo(phone.height - keyboard),
        reason: 'the sheet must sit above the keyboard, not under it');
  });
}
