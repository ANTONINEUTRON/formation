import 'package:formation/flavors/flavor_config.dart';

/// Store flavor configuration.
///
/// Used for App Store / Play Store releases.
/// - IAP enabled via RevenueCat
/// - Web3 features disabled
class StoreFlavor {
  StoreFlavor._();

  static FlavorConfig get config => const FlavorConfig(
        flavor: FlavorType.store,
        name: 'Formation',
        bundleId: 'app.formation.store',
        enableWeb3Features: false,
      );
}
