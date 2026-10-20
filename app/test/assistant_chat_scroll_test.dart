import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:formation/features/assistant_manager/domain/assistant_models.dart';
import 'package:formation/features/assistant_manager/ui/assistant_sheet.dart';
import 'package:formation/features/assistant_manager/ui/cubits/assistant_cubit.dart';
import 'package:formation/features/shared/data/fixture_repository.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/domain/models.dart';

const _team = AssistantContext(mode: SportMode.basketball);

/// Some of the sheet keeps moving (the character, the glow), so it never
/// settles. An animation starts on the frame after it's asked for, then
/// a second is plenty for any scroll.
Future<void> _wait(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(seconds: 1));
}

Finder _onScreen(String text) => find.textContaining(text, findRichText: true).hitTestable();

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('the chat opens on the latest message and follows each new one', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repository = FixtureRepository(walletAddress: 'w');
    final cubit = AssistantCubit(repository: repository);
    addTearDown(cubit.close);
    // The demo repository waits on real timers, which a widget test only runs here.
    await tester.runAsync(() async {
      await cubit.load();
      await cubit.pickCharacter('mentor');
    });
    // A conversation far longer than the screen.
    for (var i = 0; i < 12; i++) {
      cubit.explain(SportMode.basketball, question: 'Question $i?', answer: 'Answer number $i, at some length to fill the screen.');
    }

    await tester.pumpWidget(
      RepositoryProvider<FormationRepository>.value(
        value: repository,
        child: MaterialApp(
          // Reduced motion: the character's idle bob would otherwise never settle.
          builder: (context, child) =>
              MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
          home: Scaffold(
            body: BlocProvider.value(value: cubit, child: const AssistantSheet(context: _team)),
          ),
        ),
      ),
    );
    await tester.pump();
    await _wait(tester);

    expect(_onScreen('Answer number 11'), findsOneWidget);
    expect(_onScreen('Answer number 0'), findsNothing);

    // Scrolled back up, a new answer still brings the Manager down to it.
    await tester.drag(find.byType(ListView).first, const Offset(0, 600));
    await _wait(tester);
    expect(_onScreen('Answer number 11'), findsNothing);

    cubit.explain(SportMode.basketball, question: 'One more?', answer: 'The very latest answer.');
    await tester.pump();
    await _wait(tester);
    expect(_onScreen('The very latest answer.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox()); // stop the looping animations
  });
}
