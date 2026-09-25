import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/utils/format.dart';
import 'package:formation/features/profile/ui/cubits/profile_state.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/domain/load_status.dart';
import 'package:formation/features/shared/domain/models.dart';

/// Cross-sport record for the profile page.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({required FormationRepository repository})
      : _repository = repository,
        super(const ProfileState());

  final FormationRepository _repository;

  Future<void> load() async {
    emit(const ProfileState(status: LoadStatus.loading));
    try {
      final (perMode, profile) = await (
        Future.wait(SportMode.values.map(_record)),
        _repository.getProfile(),
      ).wait;
      if (isClosed) return;
      emit(ProfileState(
        status: LoadStatus.success,
        profile: profile,
        records: Map.fromIterables(SportMode.values, perMode),
      ));
    } catch (e) {
      if (isClosed) return;
      emit(ProfileState(status: LoadStatus.failure, error: errorText(e)));
    }
  }

  /// Replaces the profile after an edit, without refetching everything else.
  void setProfile(Profile profile) => emit(state.copyWith(profile: profile));

  /// Wins and losses come from settled leagues the player took part in.
  Future<SportRecord> _record(SportMode mode) async {
    final (leagues, board) =
        await (_repository.getLeagues(mode), _repository.getLeaderboard(mode)).wait;
    final settled = leagues.where(
      (l) => l.status == LeagueStatus.fin && l.standings.isNotEmpty,
    );
    final me = board.where((e) => e.isCurrentUser).firstOrNull;
    return SportRecord(
      wins: settled.where((l) => l.standings.first.isCurrentUser).length,
      losses: settled.where((l) => !l.standings.first.isCurrentUser).length,
      rank: me?.rank,
      points: me?.points,
    );
  }
}
