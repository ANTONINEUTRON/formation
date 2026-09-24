import 'package:equatable/equatable.dart';

import 'package:formation/features/shared/domain/load_status.dart';
import 'package:formation/features/shared/domain/models.dart';

class LeaguesState extends Equatable {
  const LeaguesState({
    this.status = LoadStatus.initial,
    this.leagues = const [],
    this.error,
  });

  final LoadStatus status;
  final List<League> leagues;
  final String? error;

  /// Leagues the player is in, newest window first.
  List<League> get mine => leagues.where((l) => l.joined).toList();

  /// Public leagues still open to join.
  List<League> get open => leagues.where((l) => l.joinable).toList();

  LeaguesState copyWith({
    LoadStatus? status,
    List<League>? leagues,
    String? error,
  }) =>
      LeaguesState(
        status: status ?? this.status,
        leagues: leagues ?? this.leagues,
        error: error,
      );

  @override
  List<Object?> get props => [status, leagues, error];
}
