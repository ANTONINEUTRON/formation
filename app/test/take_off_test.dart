import 'package:flutter_test/flutter_test.dart';

import 'package:formation/features/draft/ui/widgets/slot_actions_sheet.dart';
import 'package:formation/features/shared/data/fixture_repository.dart';
import 'package:formation/features/shared/data/fixtures/xstock_fixtures.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/shared/domain/roster_shapes.dart';

Session _session({int freeLeft = 3, bool window = false}) => Session(
      startsAt: DateTime(2026, 11, 2),
      endsAt: DateTime(2026, 11, 3),
      entered: true,
      points: 0,
      slots: const [],
      teamEvents: const [],
      substitutionsUsed: 3 - freeLeft,
      freeSubstitutionsLeft: freeLeft,
      transferWindowOpen: window,
    );

void main() {
  final stock = xStockFixtures.first;
  final empty = emptyRoster(SportMode.basketball);
  RosterSlot held(double balance) => RosterSlot(position: empty.slots.first.position, stock: stock, balance: balance);
  Roster with_(Session? session) => Roster(mode: SportMode.basketball, slots: empty.slots, session: session);

  test('says what taking a pick off will cost', () {
    expect(takeOffCost(with_(_session(freeLeft: 2)), held(3)), 'Uses 1 of your 2 free substitutions today');
    expect(takeOffCost(with_(_session(freeLeft: 1)), held(3)), 'Uses 1 of your 1 free substitution today');
    expect(takeOffCost(with_(_session(freeLeft: 0)), held(3)), 'Costs 4 points: no free substitutions left today');
    expect(takeOffCost(with_(_session(freeLeft: 0, window: true)), held(3)), 'Free: the transfer window is open');
    expect(takeOffCost(with_(_session()), held(0)), 'Free: it is no longer in your wallet');
  });

  test('taking a pick off empties its position and passes the armband to the vice-captain', () async {
    final repository = FixtureRepository(walletAddress: 'w');
    final roster = await repository.getRoster(SportMode.football);
    final filled = [for (var i = 0; i < roster.slots.length; i++) if (roster.slots[i].isFilled) i];
    expect(filled.length, greaterThanOrEqualTo(2), reason: 'the fixture team starts with picks');

    await repository.setCaptaincy(SportMode.football, captainSlot: filled[0], viceCaptainSlot: filled[1]);
    final after = await repository.clearSlot(SportMode.football, filled[0]);

    expect(after.slots[filled[0]].isFilled, isFalse);
    expect(after.captainSlot, filled[1]);
    expect(after.viceCaptainSlot, isNull);
    await expectLater(repository.clearSlot(SportMode.football, filled[0]), throwsA(anything));
  });
}
