import 'package:flutter_test/flutter_test.dart';

import 'package:formation/features/wallet/data/wallet_connector.dart';

void main() {
  test("recognises Mobile Wallet Adapter's no-wallet-answered failures", () {
    expect(isUnreachableWallet('SolanaMobileWalletAdapterError: ERROR_SESSION_TIMEOUT'), isTrue);
    expect(
      isUnreachableWallet('Failed to connect to the wallet websocket at ws://localhost:51234/solana-wallet.'),
      isTrue,
    );
    expect(isUnreachableWallet('Found no installed wallet that supports the mobile wallet protocol.'), isTrue);
    // A player declining in their wallet is not "unreachable".
    expect(isUnreachableWallet('Sign-in was rejected in your wallet.'), isFalse);
    expect(isUnreachableWallet('FORMATION_TAP_REQUIRED: tap to open your wallet'), isFalse);
    expect(unreachableWalletMessage, contains('Always'));
  });
}
