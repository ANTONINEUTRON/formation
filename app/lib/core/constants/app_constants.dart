/// Application-wide constants.
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Symbians';
  static const String appTagline = 'The agent economy, in your pocket.';

  // URLs - Update these with actual values
  static const String supabaseUrl = 'https://your-project.supabase.co';
  static const String webAppUrl = 'https://symbians.app';

  // Supabase Tables
  static const String usersTable = 'users';
  static const String profilesTable = 'profiles';

  // Supabase Storage Buckets
  static const String avatarsBucket = 'avatars';
  static const String assetsBucket = 'assets';

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

  // Credits
  /// Free credits granted on first app launch.
  static const int creditsFreeOnFirstLaunch = 10;

  /// Credits consumed per agent message.
  static const int creditsPerMessage = 1;

  // Credit packages — dummy pricing, will come from backend later.
  static const int creditsPackageStarterAmount = 50;
  static const double creditsPackageStarterSol = 0.01;
  static const double creditsPackageStarterUsdc = 1.50;
  static const double creditsPackageStarterSkr = 500;

  static const int creditsPackageStandardAmount = 200;
  static const double creditsPackageStandardSol = 0.03;
  static const double creditsPackageStandardUsdc = 5.00;
  static const double creditsPackageStandardSkr = 1500;

  static const int creditsPackageProAmount = 500;
  static const double creditsPackageProSol = 0.07;
  static const double creditsPackageProUsdc = 12.00;
  static const double creditsPackageProSkr = 3500;
}
