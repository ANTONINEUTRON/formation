import 'package:equatable/equatable.dart';

import 'package:formation/features/wallet/data/wallet_connector.dart';
import 'package:formation/features/wallet/domain/entities/wallet_balance.dart';

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
    this.sessionToken,
    this.balances = const [],
    this.wallets = const [],
    this.error,
  });

  final bool isConnected;

  /// True while wallet authorization or disconnect is in progress.
  final bool isLoading;

  /// True while Solana RPC balance fetch is in progress.
  final bool isLoadingBalances;

  /// Base58-encoded Solana wallet address, null when disconnected.
  final String? walletAddress;

  /// Opaque connector session handle, null when disconnected or after restore.
  ///
  /// MWA stores its auth token here so a signature can reauthorize rather than
  /// prompt from scratch; the web connector has no equivalent and leaves it
  /// null.
  final String? sessionToken;

  final List<WalletBalance> balances;

  /// Browser wallets found on this page, for the web connect screen.
  /// Always empty on Android, where the system picker does the choosing.
  final List<WalletOption> wallets;

  /// Latest error message, null if no error.
  final String? error;

  WalletState copyWith({
    bool? isConnected,
    bool? isLoading,
    bool? isLoadingBalances,
    String? walletAddress,
    String? sessionToken,
    List<WalletBalance>? balances,
    List<WalletOption>? wallets,
    String? error,
  }) {
    return WalletState(
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      isLoadingBalances: isLoadingBalances ?? this.isLoadingBalances,
      walletAddress: walletAddress ?? this.walletAddress,
      sessionToken: sessionToken ?? this.sessionToken,
      balances: balances ?? this.balances,
      wallets: wallets ?? this.wallets,
      error: error,
    );
  }

  // ── Serialization ──────────────────────────────────────────────────────────
  // Only persist connection info; balances are refreshed on each startup.

  Map<String, dynamic> toJson() => {
        'isConnected': isConnected,
        'walletAddress': walletAddress,
        // sessionToken intentionally omitted; re-auth on a fresh session.
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
        sessionToken,
        balances,
        wallets,
        error,
      ];
}
