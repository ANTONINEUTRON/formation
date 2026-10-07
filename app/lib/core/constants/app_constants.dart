import 'package:formation/env/env.dart';

/// Application-wide constants.
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Formation';
  static const String appTagline =
      'Fantasy sports for real stocks. Draft xStocks, climb the league, win duels.';

  /// Identity this app presents to wallets, for both MWA and Wallet Standard.
  /// Wallets show it on the approval prompt, so it has to be a real origin.
  static const String appIdentityUri = 'https://formation.titalabs.xyz';
  static const String appIdentityIcon = 'favicon.png';

  /// NestJS backend base URL. Empty means fixture mode (in-memory data).
  /// Set in `app/.env`; see [Env].
  static const String apiUrl = Env.apiUrl;

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);

  // Solana. Both set in `app/.env`; see [Env] for why the web build needs its
  // own endpoint rather than the public one.
  static const String solanaRpcUrl = Env.solanaRpcUrl;
  static const String solanaWsUrl = Env.solanaWsUrl;
  static const String solanaCluster = 'mainnet-beta';

  /// Mainnet USDC SPL token mint address.
  static const String usdcMintAddress =
      'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';

  /// Marker value — replace with the real SKR mint address when known.
  static const String skrMintPlaceholder = 'SKRbvo6Gf7GondiT3BbTfuRDPqLWei4j2Qy2NPGZhW3';

  /// Seeker Token SPL mint address on mainnet-beta.
  /// Update this constant once the mint is deployed.
  static const String skrMintAddress = skrMintPlaceholder;
}
