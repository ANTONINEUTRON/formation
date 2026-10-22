import 'package:equatable/equatable.dart';

import 'package:formation/features/shared/domain/load_status.dart';
import 'package:formation/features/shared/domain/models.dart';

/// The signed-in Manager's rank changed since they last saw this board.
class RankMove extends Equatable {
  const RankMove({required this.from, required this.to, required this.serial});

  final int from;
  final int to;

  /// Distinguishes two moves between the same ranks, so each one animates.
  final int serial;

  bool get isUp => to < from;

  /// Places moved: positive is up.
  int get places => from - to;

  @override
  List<Object?> get props => [from, to, serial];
}

class LeagueState extends Equatable {
  const LeagueState({
    this.status = LoadStatus.initial,
    this.entries = const [],
    this.period = const LeaguePeriod.season(),
    this.error,
    this.rankMove,
  });

  final LoadStatus status;
  final List<LeaderboardEntry> entries;

  /// Which slice of history the board covers.
  final LeaguePeriod period;
  final String? error;

  /// Set on the load that found the user's rank had moved; cleared after.
  final RankMove? rankMove;

  /// The signed-in user's entry, null until they draft a team in this mode.
  LeaderboardEntry? get me =>
      entries.where((e) => e.isCurrentUser).firstOrNull;

  /// Any change other than a fresh load drops the move: it has been shown.
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
  List<Object?> get props => [status, entries, period, error, rankMove];
}
