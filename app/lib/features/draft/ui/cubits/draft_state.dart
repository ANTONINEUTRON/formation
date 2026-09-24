import 'package:equatable/equatable.dart';

import 'package:symbians/features/shared/domain/load_status.dart';
import 'package:symbians/features/shared/domain/models.dart';

class DraftState extends Equatable {
  const DraftState({
    this.status = LoadStatus.initial,
    this.roster,
    this.stocks = const [],
    this.held = const {},
    this.isSaving = false,
    this.error,
  });

  final LoadStatus status;
  final Roster? roster;
  final List<XStock> stocks;

  /// Wallet balances keyed by mint; only mints with a positive balance.
  final Map<String, double> held;

  /// True while a formation or captaincy change is being saved.
  final bool isSaving;
  final String? error;

  double heldBalance(XStock stock) => held[stock.mint] ?? 0;

  DraftState copyWith({
    LoadStatus? status,
    Roster? roster,
    List<XStock>? stocks,
    Map<String, double>? held,
    bool? isSaving,
    String? error,
  }) =>
      DraftState(
        status: status ?? this.status,
        roster: roster ?? this.roster,
        stocks: stocks ?? this.stocks,
        held: held ?? this.held,
        isSaving: isSaving ?? this.isSaving,
        error: error,
      );

  @override
  List<Object?> get props => [status, roster, stocks, held, isSaving, error];
}
