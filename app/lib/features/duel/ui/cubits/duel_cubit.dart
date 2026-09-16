import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:symbians/core/utils/format.dart';
import 'package:symbians/features/duel/ui/cubits/duel_state.dart';
import 'package:symbians/features/shared/data/formation_repository.dart';
import 'package:symbians/features/shared/domain/load_status.dart';
import 'package:symbians/features/shared/domain/models.dart';

/// Head-to-head duels for one sport mode.
///
/// Action methods rethrow repository errors so the calling widget can toast
/// them; the list itself reloads through [FormationRepository.changes].
class DuelCubit extends Cubit<DuelState> {
  DuelCubit({required FormationRepository repository, required this.mode})
      : _repository = repository,
        super(const DuelState()) {
    _changes = _repository.changes.listen((_) => load(silent: true));
  }

  final FormationRepository _repository;
  final SportMode mode;
  late final StreamSubscription<void> _changes;

  Future<void> load({bool silent = false}) async {
    if (!silent) emit(state.copyWith(status: LoadStatus.loading));
    try {
      final duels = await _repository.getDuels(mode);
      if (isClosed) return;
      emit(state.copyWith(status: LoadStatus.success, duels: duels));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(status: LoadStatus.failure, error: errorText(e)));
    }
  }

  Future<Duel> create({required String opponent, required Duration duration}) =>
      _repository.createDuel(mode: mode, opponent: opponent, duration: duration);

  Future<Duel> respond(String duelId, {required bool accept}) =>
      _busy(duelId, () => _repository.respondToDuel(duelId, accept: accept));

  /// Debug-only: settles an active duel immediately.
  Future<Duel> settle(String duelId) =>
      _busy(duelId, () => _repository.settleDuel(duelId));

  Future<Duel> _busy(String duelId, Future<Duel> Function() action) async {
    emit(state.copyWith(busyDuelId: duelId));
    try {
      return await action();
    } finally {
      if (!isClosed) emit(state.copyWith(clearBusy: true));
    }
  }

  @override
  Future<void> close() {
    _changes.cancel();
    return super.close();
  }
}
