import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:solana/dto.dart';
import 'package:solana/solana.dart';

import 'package:formation/core/constants/app_constants.dart';
import 'package:formation/features/shared/data/api_repository.dart';
import 'package:formation/features/shared/data/session_store.dart';
import 'package:formation/features/wallet/data/wallet_connector.dart';
import 'package:formation/features/wallet/data/wallet_connector_factory.dart';
import 'package:formation/features/wallet/domain/entities/wallet_balance.dart';
import 'package:formation/features/wallet/ui/cubits/wallet_state.dart';

/// Manages the Solana wallet connection.
///
/// The transport lives behind [WalletConnector] — Mobile Wallet Adapter on
/// Android, the Wallet Standard bridge on web — so this cubit only deals with
/// state, balances and signing on behalf of [ApiRepository].
///
/// Uses [HydratedCubit] to persist the connected wallet address across
/// restarts. Balances are always re-fetched from the Solana RPC on startup.
class WalletCubit extends HydratedCubit<WalletState> implements WalletSigner {
  WalletCubit({WalletConnector? connector})
      : _connector = connector ?? createWalletConnector(),
        super(const WalletState()) {
    _setupSolanaClient();
    // If we have a persisted address, refresh balances immediately.
    if (state.walletAddress != null) {
      fetchBalances();
      _restoreSession();
    }
    loadWallets();
  }

  final WalletConnector _connector;
  late SolanaClient _solanaClient;

  /// A one-step sign-in waiting for [ApiRepository] to spend it. See
  /// [takeSignInProof].
  SignInProof? _signInProof;

  static const _signInStatement = 'Sign in to Formation';

  void _setupSolanaClient() {
    _solanaClient = SolanaClient(
      rpcUrl: Uri.parse(AppConstants.solanaRpcUrl),
      websocketUrl: Uri.parse(AppConstants.solanaWsUrl),
    );
  }

  /// True when the connect screen should offer a choice of wallets.
  bool get hasWalletChoice => state.wallets.length > 1;

  // ── Connect ─────────────────────────────────────────────────────────────────

  /// Loads the pickable wallets, for the web connect screen.
  Future<void> loadWallets() async {
    if (!_connector.canRestoreSilently) return; // Android: system picker.
    try {
      emit(state.copyWith(wallets: await _connector.availableWallets()));
    } catch (e) {
      debugPrint('[WalletCubit] wallet discovery failed: $e');
    }
  }

  /// Re-establishes a web session for an address restored from storage.
  ///
  /// Without this the address survives a page reload but the wallet does not,
  /// so the first signature would fail. If the wallet no longer trusts this
  /// origin we drop the stale connection and show onboarding again.
  Future<void> _restoreSession() async {
    if (!_connector.canRestoreSilently) return;
    try {
      final restored = await _connector.connect(silent: true);
      if (restored != null && restored.address == state.walletAddress) {
        emit(state.copyWith(sessionToken: restored.sessionToken));
        return;
      }
    } catch (e) {
      debugPrint('[WalletCubit] silent reconnect failed: $e');
    }
    emit(WalletState(wallets: state.wallets));
  }

  Future<void> connectWallet({String? walletName}) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      // On the web, connect and sign in with one wallet prompt where the
      // wallet supports it. Android Chrome only lets a tap open the wallet
      // app, and this is the tap: signing in later, on the first API call,
      // would be a second hop with no tap behind it, and Chrome blocks it —
      // which is why Mobile Wallet Adapter sign-in kept failing.
      final proof = _connector.canRestoreSilently
          ? await _connector.signIn(
              walletName: walletName,
              statement: _signInStatement,
              nonce: _nonce(),
              issuedAt: DateTime.now().toUtc().toIso8601String(),
            )
          : null;
      if (proof != null) {
        _signInProof = proof;
        emit(
          state.copyWith(
            isLoading: false,
            isConnected: true,
            walletAddress: proof.address,
          ),
        );
        await fetchBalances();
        return;
      }

      final connection = await _connector.connect(walletName: walletName);

      if (connection != null) {
        emit(
          state.copyWith(
            isLoading: false,
            isConnected: true,
            walletAddress: connection.address,
            sessionToken: connection.sessionToken,
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

    _signInProof = null;

    // Best effort: the connector swallows its own failures, since local state
    // has to be cleared either way.
    await _connector.disconnect(state.sessionToken);

    // Disconnecting has to invalidate the backend session as well, or the
    // bearer token would outlive it in storage — on a shared browser that is
    // the next person's session.
    await SessionStore().clear();

    emit(WalletState(wallets: state.wallets));
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
    balances.add(
      WalletBalance(
        currency: 'USDC',
        amount: await _tokenBalance(walletAddress, AppConstants.usdcMintAddress),
      ),
    );

    // ── SKR (Seeker) ─────────────────────────────────────────
    // Skipped if the mint address is still the placeholder constant.
    final skr = AppConstants.skrMintAddress == AppConstants.skrMintPlaceholder
        ? 0.0
        : await _tokenBalance(walletAddress, AppConstants.skrMintAddress);
    balances.add(WalletBalance(currency: 'SKR', amount: skr));

    return balances;
  }

  /// Returns the owner's balance of [mint], or 0 if they hold none.
  ///
  /// A missing token account and a failed RPC call are both reported as zero:
  /// the player cannot act on the difference, and the cause is logged.
  Future<double> _tokenBalance(String walletAddress, String mint) async {
    try {
      final accounts = await _solanaClient.rpcClient.getTokenAccountsByOwner(
        walletAddress,
        TokenAccountsFilter.byMint(mint),
        commitment: Commitment.confirmed,
        encoding: Encoding.jsonParsed,
      );

      if (accounts.value.isEmpty) return 0.0;
      final data = accounts.value.first.account.data;
      if (data is! ParsedAccountData) return 0.0;

      final parsed = (data as ParsedSplTokenProgramAccountData).parsed;
      if (parsed is! TokenAccountData) return 0.0;

      final amount = parsed.info.tokenAmount;
      final raw = double.tryParse(amount.amount) ?? 0;
      return raw / pow(10, amount.decimals.toDouble());
    } catch (e) {
      debugPrint('[WalletCubit] balance fetch failed for $mint: $e');
      return 0.0;
    }
  }

  // ── Signing ──────────────────────────────────────────────────────────────────

  @override
  String get walletAddress => state.walletAddress ?? '';

  @override
  SignInProof? takeSignInProof() {
    final proof = _signInProof;
    _signInProof = null;
    // Only for the wallet it was signed with, in case the player switched.
    return proof != null && proof.address == walletAddress ? proof : null;
  }

  /// A nonce for a Sign In With Solana message. Made here rather than fetched
  /// from the server: a network call before the wallet opens can cost the tap
  /// its permission to open it. The server accepts each nonce once.
  static String _nonce() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(24, (_) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  Future<Uint8List> signMessage(Uint8List message) async {
    final result = await _connector.signMessage(
      message,
      address: walletAddress,
      sessionToken: state.sessionToken,
    );
    _rememberSession(result);
    return result.bytes;
  }

  @override
  Future<String> signAndSendTransaction(Uint8List transaction) async {
    final result = await _connector.signAndSendTransaction(
      transaction,
      address: walletAddress,
      sessionToken: state.sessionToken,
    );
    _rememberSession(result);
    return result.base58;
  }

  /// Keeps the refreshed session token, so the next signature can reauthorize
  /// instead of asking the player to approve the app all over again.
  void _rememberSession(WalletSignature signature) {
    if (signature.sessionToken != null) {
      emit(state.copyWith(sessionToken: signature.sessionToken));
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
