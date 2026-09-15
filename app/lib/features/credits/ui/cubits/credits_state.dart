import 'package:equatable/equatable.dart';

import 'package:symbians/core/constants/app_constants.dart';

/// State for [CreditsCubit].
class CreditsState extends Equatable {
  const CreditsState({
    this.balance = AppConstants.creditsFreeOnFirstLaunch,
    this.isLoading = false,
    this.error,
  });

  /// Current credit balance.
  final int balance;

  /// True while a purchase is being processed.
  final bool isLoading;

  final String? error;

  /// Whether the user can send a message (enough credits).
  bool get canSend => balance >= AppConstants.creditsPerMessage;

  CreditsState copyWith({
    int? balance,
    bool? isLoading,
    String? error,
  }) {
    return CreditsState(
      balance: balance ?? this.balance,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {'balance': balance};

  factory CreditsState.fromJson(Map<String, dynamic> json) => CreditsState(
        balance: json['balance'] as int? ?? AppConstants.creditsFreeOnFirstLaunch,
      );

  @override
  List<Object?> get props => [balance, isLoading, error];
}
