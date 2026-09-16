import 'package:flutter_test/flutter_test.dart';

import 'package:symbians/features/shared/data/fixture_repository.dart';
import 'package:symbians/features/shared/data/fixtures/xstock_fixtures.dart';
import 'package:symbians/features/shared/domain/lineup.dart';
import 'package:symbians/features/shared/domain/models.dart';
import 'package:symbians/features/shared/domain/roster_shapes.dart';
import 'package:symbians/features/shared/domain/scoring.dart';

void main() {
  group('roster shapes', () {
    test('slot counts per mode', () {
      expect(rosterShape(SportMode.basketball), hasLength(5));
      expect(rosterShape(SportMode.football), hasLength(15)); // FPL squad
      expect(rosterShape(SportMode.americanFootball), hasLength(9));
    });

    test('every shape can be filled from the pool without duplicates', () {
      for (final mode in SportMode.values) {
        final used = <String>{};
        for (final position in rosterShape(mode)) {
          final pick = xStockFixtures.firstWhere(
            (s) => position.accepts(s) && !used.contains(s.mint),
            orElse: () => fail('No stock left for ${position.label} in $mode'),
          );
          used.add(pick.mint);
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

  group('scoreWindow', () {
    SlotWindow slot({double sb = 1, double eb = 1, double sp = 100, double ep = 100}) =>
        SlotWindow(startBalance: sb, endBalance: eb, startPrice: sp, endPrice: ep);

    test('averages slot returns and converts to basis points', () {
      final s = scoreWindow([slot(ep: 102), slot(ep: 99)]);
      expect(s.returnPct, closeTo(0.005, 1e-9));
      expect(s.points, 50);
    });

    test('negative returns score negative points', () {
      expect(scoreWindow([slot(ep: 97)]).points, -300);
    });

    test('slot sold to zero is excluded', () {
      final s = scoreWindow([slot(ep: 110, eb: 0), slot(ep: 101)]);
      expect(s.points, 100);
    });

    test('balance bought mid-window earns nothing', () {
      expect(scoreWindow([slot(sb: 0, eb: 50, ep: 150)]).points, 0);
    });

    test('empty roster scores zero', () {
      expect(scoreWindow([]).points, 0);
    });

    test('roster size does not change magnitude', () {
      final five = scoreWindow(List.generate(5, (_) => slot(ep: 101)));
      final eleven = scoreWindow(List.generate(11, (_) => slot(ep: 101)));
      expect(five.points, eleven.points);
    });
  });

  group('scoreWindow with captaincy and bench', () {
    SlotWindow slot({
      double eb = 1,
      double ep = 100,
      double weight = 1,
      String? role,
      int? benchOrder,
      bool vice = false,
    }) =>
        SlotWindow(
          startBalance: 1,
          endBalance: eb,
          startPrice: 100,
          endPrice: ep,
          weight: weight,
          role: role,
          benchOrder: benchOrder,
          isViceCaptain: vice,
        );

    test('captain counts double', () {
      // (2 × 2% + 0%) / 3
      expect(scoreWindow([slot(ep: 102, weight: 2), slot()]).points, 133);
    });

    test('vice-captain takes the double when the captain is sold', () {
      final s = scoreWindow([
        slot(ep: 110, weight: 2, eb: 0),
        slot(ep: 103, vice: true),
        slot(),
      ]);
      expect(s.points, 200); // (2 × 3% + 0%) / 3
    });

    test('substitutes only score when auto-subbed like-for-like, in bench order', () {
      final s = scoreWindow([
        slot(ep: 90, eb: 0, role: 'DEF'),
        slot(role: 'MID'),
        slot(ep: 150, weight: 0, role: 'MID', benchOrder: 1),
        slot(ep: 101, weight: 0, role: 'DEF', benchOrder: 2),
        slot(ep: 120, weight: 0, role: 'DEF', benchOrder: 3),
      ]);
      expect(s.points, 50); // DEF at order 2 replaces the sold DEF: (1% + 0%) / 2
    });
  });

  group('Lineup (FPL rules)', () {
    test('default is a valid 4-4-2 with the backup keeper first on the bench', () {
      final l = Lineup.defaultFootball();
      expect(l.formation.name, '4-4-2');
      expect(l.isValid, isTrue);
      expect(footballSquadRoles[l.bench.first], 'GK');
    });

    test('every FPL formation is reachable and valid', () {
      for (final f in footballFormations) {
        final l = Lineup.defaultFootball().withFormation(f);
        expect(l.formation, f);
        expect(l.isValid, isTrue, reason: f.name);
      }
    });

    test('changing formation keeps current starters and the captain', () {
      final l = Lineup.defaultFootball().withCaptain(12).withFormation(const Formation(3, 5, 2));
      expect(l.starters, containsAll([0, 12, 13]));
      expect(l.captain, 12);
    });

    test('substitutions that break formation rules are rejected', () {
      final l = Lineup.defaultFootball();
      expect(l.substitute(0, 6), isNull); // keeper for defender
      expect(l.substitute(2, 3), isNull); // two starters
      expect(l.withFormation(const Formation(3, 4, 3)).substitute(2, 11), isNull); // 2-5-3
      expect(l.substitute(12, 6)!.formation.name, '5-4-1');
    });

    test('benching the captain hands the armband to the vice-captain', () {
      final l = Lineup.defaultFootball().withCaptain(12).withViceCaptain(0);
      final sub = l.substitute(12, 14)!;
      expect(sub.captain, 0);
      expect(sub.viceCaptain, isNull);
    });

    test('round-trips through JSON', () {
      final l = Lineup.defaultFootball().withCaptain(12).withViceCaptain(7);
      expect(Lineup.fromJson(l.toJson()), l);
    });
  });

  group('FixtureRepository', () {
    test('seeded football roster is complete and tier-valid', () async {
      final repo = FixtureRepository(walletAddress: 'TestWallet1111111111111111111111111111111');
      final roster = await repo.getRoster(SportMode.football);
      expect(roster.isComplete, isTrue);
      for (final slot in roster.slots) {
        expect(slot.position.accepts(slot.stock!), isTrue, reason: slot.position.label);
      }
      expect(roster.classicRank, isNotNull);
    });

    test('filling a held stock updates the roster and leaderboard', () async {
      final repo = FixtureRepository(walletAddress: 'TestWallet1111111111111111111111111111111');
      final pg = xStockFixtures.firstWhere((s) => s.symbol == 'NVDAx');
      final roster = await repo.fillSlot(SportMode.basketball, 0, pg);
      expect(roster.slots.first.stock, pg);
      final board = await repo.getLeaderboard(SportMode.basketball);
      expect(board.where((e) => e.isCurrentUser), hasLength(1));
    });

    test('cannot fill with an unheld or ineligible stock', () async {
      final repo = FixtureRepository(walletAddress: 'TestWallet1111111111111111111111111111111');
      final unheld = xStockFixtures.firstWhere((s) => s.symbol == 'AMDx');
      final wrongTier = xStockFixtures.firstWhere((s) => s.symbol == 'KOx');
      expect(repo.fillSlot(SportMode.basketball, 0, unheld), throwsStateError);
      expect(repo.fillSlot(SportMode.basketball, 0, wrongTier), throwsStateError);
    });

    test('buying then filling works for an unheld stock', () async {
      final repo = FixtureRepository(walletAddress: 'TestWallet1111111111111111111111111111111');
      final amd = xStockFixtures.firstWhere((s) => s.symbol == 'AMDx');
      final quote = await repo.getSwapQuote(amd, 10);
      expect(quote.platformFeeUsdc, closeTo(0.03, 1e-9));
      await repo.executeSwap(quote);
      final roster = await repo.fillSlot(SportMode.basketball, 0, amd);
      expect(roster.slots.first.balance, closeTo(quote.estimatedShares, 1e-9));
    });

    test('settling a duel picks the higher return', () async {
      final repo = FixtureRepository(walletAddress: 'TestWallet1111111111111111111111111111111');
      final settled = await repo.settleDuel('duel-1');
      expect(settled.status, DuelStatus.settled);
      expect(settled.iWon, isTrue); // seeded 0.32% vs 0.19%
      expect(await repo.getTrophies(), hasLength(2));
    });

    test('saves a valid lineup and rejects an invalid one', () async {
      final repo = FixtureRepository(walletAddress: 'TestWallet1111111111111111111111111111111');
      final roster = await repo.getRoster(SportMode.football);
      final next = roster.lineup!.withFormation(const Formation(3, 5, 2));
      expect((await repo.setLineup(SportMode.football, next)).lineup!.formation.name, '3-5-2');

      final twoKeepers = Lineup(starters: List.generate(11, (i) => i), bench: const [11, 12, 13, 14]);
      expect(repo.setLineup(SportMode.football, twoKeepers), throwsStateError);
    });
  });
}
