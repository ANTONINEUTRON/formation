import 'package:equatable/equatable.dart';

import 'package:formation/features/shared/domain/load_status.dart';
import 'package:formation/features/shared/domain/models.dart';

class TeamState extends Equatable {
  const TeamState({
    this.status = LoadStatus.initial,
    this.roster,
    this.isTicking = false,
    this.error,
  });

  final LoadStatus status;
  final Roster? roster;

  /// True while a debug scoring tick is running.
  final bool isTicking;
  final String? error;

  TeamState copyWith({
    LoadStatus? status,
    Roster? roster,
    bool? isTicking,
    String? error,
  }) =>
      TeamState(
        status: status ?? this.status,
        roster: roster ?? this.roster,
        isTicking: isTicking ?? this.isTicking,
        error: error,
      );

  @override
  List<Object?> get props => [status, roster, isTicking, error];
}
