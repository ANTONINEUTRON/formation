import 'package:flutter_test/flutter_test.dart';

import 'package:symbians/features/shared/data/fixture_repository.dart';
import 'package:symbians/features/shared/data/fixtures/xstock_fixtures.dart';
import 'package:symbians/features/shared/domain/lineup.dart';
import 'package:symbians/features/shared/domain/models.dart';
import 'package:symbians/features/shared/domain/roster_shapes.dart';

const _wallet = 'TestWallet1111111111111111111111111111111';

void main() {
  group('roster shapes', () {
    test('slot counts per mode', () {
      expect(rosterShape(SportMode.basketball), hasLength(5));
      expect(rosterShape(SportMode.football), hasLength(11)); // 11 starters
      expect(rosterShape(SportMode.americanFootball), hasLength(9));
    });

    test('football shape follows the formation', () {
      expect(
        rosterShape(SportMode.football, '3-5-2').map((s) => s.label),
        ['GK', 'DEF', 'DEF', 'DEF', 'MID', 'MID', 'MID', 'MID', 'MID', 'FWD', 'FWD'],
      );
      expect(rosterShape(SportMode.football, '5-4-1').where((s) => s.label == 'DEF'), hasLength(5));
    });

    test('every shape can be filled from the pool without duplicates', () {
      for (final mode in SportMode.values) {
        for (final formation in [null, '3-4-3', '5-2-3']) {
          if (mode != SportMode.football && formation != null) continue;
          final used = <String>{};
          for (final position in rosterShape(mode, formation)) {
            final pick = xStockFixtures.firstWhere(
              (s) => position.accepts(s) && !used.contains(s.mint),
              orElse: () => fail('No stock left for ${position.label} in $mode'),
            );
            used.add(pick.mint);
          }
        }
      }
    });

    test('board positions are normalized', () {
      for (final mode in SportMode.values) {
        for (final p in rosterShape(mode)) {
          expect(p.boardPosition.dx, inInclusiveRange(0, 1));
          expect(p.boardPosition.dy, inInclusiveRange(0, 1));
        }
      }
    });
  });

  group('formations', () {
    test('only FPL-legal shapes are offered', () {
      expect(footballFormations.every((f) => f.isValid), isTrue);
      expect(footballFormations.map((f) => f.name), contains('4-4-2'));
      expect(const Formation(2, 5, 3).isValid, isFalse);
      expect(const Formation(4, 4, 3).isValid, isFalse);
    });

    test('roles run GK, defenders, midfielders, forwards', () {
      expect(footballRoles('4-4-2').first, 'GK');
      expect(footballRoles('4-4-2').where((r) => r == 'MID'), hasLength(4));
    });

    test('preview keeps picks in role order and reports the drops', () {
      // 4-4-2: 0 GK, 1-4 DEF, 5-8 MID, 9-10 FWD
      final picks = {
        0: 'gk', 1: 'd1', 2: 'd2', 3: 'd3', 4: 'd4',
        5: 'm1', 6: 'm2', 7: 'm3', 8: 'm4', 9: 'f1', 10: 'f2',
      };
      final preview = previewFormationChange(from: '4-4-2', to: '3-5-2', picks: picks);

      expect(preview.dropped, ['d4']);
      expect(preview.kept[3], 'd3');
      expect(preview.kept[4], 'm1'); // midfield starts a slot earlier
      expect(preview.kept.containsKey(8), isFalse); // the new midfield slot is empty
      expect(preview.kept[9], 'f1');
    });

    test('preview drops a forward when the defence grows', () {
      final picks = {for (var i = 0; i < 11; i++) i: 'p$i'};
      final preview = previewFormationChange(from: '4-4-2', to: '5-4-1', picks: picks);
      expect(preview.dropped, ['p10']);
    });
  });

  group('FixtureRepository', () {
    test('seeded football team is complete, captained and tier-valid', () async {
      final repo = FixtureRepository(walletAddress: _wallet);
      final roster = await repo.getRoster(SportMode.football);

      expect(roster.isComplete, isTrue);
      expect(roster.formation, '4-4-2');
      expect(roster.captainSlot, 9);
      expect(roster.armband(9), 'C');
      expect(roster.armband(0), 'V');
      for (final slot in roster.slots) {
        expect(slot.position.accepts(slot.stock!), isTrue, reason: slot.position.label);
      }
      expect(roster.classicRank, isNotNull);
      expect(roster.gameweek, isNotNull);
    });

    test('filling a held stock updates the team and the leaderboard', () async {
      final repo = FixtureRepository(walletAddress: _wallet);
      final nvda = xStockFixtures.firstWhere((s) => s.symbol == 'NVDAx');
      final roster = await repo.fillSlot(SportMode.basketball, 0, nvda);

      expect(roster.slots.first.stock, nvda);
      final board = await repo.getLeaderboard(SportMode.basketball);
      expect(board.where((e) => e.isCurrentUser), hasLength(1));
    });

    test('rejects an unheld or ineligible stock', () async {
      final repo = FixtureRepository(walletAddress: _wallet);
      final unheld = xStockFixtures.firstWhere((s) => s.symbol == 'AMDx');
      final wrongTier = xStockFixtures.firstWhere((s) => s.symbol == 'KOx');
      expect(repo.fillSlot(SportMode.basketball, 0, unheld), throwsStateError);
      expect(repo.fillSlot(SportMode.basketball, 0, wrongTier), throwsStateError);
    });

    test('buying then filling works for an unheld stock', () async {
      final repo = FixtureRepository(walletAddress: _wallet);
      final amd = xStockFixtures.firstWhere((s) => s.symbol == 'AMDx');
      final quote = await repo.getSwapQuote(amd, 10);
      expect(quote.platformFeeUsdc, closeTo(0.03, 1e-9));

      await repo.executeSwap(quote);
      final roster = await repo.fillSlot(SportMode.basketball, 0, amd);
      expect(roster.slots.first.balance, closeTo(quote.estimatedShares, 1e-9));
    });

    test('changing formation drops the picks that no longer fit', () async {
      final repo = FixtureRepository(walletAddress: _wallet);
      final before = await repo.getRoster(SportMode.football);
      final change = await repo.setFormation(SportMode.football, '3-5-2');

      expect(change.roster.formation, '3-5-2');
      expect(change.dropped, hasLength(1));
      expect(change.dropped.first.tier, RiskTier.stable); // the fourth defender
      expect(change.roster.slots.where((s) => s.isFilled), hasLength(10));
      expect(change.roster.isComplete, isFalse);
      // The captain's stock kept its place, so the armband moved with it.
      expect(
        change.roster.slots[change.roster.captainSlot!].stock!.symbol,
        before.slots[before.captainSlot!].stock!.symbol,
      );
    });

    test('captaincy is validated per sport', () async {
      final repo = FixtureRepository(walletAddress: _wallet);
      final roster = await repo.setCaptaincy(SportMode.football, captainSlot: 5, viceCaptainSlot: 1);
      expect(roster.captainSlot, 5);
      expect(roster.viceCaptainSlot, 1);

      expect(
        repo.setCaptaincy(SportMode.football, captainSlot: 3, viceCaptainSlot: 3),
        throwsStateError,
      );
      expect(
        repo.setCaptaincy(SportMode.americanFootball, captainSlot: 0),
        throwsStateError,
      );
      // An empty slot can't wear the armband.
      expect(repo.setCaptaincy(SportMode.basketball, captainSlot: 0), throwsStateError);
    });

    test('a tick scores the live gameweek and advancing banks it', () async {
      final repo = FixtureRepository(walletAddress: _wallet);
      await repo.runTick();
      final live = await repo.getRoster(SportMode.football);
      expect(live.gameweek!.slots, hasLength(11));
      expect(live.gameweek!.entered, isTrue);

      await repo.advanceGameweek(SportMode.football);
      final next = await repo.getRoster(SportMode.football);

      expect(next.gameweek!.number, live.gameweek!.number + 1);
      // The finished gameweek is banked into the season total, and only the
      // new gameweek's points (clean sheets from an unchanged price) sit on top.
      expect(
        next.classicPoints,
        closeTo(live.classicPoints + next.gameweek!.points, 0.01),
      );
    });

    test('settling a duel picks the higher score and awards a trophy', () async {
      final repo = FixtureRepository(walletAddress: _wallet);
      final settled = await repo.settleDuel('duel-1');

      expect(settled.status, DuelStatus.settled);
      expect(settled.iWon, isTrue); // seeded 34 vs 21 points
      expect(await repo.getTrophies(), hasLength(2));
    });
  });
}
