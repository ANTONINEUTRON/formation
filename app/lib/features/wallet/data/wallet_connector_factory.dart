/// Re-exports the one `WalletConnector` implementation this build can use.
///
/// The conditional export is what keeps `solana_mobile_client` — an
/// Android-only plugin — out of the web compile, and `dart:js_interop` out of
/// the Android one. Both files define `createWalletConnector()`.
library;

export 'package:formation/features/wallet/data/mwa_wallet_connector.dart'
    if (dart.library.js_interop) 'package:formation/features/wallet/data/web_wallet_connector.dart';
