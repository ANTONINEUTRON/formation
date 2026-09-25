import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:formation/core/errors/app_exception.dart';
import 'package:formation/core/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:formation/domain/entity/notification.dart';
import 'package:formation/features/shared/data/api_repository.dart';
import 'package:formation/features/shared/domain/models.dart';

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
        '/leagues' => _sample('leagues-browse'),
        '/notifications' => _sample('notifications'),
        '/users/me' => _sample('profile'),
        _ when path.startsWith('/managers/') => _sample('manager-profile'),
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


  /// A repository whose every call fails the way [respond] says.
  ApiRepository failing(Future<http.Response> Function(http.Request) respond) =>
      ApiRepository(
        baseUrl: 'http://localhost:3000',
        signer: _FakeSigner(),
        client: MockClient(respond),
      );

  test('signs in with the wallet before the first authenticated call', () async {
    await repository().getRoster(SportMode.football);
    expect(requested, [
      'POST /auth/challenge',
      'POST /auth/verify',
      'GET /roster/football',
    ]);
  });

  test('parses a team with its live session and bench', () async {
    final roster = await repository().getRoster(SportMode.football);

    expect(roster.mode, SportMode.football);
    expect(roster.slots, hasLength(11));
    expect(roster.slots.first.position.label, 'GK');
    expect(roster.slots.first.stock!.symbol, isNotEmpty);

    final session = roster.session!;
    expect(session.entered, isTrue);
    expect(session.points, isNot(0));
    expect(session.slots, hasLength(11));
    // Three free substitutions a day, none used in the recorded run.
    expect(session.freeSubstitutionsLeft, 3);
    expect(session.substitutionsUsed, 0);

    // Every score lines up with the slot it belongs to.
    for (final score in session.slots) {
      expect(roster.slots[score.slotIndex].stock!.mint, score.mint);
    }

    // The bench is whatever the wallet holds that isn't starting.
    expect(roster.bench, isNotEmpty);
    final startingMints = {
      for (final slot in roster.slots) if (slot.stock != null) slot.stock!.mint,
    };
    for (final benched in roster.bench) {
      expect(startingMints, isNot(contains(benched.stock.mint)));
      // A tier that fits no slot in the current shape legitimately has none.
      expect(
        benched.eligibleSlots,
        everyElement(inInclusiveRange(0, roster.slots.length - 1)),
      );
    }
    // At least one benched stock can actually come on.
    expect(roster.bench.any((b) => b.eligibleSlots.isNotEmpty), isTrue);
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

  test('parses leagues, including a settled table', () async {
    final leagues = await repository().getLeagues(SportMode.football);
    expect(leagues, isNotEmpty);
    expect(requested.last, 'GET /leagues?mode=football');

    final settled = League.fromJson(
      jsonDecode(_sample('league-settled')) as Map<String, dynamic>,
    );
    expect(settled.status, LeagueStatus.fin);
    expect(settled.standings, hasLength(2));
    expect(settled.standings.first.rank, 1);
    // A PvP duel is a two-member private league.
    expect(settled.isDuel, isTrue);
    expect(settled.isPrivate, isTrue);
  });

  test('parses a manager profile with lineup and holdings', () async {
    final manager = await repository().getManager('someone', SportMode.football);

    expect(manager.username, isNotEmpty);
    expect(manager.isCurrentUser, isFalse);
    expect(manager.following, isFalse);
    expect(manager.lineup, isNotEmpty);
    expect(manager.holdings, isNotEmpty);
    // At least one holding is in their starting lineup.
    expect(manager.holdings.any((h) => h.starting), isTrue);
  });

  test('parses the signed-in profile, including the private email', () async {
    final profile = await repository().getProfile();

    expect(profile.username, isNotEmpty);
    expect(profile.bio, isNotEmpty);
    expect(profile.email, isNotEmpty);
  });

  test("a manager's profile carries a bio but never an email", () async {
    final manager = await repository().getManager('someone', SportMode.football);

    // Bio is public and optional, so null is valid here — the recorded manager
    // simply hasn't written one.
    final raw = jsonDecode(_sample('manager-profile')) as Map<String, dynamic>;
    expect(raw, contains('bio'));
    expect(manager.bio, raw['bio']);

    // The guarantee that matters: a public profile has no email field at all,
    // so a private address cannot ride along on one.
    expect(raw, isNot(contains('email')));
    expect(jsonEncode(raw), isNot(contains('@')));
  });

  test('parses notifications and their read state', () async {
    final items = await repository().getNotifications();

    expect(items, isNotEmpty);
    expect(items.first.title, isNotEmpty);
    expect(items.first.body, isNotEmpty);
    expect(
      items.map((n) => n.kind),
      everyElement(isIn(NotificationKind.values)),
    );
  });

  group('errors reach the UI as short sentences, never stack traces', () {
    test('a 4xx passes the backend message through, since we wrote it', () async {
      final repo = failing((_) async => http.Response(
            jsonEncode({'message': 'You do not hold AAPLx'}),
            400,
            headers: {'content-type': 'application/json'},
          ));

      await expectLater(
        repo.getXStocks(),
        throwsA(isA<ValidationException>()
            .having((e) => e.message, 'message', 'You do not hold AAPLx')),
      );
      expect(errorText(await _caught(repo.getXStocks())), 'You do not hold AAPLx');
    });

    test('a 5xx is our bug, so the player gets a neutral line', () async {
      final repo = failing((_) async => http.Response(
            jsonEncode({'message': 'TypeError: cannot read property of undefined'}),
            500,
            headers: {'content-type': 'application/json'},
          ));

      final message = errorText(await _caught(repo.getXStocks()));
      expect(message, isNot(contains('TypeError')));
      expect(message, contains('having trouble'));
    });

    test('an unreachable server does not surface the socket error', () async {
      final repo = failing((_) async => throw const SocketException('failed host lookup'));

      final message = errorText(await _caught(repo.getXStocks()));
      expect(message, isNot(contains('SocketException')));
      expect(message, contains("Can't reach Formation"));
    });

    test('a non-JSON body does not surface the parse error', () async {
      final repo = failing((_) async => http.Response('<html>502 Bad Gateway</html>', 200));

      final message = errorText(await _caught(repo.getXStocks()));
      expect(message, isNot(contains('FormatException')));
      expect(message, contains('unexpected'));
    });

    test('an unrecognised error never shows its own text', () {
      expect(errorText(ArgumentError('internal: bad mint index 7')), isNot(contains('mint')));
      expect(errorText(TypeError()), isNot(contains('TypeError')));
    });
  });
}

/// Runs [future] and returns whatever it threw.
Future<Object> _caught(Future<Object?> future) async {
  try {
    await future;
    return StateError('expected a failure');
  } catch (e) {
    return e;
  }
}
