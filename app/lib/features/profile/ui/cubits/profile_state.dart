import 'package:equatable/equatable.dart';

import 'package:formation/features/shared/domain/load_status.dart';
import 'package:formation/features/shared/domain/models.dart';

/// League record and standing in one sport mode.
class SportRecord extends Equatable {
  const SportRecord({this.wins = 0, this.losses = 0, this.rank, this.points});

  final int wins;
  final int losses;
  final int? rank;
  final double? points;

  @override
  List<Object?> get props => [wins, losses, rank, points];
}

class ProfileState extends Equatable {
  const ProfileState({
    this.profile,
    this.status = LoadStatus.initial,
    this.records = const {},
    this.error,
  });

  /// The player's own profile; null until it loads.
  final Profile? profile;
  final LoadStatus status;
  final Map<SportMode, SportRecord> records;
  final String? error;

  ProfileState copyWith({
    Profile? profile,
    LoadStatus? status,
    Map<SportMode, SportRecord>? records,
    String? error,
  }) =>
      ProfileState(
        profile: profile ?? this.profile,
        status: status ?? this.status,
        records: records ?? this.records,
        error: error,
      );

  @override
  List<Object?> get props => [profile, status, records, error];
}
