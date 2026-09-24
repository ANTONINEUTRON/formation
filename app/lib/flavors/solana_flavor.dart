import 'package:formation/flavors/flavor_config.dart';

/// Solana flavor configuration.
///
/// Used for Web3/crypto releases.
/// - Solana wallet integration enabled
/// - IAP disabled (uses on-chain payments)
class SolanaFlavor {
  SolanaFlavor._();

  static FlavorConfig get config => const FlavorConfig(
        flavor: FlavorType.solana,
        name: 'Formation',
        bundleId: 'app.formation.web3',
        enableWeb3Features: true,
      );
}
