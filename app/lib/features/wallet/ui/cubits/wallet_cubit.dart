import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:solana/base58.dart';
import 'package:solana/dto.dart';
import 'package:solana/solana.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';

import 'package:formation/core/constants/app_constants.dart';
import 'package:formation/core/errors/app_exception.dart';
import 'package:formation/features/shared/data/api_repository.dart';
import 'package:formation/features/wallet/domain/entities/wallet_balance.dart';
import 'package:formation/features/wallet/ui/cubits/wallet_state.dart';

/// Manages Solana wallet connection via Mobile Wallet Adapter (MWA).
///
/// Uses [HydratedCubit] to persist the connected wallet address across restarts.
/// Balances are always re-fetched from the Solana RPC on startup.
/// Also signs sign-in messages and swap transactions for [ApiRepository].
class WalletCubit extends HydratedCubit<WalletState> implements WalletSigner {
  WalletCubit() : super(const WalletState()) {
    _setupSolanaClient();
    // If we have a persisted address, refresh balances immediately.
    if (state.walletAddress != null) {
      fetchBalances();
    }
  }

  late SolanaClient _solanaClient;

  void _setupSolanaClient() {
    _solanaClient = SolanaClient(
      rpcUrl: Uri.parse(AppConstants.solanaRpcUrl),
      websocketUrl: Uri.parse(AppConstants.solanaWsUrl),
    );
  }

  // ── Connect ─────────────────────────────────────────────────────────────────

  Future<void> connectWallet() async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      // Open the MWA session — this launches the wallet app on Android.
      final session = await LocalAssociationScenario.create();
      session.startActivityForResult(null).ignore();

      final client = await session.start();
      final result = await client.authorize(
        identityUri: Uri.parse('https://symbians.titalabs.xyz'),
        iconUri: Uri.parse('favicon.png'),
        identityName: 'Formation',
        cluster: 'mainnet-beta',
      );

