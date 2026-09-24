import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/utils/format.dart';
import 'package:formation/features/leagues/ui/cubits/leagues_state.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/domain/load_status.dart';
import 'package:formation/features/shared/domain/models.dart';

/// Custom leagues for one sport, including two-player PvP challenges.
class LeaguesCubit extends Cubit<LeaguesState> {
  LeaguesCubit({required FormationRepository repository, required this.mode})
      : _repository = repository,
        super(const LeaguesState()) {
    _changes = _repository.changes.listen((_) => load(silent: true));
  }

  final FormationRepository _repository;
  final SportMode mode;
  late final StreamSubscription<void> _changes;

  Future<void> load({bool silent = false}) async {
    if (!silent) emit(state.copyWith(status: LoadStatus.loading));
    try {
      final leagues = await _repository.getLeagues(mode);
      if (isClosed) return;
      emit(LeaguesState(status: LoadStatus.success, leagues: leagues));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(status: LoadStatus.failure, error: errorText(e)));
    }
  }

  /// Creates an open league, or a PvP duel when [opponent] is given.
  Future<League> create({
    required String name,
    required bool isPrivate,
    required DateTime startsAt,
    required Duration duration,
    String? opponent,
  }) =>
      _repository.createLeague(
        mode: mode,
        name: name,
        isPrivate: isPrivate,
        startsAt: startsAt,
        duration: duration,
        maxMembers: opponent == null ? null : 2,
        opponent: opponent,
      );

  Future<League> join({String? id, String? code}) =>
      _repository.joinLeague(id: id, code: code);

  Future<void> leave(String id) => _repository.leaveLeague(id);

  @override
  Future<void> close() {
    _changes.cancel();
    return super.close();
  }
}
