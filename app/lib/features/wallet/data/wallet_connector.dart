import 'dart:typed_data';

/// A wallet that the player can pick from on the connect screen.
///
/// On Android there is only ever one entry (Mobile Wallet Adapter picks the
/// installed wallet itself); on web there is one per detected browser wallet.
class WalletOption {
  const WalletOption({required this.name, this.icon});

  /// Display name as the wallet reports it, e.g. `Phantom`.
  final String name;

  /// Wallet-supplied icon, usually a `data:` URI. Null when none was given.
  final String? icon;
}

/// The result of a successful [WalletConnector.connect].
class WalletConnection {
  const WalletConnection({required this.address, this.sessionToken});

  /// Base58-encoded Solana address.
  final String address;

  /// Opaque, connector-specific handle for the live session.
  ///
  /// MWA puts its auth token here so a later signature can reauthorize instead
  /// of prompting from scratch. The web connector has no such token and leaves
  /// it null — the browser wallet keeps the session itself.
  final String? sessionToken;
}

/// Platform-specific wallet transport.
///
/// [WalletCubit] owns the state and the balances; everything that actually
/// talks to a wallet lives behind this interface so the web build never
/// compiles the Android-only `solana_mobile_client`.
abstract class WalletConnector {
  /// Whether [connect] with `silent: true` can restore a session on its own.
  ///
  /// True on web, where the wallet remembers the trusted origin. False under
  /// MWA, which always has to show the wallet app — so a null silent result
  /// there means "not possible", not "no longer authorized", and the caller
  /// must keep the restored address instead of clearing it.
  bool get canRestoreSilently;

  /// Wallets the player can choose between, for the web connect screen.
  ///
  /// Returns a single generic entry on Android, where the choice happens in
  /// the system wallet picker rather than in our UI.
  Future<List<WalletOption>> availableWallets();

  /// Connects to [walletName], or to the only/last wallet when it is null.
  ///
  /// With [silent] true, reconnects only if the wallet already trusts this
  /// origin, and returns null rather than showing a prompt. Used on web
  /// startup to restore a hydrated address without nagging the player.
  /// Returns null when the player cancels.
  Future<WalletConnection?> connect({String? walletName, bool silent = false});

  /// Best-effort teardown. Must not throw.
  Future<void> disconnect(String? sessionToken);

  /// Returns the raw 64-byte ed25519 signature of [message].
  Future<WalletSignature> signMessage(
    Uint8List message, {
    required String address,
    String? sessionToken,
  });

  /// Signs and submits [transaction]. Returns the base58 signature.
  Future<WalletSignature> signAndSendTransaction(
    Uint8List transaction, {
    required String address,
    String? sessionToken,
  });
}

/// A signature plus any refreshed session token the wallet handed back.
///
/// MWA returns a new auth token on every reauthorize, and dropping it would
/// mean a full authorization prompt on the next signature.
class WalletSignature {
  const WalletSignature({required this.value, this.sessionToken});

  /// Base58 signature for a transaction, or the raw bytes for a message.
  final Object value;

  /// Replacement session token, or null to keep the existing one.
  final String? sessionToken;

  Uint8List get bytes => value as Uint8List;
  String get base58 => value as String;
}
