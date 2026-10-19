import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:formation/features/feedback/domain/feedback.dart';
import 'package:formation/features/feedback/ui/feedback_sheet.dart';
import 'package:formation/features/shared/data/fixture_repository.dart';

Future<void> _open(WidgetTester tester, FixtureRepository repository, {String? email}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => FeedbackSheet.show(context, repository: repository, replyEmail: email),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('sends a rated bug report and says where the reply goes', (tester) async {
    final repository = FixtureRepository(walletAddress: 'w');
    await _open(tester, repository, email: 'me@example.com');
    expect(find.text("We'll reply to me@example.com."), findsOneWidget);

    // Nothing to send until there's a message.
    final send = find.widgetWithText(FilledButton, 'Send');
    expect(tester.widget<FilledButton>(send).onPressed, isNull);

    await tester.tap(find.text('Bug'));
    await tester.pump();
    expect(find.text(FeedbackKind.bug.hint), findsOneWidget);
    await tester.tap(find.byTooltip('4 of 5'));
    await tester.enterText(find.byType(TextField), 'The chart stays blank');
    await tester.pump();
    await tester.tap(send);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 4)); // the thank-you toast

    expect(repository.sentFeedback.single, (
      kind: FeedbackKind.bug,
      message: 'The chart stays blank',
      rating: 4,
      screenshot: false,
    ));
    expect(find.text('Send feedback'), findsNothing); // closed
  });

  testWidgets('without a profile email it says how to get a reply, and a second tap clears the rating', (tester) async {
    final repository = FixtureRepository(walletAddress: 'w');
    await _open(tester, repository);
    expect(find.text("Add an email to your profile if you'd like a reply."), findsOneWidget);

    await tester.tap(find.byTooltip('3 of 5'));
    await tester.tap(find.byTooltip('3 of 5'));
    await tester.enterText(find.byType(TextField), 'More sports please');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 4));
    expect(repository.sentFeedback.single.rating, isNull);
    expect(repository.sentFeedback.single.kind, FeedbackKind.idea); // the default
  });

  test('the demo keeps the server rules', () async {
    final repository = FixtureRepository(walletAddress: 'w');
    expect(() => repository.sendFeedback(kind: FeedbackKind.bug, message: 'no'), throwsA(isA<Exception>()));
    expect(
      () => repository.sendFeedback(kind: FeedbackKind.bug, message: 'Broken', rating: 6),
      throwsA(isA<Exception>()),
    );
    expect(
      () => repository.sendFeedback(
        kind: FeedbackKind.bug,
        message: 'Broken',
        screenshot: Uint8List(FeedbackLimits.maxScreenshotBytes + 1),
        screenshotMime: 'image/png',
      ),
      throwsA(isA<Exception>()),
    );
    for (var i = 0; i < FeedbackLimits.perHour; i++) {
      await repository.sendFeedback(kind: FeedbackKind.other, message: 'note $i');
    }
    expect(() => repository.sendFeedback(kind: FeedbackKind.other, message: 'one more'), throwsA(isA<Exception>()));
  });
}
