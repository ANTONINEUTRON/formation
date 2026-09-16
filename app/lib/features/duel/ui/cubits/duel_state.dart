import 'package:equatable/equatable.dart';

import 'package:symbians/features/shared/domain/load_status.dart';
import 'package:symbians/features/shared/domain/models.dart';

class DuelState extends Equatable {
  const DuelState({
    this.status = LoadStatus.initial,
    this.duels = const [],
    this.busyDuelId,
    this.error,
  });

  final LoadStatus status;
  final List<Duel> duels;

  /// Duel with an accept/decline/settle request in flight.
  final String? busyDuelId;
  final String? error;

  List<Duel> get invites => duels.where((d) => d.awaitingMyResponse).toList();

  List<Duel> get outgoing => duels
      .where((d) => d.status == DuelStatus.pending && d.challenger.isCurrentUser)
      .toList();

  List<Duel> get active => duels.where((d) => d.status == DuelStatus.active).toList();

  List<Duel> get past => duels
      .where((d) => d.status == DuelStatus.settled || d.status == DuelStatus.declined)
      .toList();

  Duel? byId(String id) => duels.where((d) => d.id == id).firstOrNull;

  DuelState copyWith({
    LoadStatus? status,
    List<Duel>? duels,
    String? busyDuelId,
    bool clearBusy = false,
    String? error,
  }) =>
      DuelState(
        status: status ?? this.status,
        duels: duels ?? this.duels,
        busyDuelId: clearBusy ? null : busyDuelId ?? this.busyDuelId,
        error: error,
      );

  @override
  List<Object?> get props => [status, duels, busyDuelId, error];
}
