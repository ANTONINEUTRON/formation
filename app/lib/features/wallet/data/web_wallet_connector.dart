import 'dart:js_interop';
import 'dart:typed_data';

import 'package:formation/core/errors/app_exception.dart';
import 'package:formation/features/wallet/data/wallet_connector.dart';

/// Selected on web by `wallet_connector_factory.dart`.
WalletConnector createWalletConnector() => WebWalletConnector();

/// Browser-wallet transport, over the `window.formationWallet` bridge.
///
/// The bridge is `web/wallet_bridge.js`, built from `web_wallet/`. It wraps
/// the Wallet Standard, which covers both desktop extensions (Phantom,
/// Solflare, Backpack) and — through `wallet-standard-mobile` — Mobile Wallet
/// Adapter when the page is open in Android Chrome.
class WebWalletConnector implements WalletConnector {
  @override
  bool get canRestoreSilently => true;

  _Bridge get _bridge {
    final bridge = _formationWallet;
    if (bridge == null) {
      throw const WalletException(
        message: 'Wallet support failed to load. Please reload the page.',
      );
    }
    return bridge;
  }

  @override
  Future<List<WalletOption>> availableWallets() async {
    final wallets = await _bridge.list().toDart;
    return wallets.toDart
        .map((w) => WalletOption(name: w.name, icon: w.icon))
        .toList(growable: false);
  }

  @override
  Future<WalletConnection?> connect({String? walletName, bool silent = false}) async {
    final result = await _bridge.connect(walletName, silent).toDart;
    if (result == null) return null;
    // The browser wallet keeps the session itself, so there is no token to
    // carry: the address is the whole of what we need to remember.
    return WalletConnection(address: result.address);
  }

  @override
  Future<SignInProof?> signIn({
    String? walletName,
    required String statement,
    required String nonce,
    required String issuedAt,
  }) async {
    final result =
        await _bridge.signIn(walletName, statement, nonce, issuedAt).toDart;
    if (result == null) return null;
    return SignInProof(
      address: result.address,
      signedMessage: result.signedMessage.toDart,
      signature: result.signature.toDart,
    );
  }

  @override
  Future<void> disconnect(String? sessionToken) async {
    try {
      await _bridge.disconnect().toDart;
    } catch (_) {
      // Already gone, or the extension was uninstalled mid-session. Either
      // way the caller is about to clear local state.
    }
  }

  @override
  Future<WalletSignature> signMessage(
    Uint8List message, {
    required String address,
    String? sessionToken,
  }) async {
    final signature = await _bridge.signMessage(message.toJS).toDart;
    return WalletSignature(value: signature.toDart);
  }

  @override
  Future<WalletSignature> signAndSendTransaction(
    Uint8List transaction, {
    required String address,
    String? sessionToken,
  }) async {
    final signature = await _bridge.signAndSendTransaction(transaction.toJS).toDart;
    return WalletSignature(value: signature.toDart);
  }
}

@JS('window.formationWallet')
external _Bridge? get _formationWallet;

extension type _Bridge._(JSObject _) implements JSObject {
  external JSPromise<JSArray<_JsWalletOption>> list();
  external JSPromise<_JsConnection?> connect(String? name, bool silent);
  external JSPromise<_JsSignIn?> signIn(
    String? name,
    String statement,
    String nonce,
    String issuedAt,
  );
  external JSPromise<JSAny?> disconnect();
  external JSPromise<JSUint8Array> signMessage(JSUint8Array message);
  external JSPromise<JSString> signAndSendTransaction(JSUint8Array transaction);
}

extension type _JsWalletOption._(JSObject _) implements JSObject {
  external String get name;
  external String? get icon;
}

extension type _JsConnection._(JSObject _) implements JSObject {
  external String get address;
}

extension type _JsSignIn._(JSObject _) implements JSObject {
  external String get address;
  external JSUint8Array get signedMessage;
  external JSUint8Array get signature;
}
