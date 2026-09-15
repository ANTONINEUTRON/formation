import 'package:equatable/equatable.dart';

import 'package:symbians/features/wallet/domain/entities/wallet_balance.dart';

/// State for [WalletCubit].
///
/// A single class with [copyWith] following the same pattern as symbal_fl,
/// making it straightforward to serialize with [HydratedCubit].
class WalletState extends Equatable {
  const WalletState({
    this.isConnected = false,
    this.isLoading = false,
    this.isLoadingBalances = false,
    this.walletAddress,
    this.authToken,
    this.balances = const [],
    this.error,
  });

  final bool isConnected;

  /// True while MWA authorization or disconnect is in progress.
  final bool isLoading;

  /// True while Solana RPC balance fetch is in progress.
  final bool isLoadingBalances;

  /// Base58-encoded Solana wallet address, null when disconnected.
  final String? walletAddress;

  /// MWA session auth token, null when disconnected or after restore
  /// (re-auth is required after a cold start if deauthorize is needed).
  final String? authToken;

  final List<WalletBalance> balances;

  /// Latest error message, null if no error.
  final String? error;

  WalletState copyWith({
    bool? isConnected,
    bool? isLoading,
    bool? isLoadingBalances,
    String? walletAddress,
    String? authToken,
    List<WalletBalance>? balances,
    String? error,
  }) {
    return WalletState(
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      isLoadingBalances: isLoadingBalances ?? this.isLoadingBalances,
      walletAddress: walletAddress ?? this.walletAddress,
      authToken: authToken ?? this.authToken,
      balances: balances ?? this.balances,
      error: error,
    );
  }

  // ── Serialization ──────────────────────────────────────────────────────────
  // Only persist connection info; balances are refreshed on each startup.

  Map<String, dynamic> toJson() => {
        'isConnected': isConnected,
        'walletAddress': walletAddress,
        // authToken intentionally omitted; re-auth on fresh session.
      };

  factory WalletState.fromJson(Map<String, dynamic> json) => WalletState(
        isConnected: json['isConnected'] as bool? ?? false,
        walletAddress: json['walletAddress'] as String?,
      );

  @override
  List<Object?> get props => [
        isConnected,
        isLoading,
        isLoadingBalances,
        walletAddress,
        authToken,
        balances,
        error,
      ];
}
