/// Flavor configuration for the app.
///
/// Two flavors are supported:
/// - `store` - App Store/Play Store version with RevenueCat IAP
/// - `solana` - Web3 version with Solana wallet integration

enum FlavorType {
  store,
  solana,
}

class FlavorConfig {
  const FlavorConfig({
    required this.flavor,
    required this.name,
    required this.bundleId,
    required this.enableWeb3Features,
  });

  final FlavorType flavor;
  final String name;
  final String bundleId;
  final bool enableWeb3Features;

  static FlavorConfig? _instance;

  static FlavorConfig get instance {
    if (_instance == null) {
      throw StateError(
        'FlavorConfig not initialized. Call FlavorConfig.setFlavor() first.',
      );
    }
    return _instance!;
  }

  static bool get isInitialized => _instance != null;

  static void setFlavor(FlavorConfig config) {
    _instance = config;
  }

  bool get isStore => flavor == FlavorType.store;
  bool get isSolana => flavor == FlavorType.solana;
}
