import 'package:equatable/equatable.dart';

import 'package:symbians/features/shared/domain/load_status.dart';
import 'package:symbians/features/shared/domain/models.dart';

class LeagueState extends Equatable {
  const LeagueState({
    this.status = LoadStatus.initial,
    this.entries = const [],
    this.error,
  });

  final LoadStatus status;
  final List<LeaderboardEntry> entries;
  final String? error;

  /// The signed-in user's entry, null until they draft a team in this mode.
  LeaderboardEntry? get me =>
      entries.where((e) => e.isCurrentUser).firstOrNull;

  LeagueState copyWith({
    LoadStatus? status,
    List<LeaderboardEntry>? entries,
    String? error,
  }) =>
      LeagueState(
        status: status ?? this.status,
        entries: entries ?? this.entries,
        error: error,
      );

  @override
  List<Object?> get props => [status, entries, error];
}
