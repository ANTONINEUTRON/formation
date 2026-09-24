import 'package:flutter/widgets.dart';

import 'package:formation/flavors/flavor_config.dart';

/// Widget that conditionally renders based on app flavor or feature flags.
///
/// Example usage:
/// ```dart
/// ConditionalFeature(
///   condition: FlavorConfig.instance.isSolana,
///   child: SolanaWalletButton(),
///   fallback: AppStorePaymentButton(),
/// )
/// ```
class ConditionalFeature extends StatelessWidget {
  const ConditionalFeature({
    required this.condition,
    required this.child,
    this.fallback,
    super.key,
  });

  /// The condition to evaluate. If true, [child] is shown.
  final bool condition;

  /// Widget to show when [condition] is true.
  final Widget child;

  /// Optional widget to show when [condition] is false.
  /// If null, nothing is rendered.
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    if (condition) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }

  /// Factory for Solana-only features.
  factory ConditionalFeature.solanaOnly({
    required Widget child,
    Widget? fallback,
    Key? key,
  }) {
    return ConditionalFeature(
      key: key,
      condition: FlavorConfig.instance.isSolana,
      fallback: fallback,
      child: child,
    );
  }

  /// Factory for Store-only features.
  factory ConditionalFeature.storeOnly({
    required Widget child,
    Widget? fallback,
    Key? key,
  }) {
    return ConditionalFeature(
      key: key,
      condition: FlavorConfig.instance.isStore,
      fallback: fallback,
      child: child,
    );
  }
}
