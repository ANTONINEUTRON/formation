import 'package:equatable/equatable.dart';

import 'package:symbians/features/shared/domain/load_status.dart';
import 'package:symbians/features/shared/domain/models.dart';

/// Duel record and league standing in one sport mode.
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
    this.status = LoadStatus.initial,
    this.records = const {},
    this.trophies = const [],
    this.error,
  });

  final LoadStatus status;
  final Map<SportMode, SportRecord> records;
  final List<Trophy> trophies;
  final String? error;

  @override
  List<Object?> get props => [status, records, trophies, error];
}
