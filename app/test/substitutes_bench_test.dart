import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:formation/features/shared/data/fixtures/xstock_fixtures.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/shared/domain/roster_shapes.dart';
import 'package:formation/features/team/ui/widgets/substitutes_bench.dart';

Roster _withBench(SportMode mode, List<BenchSlot> bench) =>
    Roster(mode: mode, slots: emptyRoster(mode).slots, formation: emptyRoster(mode).formation, bench: bench);

BenchSlot _sub(String symbol, double balance, {List<int> eligible = const [0]}) => BenchSlot(
      stock: xStockFixtures.firstWhere((s) => s.symbol == symbol),
      balance: balance,
      eligibleSlots: eligible,
    );

Future<void> _pump(WidgetTester tester, Roster roster) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 420, child: SubstitutesBench(roster: roster, onAddStock: () {})),
        ),
      ),
    );

void main() {
  test('each sport has its fantasy bench size', () {
    expect(benchSpots(SportMode.football), 4);
    expect(benchSpots(SportMode.basketball), 3);
    expect(benchSpots(SportMode.americanFootball), 6);
  });

  testWidgets('fills the bench spots best first, and leaves the rest to add', (tester) async {
    await _pump(
      tester,
      _withBench(SportMode.football, [
        _sub('KOx', 1), // ~$70
        _sub('MSFTx', 2), // ~$1,024
        _sub('GMEx', 50), // ~$1,158, the most valuable
      ]),
    );
    expect(find.text('SUB 1'), findsOneWidget);
    expect(find.text('SUB 4'), findsOneWidget);
    // One empty spot after three held stocks.
    expect(find.text('Add'), findsNWidgets(1));

    final msft = tester.getTopLeft(find.text('MSFTx')).dx;
    final ko = tester.getTopLeft(find.text('KOx')).dx;
    final gme = tester.getTopLeft(find.text('GMEx')).dx;
    expect(gme < msft && msft < ko, isTrue);
    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('more holdings than spots shows how many are behind More', (tester) async {
    await _pump(
      tester,
      _withBench(SportMode.basketball, [for (final s in ['KOx', 'MSFTx', 'JPMx', 'Vx', 'PGx']) _sub(s, 1)]),
    );
    expect(find.text('SUB 3'), findsOneWidget);
    expect(find.text('SUB 4'), findsNothing);
    expect(find.text('More (5)'), findsOneWidget);
  });
}
