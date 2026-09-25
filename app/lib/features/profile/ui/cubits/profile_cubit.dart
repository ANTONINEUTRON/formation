import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/utils/app_log.dart';
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

    // The record and the profile are independent, and they used to be joined
    // with `(a, b).wait` — which throws a ParallelWaitError the moment either
    // side fails, discarding whichever one succeeded. So a single unavailable
    // endpoint took down the whole page and, because the edit button is
    // disabled while `profile` is null, also left the player unable to set
    // their name. Each is fetched on its own now, still concurrently.
    final recordsFuture = _recordsOrNull();
    final profileFuture = _profileOrNull();
    final records = await recordsFuture;
    final profile = await profileFuture;

    if (isClosed) return;

    // The record IS the page; the profile only fills in the card, which falls
    // back to the wallet address. So only a missing record is a failed page.
    if (records == null) {
      emit(ProfileState(status: LoadStatus.failure, profile: profile, error: _recordError));
      return;
    }
    emit(ProfileState(status: LoadStatus.success, profile: profile, records: records));
  }

  String? _recordError;

  Future<Map<SportMode, SportRecord>?> _recordsOrNull() async {
    try {
      final perMode = await Future.wait(SportMode.values.map(_record));
      return Map.fromIterables(SportMode.values, perMode);
    } catch (e, stackTrace) {
      _recordError = errorText(e, stackTrace);
      return null;
    }
  }

  Future<Profile?> _profileOrNull() async {
    try {
      return await _repository.getProfile();
    } catch (e) {
      // Logged rather than surfaced: the card degrades to the wallet address
      // on its own, and nothing else on the page depends on this.
      AppLog.warn('Profile unavailable, falling back to wallet address', e);
      return null;
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
