import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:symbians/features/shared/data/api_repository.dart';
import 'package:symbians/features/shared/domain/models.dart';

/// Contract tests: the app parses responses recorded from the real backend
/// (`backend/test/e2e/flow.e2e-spec.ts` writes them into test/contract).
/// If either side changes the shape, these fail.
String _sample(String name) => File('test/contract/$name.json').readAsStringSync();

class _FakeSigner implements WalletSigner {
  @override
  String get walletAddress => 'GER2werVnaHehJ9dDZN7KVpf41aepYaLEEBgZ27MTUhW';

  @override
  Future<Uint8List> signMessage(Uint8List message) async => Uint8List(64);

  @override
  Future<String> signAndSendTransaction(Uint8List transaction) async => 'signature';
}

void main() {
  late List<String> requested;

  ApiRepository repository() {
    requested = [];
    final client = MockClient((request) async {
      final path = request.url.path;
      requested.add(
        '${request.method} $path${request.url.hasQuery ? '?${request.url.query}' : ''}',
      );
      final body = switch (path) {
        '/auth/challenge' => jsonEncode({'message': 'Sign in to Formation'}),
        '/auth/verify' => jsonEncode({
            'token': 'test-token',
            'user': {'id': 'user-1', 'username': 'me', 'walletAddress': 'wallet'},
          }),
        '/xstocks' => _sample('xstocks'),
        '/roster/football' => _sample('roster-football'),
        '/roster/football/formation' => _sample('formation-change'),
        '/league/football' => _sample('league-football'),
        '/duels' => _sample('duels-football'),
        '/trophies' => _sample('trophies'),
        _ => jsonEncode({'message': 'not stubbed: $path'}),
      };
      return http.Response(body, 200, headers: {'content-type': 'application/json'});
    });
    return ApiRepository(
      baseUrl: 'http://localhost:3000',
      signer: _FakeSigner(),
      client: client,
    );
  }

  test('signs in with the wallet before the first authenticated call', () async {
    await repository().getRoster(SportMode.football);
    expect(requested, [
      'POST /auth/challenge',
      'POST /auth/verify',
      'GET /roster/football',
    ]);
  });

  test('parses a team with its live gameweek', () async {
    final roster = await repository().getRoster(SportMode.football);

    expect(roster.mode, SportMode.football);
    expect(roster.formation, '3-5-2');
    expect(roster.slots, hasLength(11));
    expect(roster.slots.first.position.label, 'GK');
    expect(roster.slots.first.stock!.symbol, isNotEmpty);
    expect(roster.captainSlot, 9);
    expect(roster.viceCaptainSlot, 0);
    expect(roster.armband(9), 'C');
    expect(roster.armband(0), 'V');

    final gameweek = roster.gameweek!;
    expect(gameweek.entered, isTrue);
    expect(gameweek.isLive, isTrue);
    expect(gameweek.points, greaterThan(0));
    expect(gameweek.slots, hasLength(11));

    // Every score lines up with the slot it belongs to.
    for (final score in gameweek.slots) {
      expect(roster.slots[score.slotIndex].stock!.mint, score.mint);
    }
    // The captain carries the multiplier, and events are labelled for the UI.
    final captain = gameweek.scoreFor(9)!;
    expect(captain.multiplier, 2);
    expect(captain.events.map((e) => e.label), everyElement(isNotEmpty));
  });

  test('parses a formation change and the picks it dropped', () async {
    final change = await repository().setFormation(SportMode.football, '3-5-2');

    expect(change.roster.formation, '3-5-2');
    expect(change.dropped, hasLength(1));
    expect(change.dropped.first.symbol, isNotEmpty);
    expect(requested.last, 'PUT /roster/football/formation');
  });

  test('parses the leaderboard with season and gameweek points', () async {
    final board = await repository().getLeaderboard(SportMode.football);

    expect(board, isNotEmpty);
    expect(board.first.rank, 1);
    expect(board.first.points, greaterThan(0));
    expect(board.where((e) => e.isCurrentUser), hasLength(1));
  });

  test('parses duels, including points and the current user side', () async {
    final duels = await repository().getDuels(SportMode.football);

    expect(duels, isNotEmpty);
    final duel = duels.first;
    expect(duel.mode, SportMode.football);
    expect(duel.status, DuelStatus.settled);
    expect(duel.winnerId, isNotNull);
    expect(duel.me.isCurrentUser, isTrue);
    expect(duel.myPoints, isNot(0));
    expect(requested.last, 'GET /duels?mode=football');
  });

  test('parses a basketball duel decided on categories', () async {
    final duel = Duel.fromJson(
      jsonDecode(_sample('duel-basketball-settled')) as Map<String, dynamic>,
    );

    expect(duel.mode, SportMode.basketball);
    expect(duel.categories, hasLength(5));
    expect(duel.categories!.map((c) => c.name), contains('Hot hand'));
    expect(
      duel.categories!.every((c) => ['challenger', 'opponent', 'tie'].contains(c.winner)),
      isTrue,
    );
  });

  test('parses the stock pool and trophies', () async {
    final repo = repository();

    final stocks = await repo.getXStocks();
    expect(stocks, isNotEmpty);
    expect(stocks.first.tier, isA<RiskTier>());

    final trophies = await repo.getTrophies();
    expect(trophies, isNotEmpty);
    expect(trophies.first.title, isNotEmpty);
  });

  test('surfaces the backend error message', () async {
    final client = MockClient((request) async {
      if (request.url.path.startsWith('/auth')) {
        return http.Response(
          jsonEncode({
            'message': 'Sign in to Formation',
            'token': 't',
            'user': {'id': 'u'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'message': 'TSLAx is already on this team'}),
        400,
        headers: {'content-type': 'application/json'},
      );
    });
    final repo = ApiRepository(
      baseUrl: 'http://localhost:3000',
      signer: _FakeSigner(),
      client: client,
    );

    await expectLater(
      repo.getRoster(SportMode.football),
      throwsA(isA<StateError>()
          .having((e) => e.message, 'message', contains('already on this team'))),
    );
  });
}
