import 'package:symbians/flavors/flavor_config.dart';

/// Solana flavor configuration.
///
/// Used for Web3/crypto releases.
/// - Solana wallet integration enabled
/// - IAP disabled (uses on-chain payments)
class SolanaFlavor {
  SolanaFlavor._();

  static FlavorConfig get config => const FlavorConfig(
        flavor: FlavorType.solana,
        name: 'Symbians Web3',
        bundleId: 'com.symbians.web3',
        enableWeb3Features: true,
      );
}
