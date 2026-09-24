import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/utils/format.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/domain/load_status.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/team/ui/cubits/team_state.dart';

/// The signed-in user's team for one sport mode, and its live session.
class TeamCubit extends Cubit<TeamState> {
  TeamCubit({required FormationRepository repository, required this.mode})
      : _repository = repository,
        super(const TeamState()) {
    _changes = _repository.changes.listen((_) => load(silent: true));
  }

  final FormationRepository _repository;
  final SportMode mode;
  late final StreamSubscription<void> _changes;

  Future<void> load({bool silent = false}) async {
    if (!silent) emit(state.copyWith(status: LoadStatus.loading));
    try {
      final roster = await _repository.getRoster(mode);
      if (isClosed) return;
      emit(state.copyWith(status: LoadStatus.success, roster: roster));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(status: LoadStatus.failure, error: errorText(e)));
    }
  }

  /// Debug-only: records prices now and banks everything owed.
  Future<void> runTick() => _busy(_repository.runTick);

  /// Debug-only: opens scheduled leagues and settles finished ones.
  Future<void> processLeagues() => _busy(() => _repository.processLeagues());

  Future<void> _busy(Future<void> Function() action) async {
    emit(state.copyWith(isTicking: true));
    try {
      await action();
    } finally {
      if (!isClosed) emit(state.copyWith(isTicking: false));
    }
  }

  @override
  Future<void> close() {
    _changes.cancel();
    return super.close();
  }
}
