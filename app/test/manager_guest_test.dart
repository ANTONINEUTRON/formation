import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:formation/features/managers/ui/pages/manager_profile_page.dart';
import 'package:formation/features/shared/data/fixture_repository.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/domain/models.dart';

void main() {
  testWidgets('a guest on a shared link sees the team and a way in, not follow or adopt', (tester) async {
    final repository = FixtureRepository(walletAddress: '');
    // The fixture repository waits on real timers, which fake test time never fires.
    final board = await tester.runAsync(() => repository.getLeaderboard(SportMode.basketball));
    final someone = board!.firstWhere((e) => !e.isCurrentUser);
    var played = 0;

    await tester.pumpWidget(
      RepositoryProvider<FormationRepository>.value(
        value: repository,
        child: MaterialApp(
          home: ManagerProfilePage(
            userId: someone.userId,
            modeName: 'basketball',
            guest: true,
            onPlay: () => played++,
          ),
        ),
      ),
    );
    // The fixture repository answers after a short delay; the spinner never
    // settles, so step time forward instead of waiting for it to stop.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(someone.username), findsWidgets);
    expect(find.textContaining('basketball team'), findsOneWidget);
    // Anyone's team can be shared from their page, the guest's view included.
    expect(find.byTooltip('Share this team'), findsOneWidget);
    expect(find.text('Follow'), findsNothing);
    expect(find.text('Adopt wallet'), findsNothing);

    await tester.ensureVisible(find.text('Play Formation'));
    await tester.tap(find.text('Play Formation'));
    expect(played, 1);
  });

  test('a link without a known sport falls back to football', () {
    expect(const ManagerProfilePage(userId: 'x', modeName: 'cricket').sport, SportMode.football);
    expect(const ManagerProfilePage(userId: 'x', modeName: 'american_football').sport, SportMode.americanFootball);
  });
}
