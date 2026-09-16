import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:symbians/core/utils/format.dart';
import 'package:symbians/features/profile/ui/cubits/profile_state.dart';
import 'package:symbians/features/shared/data/formation_repository.dart';
import 'package:symbians/features/shared/domain/load_status.dart';
import 'package:symbians/features/shared/domain/models.dart';

/// Cross-sport record and trophy case for the profile page.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({required FormationRepository repository})
      : _repository = repository,
        super(const ProfileState());

  final FormationRepository _repository;

  Future<void> load() async {
    emit(const ProfileState(status: LoadStatus.loading));
    try {
      final perMode = await Future.wait(SportMode.values.map(_record));
      final trophies = await _repository.getTrophies();
      if (isClosed) return;
      emit(ProfileState(
        status: LoadStatus.success,
        records: Map.fromIterables(SportMode.values, perMode),
        trophies: trophies,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(ProfileState(status: LoadStatus.failure, error: errorText(e)));
    }
  }

  Future<SportRecord> _record(SportMode mode) async {
    final (duels, board) = await (_repository.getDuels(mode), _repository.getLeaderboard(mode)).wait;
    final settled = duels.where((d) => d.status == DuelStatus.settled);
    final me = board.where((e) => e.isCurrentUser).firstOrNull;
    return SportRecord(
      wins: settled.where((d) => d.iWon).length,
      losses: settled.where((d) => !d.iWon).length,
      rank: me?.rank,
      points: me?.points,
    );
  }
}
