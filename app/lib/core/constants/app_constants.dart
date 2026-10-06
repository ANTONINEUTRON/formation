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
  /// Override with `flutter run --dart-define=API_URL=https://...`.
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://api.formation.titalabs.xyz',
  );

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);

  // Solana
  //
  // The public endpoint rate-limits by origin, which a browser build hits far
  // sooner than an APK does — pass a dedicated RPC with --dart-define for web.
  static const String solanaRpcUrl = String.fromEnvironment(
    'SOLANA_RPC_URL',
    defaultValue: 'https://api.mainnet-beta.solana.com',
  );
  static const String solanaWsUrl = String.fromEnvironment(
    'SOLANA_WS_URL',
    defaultValue: 'wss://api.mainnet-beta.solana.com',
  );
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
