import 'package:equatable/equatable.dart';

import 'package:symbians/features/shared/domain/load_status.dart';
import 'package:symbians/features/shared/domain/models.dart';

class DraftState extends Equatable {
  const DraftState({
    this.status = LoadStatus.initial,
    this.roster,
    this.stocks = const [],
    this.held = const {},
    this.substituting,
    this.error,
  });

  final LoadStatus status;
  final Roster? roster;
  final List<XStock> stocks;

  /// Wallet balances keyed by mint; only mints with a positive balance.
  final Map<String, double> held;

  /// Football only: slot waiting for a substitution partner.
  final int? substituting;
  final String? error;

  double heldBalance(XStock stock) => held[stock.mint] ?? 0;

  DraftState copyWith({
    LoadStatus? status,
    Roster? roster,
    List<XStock>? stocks,
    Map<String, double>? held,
    int? substituting,
    bool clearSubstituting = false,
    String? error,
  }) =>
      DraftState(
        status: status ?? this.status,
        roster: roster ?? this.roster,
        stocks: stocks ?? this.stocks,
        held: held ?? this.held,
        substituting: clearSubstituting ? null : substituting ?? this.substituting,
        error: error,
      );

  @override
  List<Object?> get props => [status, roster, stocks, held, substituting, error];
}
