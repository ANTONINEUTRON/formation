import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:formation/features/draft/ui/widgets/formation_board.dart';
import 'package:formation/features/shared/data/fixtures/xstock_fixtures.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/shared/domain/roster_shapes.dart';
import 'package:formation/features/team/ui/widgets/team_share_card.dart';

/// A full football XI, every slot picked.
Roster _fullTeam() {
  final empty = emptyRoster(SportMode.football);
  return Roster(
    mode: SportMode.football,
    formation: empty.formation,
    captainSlot: 0,
    classicPoints: 1234.5,
    classicRank: 7,
    slots: [
      for (final (i, slot) in empty.slots.indexed)
        RosterSlot(position: slot.position, stock: xStockFixtures[i % xStockFixtures.length], balance: 1),
    ],
  );
}

void main() {
  testWidgets('lays out the shared picture at its fixed size without overflowing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox.fromSize(
            size: TeamShareCard.size,
            child: TeamShareCard(
              roster: _fullTeam(),
              username: 'a_very_long_username_that_keeps_going',
              totalPlayers: 1520,
              streak: 12,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(FormationBoard), findsOneWidget);
    expect(find.text('#7 of 1520'), findsOneWidget);
    expect(find.text('12 days'), findsOneWidget);
  });
}
