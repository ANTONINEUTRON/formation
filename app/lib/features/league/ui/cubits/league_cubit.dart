import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/utils/format.dart';
import 'package:formation/features/league/data/rank_memory.dart';
import 'package:formation/features/league/ui/cubits/league_state.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/domain/load_status.dart';
import 'package:formation/features/shared/domain/models.dart';

/// Global Classic leaderboard for one sport mode.
class LeagueCubit extends Cubit<LeagueState> {
  LeagueCubit({
    required FormationRepository repository,
    required this.mode,
    RankMemory memory = const PrefsRankMemory(),
  })  : _repository = repository,
        _memory = memory,
        super(const LeagueState()) {
    _changes = _repository.changes.listen((_) => load(silent: true));
  }

  final FormationRepository _repository;
  final RankMemory _memory;
  final SportMode mode;
  late final StreamSubscription<void> _changes;
  var _moves = 0;

  Future<void> load({bool silent = false, bool animate = true}) async {
    if (!silent) emit(state.copyWith(status: LoadStatus.loading));
    try {
      final period = state.period;
      final entries = await _repository.getLeaderboard(mode, period: period);
      if (isClosed) return;
      final move = await _rankMove(entries, period, animate: animate);
      if (isClosed) return;
      emit(LeagueState(
        status: LoadStatus.success,
        entries: entries,
        period: period,
        rankMove: move,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(status: LoadStatus.failure, error: errorText(e)));
    }
  }

  /// Compares the user's rank with the one they last saw on this board, and
  /// remembers the new one. Null when it hasn't moved or there's nothing to
  /// compare with.
  Future<RankMove?> _rankMove(
    List<LeaderboardEntry> entries,
    LeaguePeriod period, {
    required bool animate,
  }) async {
    final me = entries.where((e) => e.isCurrentUser).firstOrNull;
    // A custom range is a one-off look, not a board you come back to.
    if (me == null || period.kind == LeaguePeriodKind.custom) return null;
    final key = '${me.userId}.${mode.apiValue}.${period.kind.apiValue}';
    final last = await _memory.read(key);
    if (last != me.rank) await _memory.write(key, me.rank);
    if (!animate || last == null || last == me.rank) return null;
    return RankMove(from: last, to: me.rank, serial: ++_moves);
  }

  /// Switches the board to another range and reloads. The old entries stay on
  /// screen while the new ones load, so the list doesn't flash empty. A
  /// different range isn't a move, so nothing animates.
  Future<void> setPeriod(LeaguePeriod period) async {
    if (period == state.period) return;
    emit(state.copyWith(period: period, status: LoadStatus.loading));
    await load(silent: true, animate: false);
  }

  @override
  Future<void> close() {
    _changes.cancel();
    return super.close();
  }
}
