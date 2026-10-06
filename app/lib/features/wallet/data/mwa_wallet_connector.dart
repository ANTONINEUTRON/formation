import 'package:flutter/foundation.dart';
import 'package:solana/base58.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';

import 'package:formation/core/constants/app_constants.dart';
import 'package:formation/core/errors/app_exception.dart';
import 'package:formation/features/wallet/data/wallet_connector.dart';

/// Selected on Android by `wallet_connector_factory.dart`.
WalletConnector createWalletConnector() => MwaWalletConnector();

/// Mobile Wallet Adapter transport.
///
/// Every operation opens a short-lived local association session, which is
/// what launches the wallet app (Seed Vault on a Seeker), and closes it again.
class MwaWalletConnector implements WalletConnector {
  @override
  bool get canRestoreSilently => false;

  @override
  Future<List<WalletOption>> availableWallets() async => const [
        WalletOption(name: 'Solana wallet'),
      ];

  @override
  Future<WalletConnection?> connect({String? walletName, bool silent = false}) async {
    // MWA cannot authorize without showing the wallet, so a silent reconnect
    // is simply not possible; the hydrated address stands on its own.
    if (silent) return null;

    final session = await LocalAssociationScenario.create();
    session.startActivityForResult(null).ignore();
    try {
      final client = await session.start();
      final result = await client.authorize(
        identityUri: Uri.parse(AppConstants.appIdentityUri),
        iconUri: Uri.parse(AppConstants.appIdentityIcon),
        identityName: AppConstants.appName,
        cluster: AppConstants.solanaCluster,
      );
      if (result == null) return null;
      return WalletConnection(
        address: base58encode(result.publicKey.toList()),
        sessionToken: result.authToken,
      );
    } finally {
      await session.close();
    }
  }

  @override
  Future<void> disconnect(String? sessionToken) async {
    // Without a token there is nothing to revoke: a cold start drops it, and
    // clearing our own state is all that is left to do.
    if (sessionToken == null) return;
    try {
      final session = await LocalAssociationScenario.create();
      session.startActivityForResult(null).ignore();
      final client = await session.start();
      await client.deauthorize(authToken: sessionToken);
      await session.close();
    } catch (e) {
      debugPrint('[MwaWalletConnector] deauthorize failed (non-fatal): $e');
    }
  }

  @override
  Future<WalletSignature> signMessage(
    Uint8List message, {
    required String address,
    String? sessionToken,
  }) =>
      _withWallet(sessionToken, (client) async {
        final result = await client.signMessages(
          messages: [message],
          addresses: [Uint8List.fromList(base58decode(address))],
        );
        final signatures = result.signedMessages.firstOrNull?.signatures ?? const [];
        if (signatures.isEmpty) {
          throw const WalletException(message: 'Sign-in was rejected in your wallet');
        }
        return signatures.first;
      });

  @override
  Future<WalletSignature> signAndSendTransaction(
    Uint8List transaction, {
    required String address,
    String? sessionToken,
  }) =>
      _withWallet(sessionToken, (client) async {
        final result = await client.signAndSendTransactions(transactions: [transaction]);
        if (result.signatures.isEmpty) {
          throw const WalletException(message: 'Transaction was rejected in your wallet');
        }
        return base58encode(result.signatures.first);
      });

  /// Opens a session, (re)authorizes, runs [action], and closes.
  Future<WalletSignature> _withWallet(
    String? sessionToken,
    Future<Object> Function(MobileWalletAdapterClient client) action,
  ) async {
    final session = await LocalAssociationScenario.create();
    session.startActivityForResult(null).ignore();
    try {
      final client = await session.start();
      final auth = sessionToken == null
          ? await client.authorize(
              identityUri: Uri.parse(AppConstants.appIdentityUri),
              iconUri: Uri.parse(AppConstants.appIdentityIcon),
              identityName: AppConstants.appName,
              cluster: AppConstants.solanaCluster,
            )
          : await client.reauthorize(
              identityUri: Uri.parse(AppConstants.appIdentityUri),
              iconUri: Uri.parse(AppConstants.appIdentityIcon),
              identityName: AppConstants.appName,
              authToken: sessionToken,
            );
      if (auth == null) {
        throw const WalletException(message: 'Wallet authorization was cancelled');
      }
      return WalletSignature(
        value: await action(client),
        sessionToken: auth.authToken,
      );
    } finally {
      await session.close();
    }
  }
}
