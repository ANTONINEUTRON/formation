/// Application-wide constants.
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Formation';
  static const String appTagline =
      'Fantasy sports for real stocks. Draft xStocks, climb the league, win duels.';

  /// NestJS backend base URL. Empty means fixture mode (in-memory data).
  /// Set with `flutter run --dart-define=API_URL=https://...`.
  static const String apiUrl = String.fromEnvironment('API_URL');

  // URLs - Update these with actual values
  static const String webAppUrl = 'https://symbians.app';

  // Pagination
  static const int defaultPageSize = 20;

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);

  // Solana
  static const String solanaRpcUrl = 'https://api.mainnet-beta.solana.com';
  static const String solanaWsUrl = 'wss://api.mainnet-beta.solana.com';

  /// Mainnet USDC SPL token mint address.
  static const String usdcMintAddress =
      'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';

  /// Marker value — replace with the real SKR mint address when known.
  static const String skrMintPlaceholder = 'PLACEHOLDER';

  /// Seeker Token SPL mint address on mainnet-beta.
  /// Update this constant once the mint is deployed.
  static const String skrMintAddress = skrMintPlaceholder;
}
