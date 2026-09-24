import 'package:equatable/equatable.dart';

import 'package:formation/features/shared/domain/load_status.dart';
import 'package:formation/features/shared/domain/models.dart';

class LeagueState extends Equatable {
  const LeagueState({
    this.status = LoadStatus.initial,
    this.entries = const [],
    this.period = const LeaguePeriod.allTime(),
    this.error,
  });

  final LoadStatus status;
  final List<LeaderboardEntry> entries;

  /// Which slice of history the board covers.
  final LeaguePeriod period;
  final String? error;

  /// The signed-in user's entry, null until they draft a team in this mode.
  LeaderboardEntry? get me =>
      entries.where((e) => e.isCurrentUser).firstOrNull;

  LeagueState copyWith({
    LoadStatus? status,
    List<LeaderboardEntry>? entries,
    LeaguePeriod? period,
    String? error,
  }) =>
      LeagueState(
        status: status ?? this.status,
        entries: entries ?? this.entries,
        period: period ?? this.period,
        error: error,
      );

  @override
  List<Object?> get props => [status, entries, period, error];
}
