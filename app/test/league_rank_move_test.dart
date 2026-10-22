import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:formation/features/league/data/rank_memory.dart';
import 'package:formation/features/league/ui/cubits/league_cubit.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/domain/models.dart';

/// Only what the league cubit calls; anything else fails loudly.
class _Repository implements FormationRepository {
  final _changes = StreamController<void>.broadcast();
  int myRank = 5;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<LeaderboardEntry>> getLeaderboard(SportMode mode, {LeaguePeriod period = const LeaguePeriod.season()}) async => [
        for (var rank = 1; rank <= 8; rank++)
          LeaderboardEntry(
            rank: rank,
            userId: rank == myRank ? 'me' : 'other-$rank',
            username: rank == myRank ? 'me' : 'other$rank',
            walletAddress: 'wallet-$rank',
            points: 100.0 - rank,
            isCurrentUser: rank == myRank,
          ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _Memory implements RankMemory {
  final values = <String, int>{};

  @override
  Future<int?> read(String key) async => values[key];

  @override
  Future<void> write(String key, int rank) async => values[key] = rank;
}

void main() {
  late _Repository repository;
  late _Memory memory;
  late LeagueCubit cubit;

  setUp(() {
    repository = _Repository();
    memory = _Memory();
    cubit = LeagueCubit(repository: repository, mode: SportMode.football, memory: memory);
  });
  tearDown(() => cubit.close());

  test('the first look has nothing to compare with, and remembers the rank', () async {
    await cubit.load();
    expect(cubit.state.rankMove, isNull);
    expect(memory.values['me.football.season'], 5);
  });

  test('a climb since the last look is a move up, shown once', () async {
    await cubit.load();
    repository.myRank = 2;
    await cubit.load(silent: true);
    final move = cubit.state.rankMove!;
    expect((move.from, move.to, move.isUp, move.places), (5, 2, true, 3));

    await cubit.load(silent: true);
    expect(cubit.state.rankMove, isNull);
  });

  test('a rank from a previous visit still animates on return', () async {
    memory.values['me.football.season'] = 3;
    await cubit.load();
    final move = cubit.state.rankMove!;
    expect((move.from, move.to, move.isUp), (3, 5, false));
  });

  test('switching period is not a move, but remembers that board too', () async {
    await cubit.load();
    memory.values['me.football.match_week'] = 1;
    await cubit.setPeriod(const LeaguePeriod(LeaguePeriodKind.matchWeek));
    expect(cubit.state.rankMove, isNull);
    expect(memory.values['me.football.match_week'], 5);
  });
}
