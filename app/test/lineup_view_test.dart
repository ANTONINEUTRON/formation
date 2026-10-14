import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:formation/features/draft/ui/widgets/formation_board.dart';
import 'package:formation/features/shared/data/fixtures/xstock_fixtures.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/shared/domain/roster_shapes.dart';
import 'package:formation/features/shared/ui/widgets/lineup_view.dart';
import 'package:formation/features/team/ui/widgets/roster_slot_card.dart';

/// A football team with a keeper and a striker picked.
Roster _team() {
  final empty = emptyRoster(SportMode.football);
  XStock pick(RiskTier tier) => xStockFixtures.firstWhere((s) => s.tier == tier);
  return Roster(
    mode: SportMode.football,
    formation: empty.formation,
    captainSlot: 0,
    slots: [
      for (final (i, slot) in empty.slots.indexed)
        i == 0
            ? RosterSlot(position: slot.position, stock: pick(RiskTier.blueChip), balance: 2)
            : i == empty.slots.length - 1
                ? RosterSlot(position: slot.position, stock: pick(RiskTier.momentum), balance: 1)
                : slot,
    ],
  );
}

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 420, child: child)))),
    );

void main() {
  testWidgets('shows the team on the pitch first, with the list one tap away', (tester) async {
    var edits = 0;
    await _pump(
      tester,
      LineupView(
        roster: _team(),
        ownTeam: true,
        action: (label: 'Pick team', icon: Icons.tune, onPressed: () => edits++),
      ),
    );

    expect(find.byType(FormationBoard), findsOneWidget);
    expect(find.text('Starting XI'), findsOneWidget);
    expect(find.text('4-4-2'), findsOneWidget);

    await tester.tap(find.text('Pick team'));
    expect(edits, 1);

    await tester.tap(find.byIcon(Icons.format_list_bulleted));
    await tester.pumpAndSettle();
    expect(find.byType(FormationBoard), findsNothing);
    // The Manager's own list includes every slot, filled or not.
    expect(find.byType(RosterSlotCard), findsNWidgets(11));

    // Back to the pitch for the next test (the choice lasts the session).
    await tester.tap(find.byIcon(Icons.stadium_outlined));
    await tester.pumpAndSettle();
  });

  testWidgets("another Manager's list shows only their picks", (tester) async {
    await _pump(tester, LineupView(roster: _team()));
    await tester.tap(find.byIcon(Icons.format_list_bulleted));
    await tester.pumpAndSettle();
    expect(find.byType(RosterSlotCard), findsNothing);
    final team = _team();
    expect(find.text(team.slots.first.stock!.symbol), findsOneWidget);
    expect(find.text(team.slots.last.stock!.symbol), findsOneWidget);
    await tester.tap(find.byIcon(Icons.stadium_outlined));
    await tester.pumpAndSettle();
  });

  testWidgets('pitch only has no toggle', (tester) async {
    await _pump(tester, LineupView(roster: _team(), title: 'Your squad', pitchOnly: true));
    expect(find.byType(FormationBoard), findsOneWidget);
    expect(find.byIcon(Icons.format_list_bulleted), findsNothing);
    expect(find.text('Your squad'), findsOneWidget);
  });
}
