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

  /// Where the web app is served; shared links point here.
  static const String webAppUrl = String.fromEnvironment(
    'WEB_APP_URL',
    defaultValue: 'https://app.formation.titalabs.xyz',
  );

  /// A Manager's public page: opens their team, signed in or not.
  static String managerUrl(String userId, String mode) => '$webAppUrl/managers/$userId?mode=$mode';

  /// The legal pages, served by the landing site.
  static const String termsUrl = '$appIdentityUri/terms';
  static const String privacyUrl = '$appIdentityUri/privacy';

  /// NestJS backend base URL. Empty means fixture mode (in-memory data).
  /// Set in `app/.env`; see [Env].
  static String apiUrl = Env.apiUrl;

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);

  // Solana. Both set in `app/.env`; see [Env] for why the web build needs its
  // own endpoint rather than the public one.
  static String solanaRpcUrl = Env.solanaRpcUrl;
  static String solanaWsUrl = Env.solanaWsUrl;
  static const String solanaCluster = 'mainnet-beta';

  /// Mainnet USDC SPL token mint address.
  static const String usdcMintAddress =
      'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';

  /// Seeker (SKR) SPL mint on mainnet-beta; the backend's SKR_MINT.
  static const String skrMintAddress = 'SKRbvo6Gf7GondiT3BbTfuRDPqLWei4j2Qy2NPGZhW3';
}
