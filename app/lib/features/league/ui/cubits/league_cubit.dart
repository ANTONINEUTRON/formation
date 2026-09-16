import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:symbians/core/utils/format.dart';
import 'package:symbians/features/league/ui/cubits/league_state.dart';
import 'package:symbians/features/shared/data/formation_repository.dart';
import 'package:symbians/features/shared/domain/load_status.dart';
import 'package:symbians/features/shared/domain/models.dart';

/// Global Classic leaderboard for one sport mode.
class LeagueCubit extends Cubit<LeagueState> {
  LeagueCubit({required FormationRepository repository, required this.mode})
      : _repository = repository,
        super(const LeagueState()) {
    _changes = _repository.changes.listen((_) => load(silent: true));
  }

  final FormationRepository _repository;
  final SportMode mode;
  late final StreamSubscription<void> _changes;

  Future<void> load({bool silent = false}) async {
    if (!silent) emit(state.copyWith(status: LoadStatus.loading));
    try {
      final entries = await _repository.getLeaderboard(mode);
      if (isClosed) return;
      emit(LeagueState(status: LoadStatus.success, entries: entries));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(status: LoadStatus.failure, error: errorText(e)));
    }
  }

  @override
  Future<void> close() {
    _changes.cancel();
    return super.close();
  }
}