      if (result != null) {
        final walletAddress = base58encode(result.publicKey.toList());

        emit(
          state.copyWith(
            isLoading: false,
            isConnected: true,
            walletAddress: walletAddress,
            authToken: result.authToken,
          ),
        );

        await fetchBalances();
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            error: 'Wallet connection was cancelled.',
          ),
        );
      }

      await session.close();
    } catch (e, st) {
      debugPrint('WalletCubit.connectWallet error: $e\n$st');
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Could not connect wallet. Please try again.',
        ),
      );
    }
  }

  // ── Disconnect ───────────────────────────────────────────────────────────────

  Future<void> disconnectWallet() async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      // Best-effort deauthorize; if authToken is gone (cold start restore),
      // we skip the MWA call and just clear local state.
      if (state.authToken != null) {
        final session = await LocalAssociationScenario.create();
        session.startActivityForResult(null).ignore();
        final client = await session.start();
        await client.deauthorize(authToken: state.authToken!);
        await session.close();
      }
    } catch (e) {
      debugPrint('[WalletCubit] deauthorize failed (non-fatal): $e');
    }

    // Always clear local state regardless of deauthorize result.
    emit(const WalletState());
  }

  // ── Balances ─────────────────────────────────────────────────────────────────

  Future<void> fetchBalances() async {
    final address = state.walletAddress;
    if (address == null) return;

    emit(state.copyWith(isLoadingBalances: true, error: null));

    try {
      final balances = await _getWalletBalances(address);
      emit(state.copyWith(isLoadingBalances: false, balances: balances));
    } catch (e, st) {
      debugPrint('WalletCubit.fetchBalances error: $e\n$st');
      emit(
        state.copyWith(
          isLoadingBalances: false,
          error: 'Could not load balances. Please try again.',
        ),
      );
    }
  }

  Future<List<WalletBalance>> _getWalletBalances(String walletAddress) async {
    final balances = <WalletBalance>[];

    // ── SOL ───────────────────────────────────────────────────────────────────
    try {
      final solResponse = await _solanaClient.rpcClient.getBalance(
        walletAddress,
        commitment: Commitment.confirmed,
      );
      balances.add(
        WalletBalance(
          currency: 'SOL',
          amount: solResponse.value / 1e9,
        ),
      );
    } catch (e) {
      debugPrint('[WalletCubit] SOL balance fetch failed: $e');
      balances.add(const WalletBalance(currency: 'SOL', amount: 0.0));
    }

    // ── USDC ──────────────────────────────────────────────────────────────────
    try {
      final usdcAccounts = await _solanaClient.rpcClient.getTokenAccountsByOwner(
        walletAddress,
        TokenAccountsFilter.byMint(AppConstants.usdcMintAddress),
        commitment: Commitment.confirmed,
        encoding: Encoding.jsonParsed,
      );

      double usdcAmount = 0.0;
      if (usdcAccounts.value.isNotEmpty) {
        final accountInfo = usdcAccounts.value.first;
        if (accountInfo.account.data is ParsedAccountData) {
          final parsedData =
              ((accountInfo.account.data as ParsedAccountData)
                          as ParsedSplTokenProgramAccountData)
                      .parsed as TokenAccountData;
          final info = parsedData.info;
          final raw = double.tryParse(info.tokenAmount.amount) ?? 0;
          final decimals = info.tokenAmount.decimals.toDouble();
          usdcAmount = raw / pow(10, decimals);
        }
      }
      balances.add(WalletBalance(currency: 'USDC', amount: usdcAmount));
    } catch (e) {
      debugPrint('[WalletCubit] USDC balance fetch failed: $e');
      balances.add(const WalletBalance(currency: 'USDC', amount: 0.0));
    }

    // ── SKR (Seeker) ─────────────────────────────────────────
    // Skipped if the mint address is still the placeholder constant.
    if (AppConstants.skrMintAddress != AppConstants.skrMintPlaceholder) {
      try {
        final skrAccounts = await _solanaClient.rpcClient.getTokenAccountsByOwner(
          walletAddress,
          TokenAccountsFilter.byMint(AppConstants.skrMintAddress),
          commitment: Commitment.confirmed,
          encoding: Encoding.jsonParsed,
        );

        double skrAmount = 0.0;
        if (skrAccounts.value.isNotEmpty) {
          final accountInfo = skrAccounts.value.first;
          if (accountInfo.account.data is ParsedAccountData) {
            final parsedData =
                ((accountInfo.account.data as ParsedAccountData)
                            as ParsedSplTokenProgramAccountData)
                        .parsed as TokenAccountData;
            final info = parsedData.info;
            final raw = double.tryParse(info.tokenAmount.amount) ?? 0;
            final decimals = info.tokenAmount.decimals.toDouble();
            skrAmount = raw / pow(10, decimals);
          }
        }
        balances.add(WalletBalance(currency: 'SKR', amount: skrAmount));
      } catch (e) {
        debugPrint('[WalletCubit] SKR balance fetch failed: $e');
        balances.add(const WalletBalance(currency: 'SKR', amount: 0.0));
      }
    } else {
      // Real mint not yet configured — show 0 until AppConstants is updated.
      balances.add(const WalletBalance(currency: 'SKR', amount: 0.0));
    }

    return balances;
  }

  // ── Signing ──────────────────────────────────────────────────────────────────

  @override
  String get walletAddress => state.walletAddress ?? '';

  @override
  Future<Uint8List> signMessage(Uint8List message) => _withWallet((client) async {
        final result = await client.signMessages(
          messages: [message],
          addresses: [Uint8List.fromList(base58decode(walletAddress))],
        );
        final signatures = result.signedMessages.firstOrNull?.signatures ?? const [];
        if (signatures.isEmpty) throw const WalletException(message: 'Sign-in was rejected in your wallet');
        return signatures.first;
      });

  @override
  Future<String> signAndSendTransaction(Uint8List transaction) => _withWallet((client) async {
        final result = await client.signAndSendTransactions(transactions: [transaction]);
        if (result.signatures.isEmpty) throw const WalletException(message: 'Transaction was rejected in your wallet');
        return base58encode(result.signatures.first);
      });

  /// Opens an MWA session, (re)authorizes, runs [action], and closes.
  Future<T> _withWallet<T>(Future<T> Function(MobileWalletAdapterClient client) action) async {
    final session = await LocalAssociationScenario.create();
    session.startActivityForResult(null).ignore();
    try {
      final client = await session.start();
      final token = state.authToken;
      final auth = token == null
          ? await client.authorize(
              identityUri: Uri.parse('https://symbians.titalabs.xyz'),
              iconUri: Uri.parse('favicon.png'),
              identityName: 'Formation',
              cluster: 'mainnet-beta',
            )
          : await client.reauthorize(
              identityUri: Uri.parse('https://symbians.titalabs.xyz'),
              iconUri: Uri.parse('favicon.png'),
              identityName: 'Formation',
              authToken: token,
            );
      if (auth == null) throw const WalletException(message: 'Wallet authorization was cancelled');
      emit(state.copyWith(authToken: auth.authToken));
      return await action(client);
    } finally {
      await session.close();
    }
  }

  // ── Formatting helper ─────────────────────────────────────────────────────

  /// Returns a truncated wallet address like `ABCDEF...WXYZ`.
  String get formattedAddress {
    final addr = state.walletAddress;
    if (addr == null || addr.length < 10) return '';
    return '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';
  }

  void clearError() => emit(state.copyWith(error: null));

  // ── HydratedCubit ────────────────────────────────────────────────────────

  @override
  WalletState? fromJson(Map<String, dynamic> json) {
    try {
      return WalletState.fromJson(json);
    } catch (_) {
      return const WalletState();
    }
  }

  @override
  Map<String, dynamic>? toJson(WalletState state) => state.toJson();
}
