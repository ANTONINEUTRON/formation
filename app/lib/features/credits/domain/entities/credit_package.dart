import 'package:symbians/core/constants/app_constants.dart';

/// A purchasable credits package.
///
/// Pricing values come from [AppConstants] — swap those constants when
/// real pricing arrives from the backend.
class CreditPackage {
  const CreditPackage({
    required this.id,
    required this.name,
    required this.creditAmount,
    required this.priceSol,
    required this.priceUsdc,
    required this.priceSkr,
  });

  final String id;
  final String name;
  final int creditAmount;
  final double priceSol;
  final double priceUsdc;
  final double priceSkr;

  double priceFor(String currency) => switch (currency) {
        'SOL' => priceSol,
        'USDC' => priceUsdc,
        'SKR' => priceSkr,
        _ => throw ArgumentError('Unknown currency: $currency'),
      };

  /// The three available packages, sourced from [AppConstants].
  static const List<CreditPackage> all = [
    CreditPackage(
      id: 'starter',
      name: 'Starter',
      creditAmount: AppConstants.creditsPackageStarterAmount,
      priceSol: AppConstants.creditsPackageStarterSol,
      priceUsdc: AppConstants.creditsPackageStarterUsdc,
      priceSkr: AppConstants.creditsPackageStarterSkr,
    ),
    CreditPackage(
      id: 'standard',
      name: 'Standard',
      creditAmount: AppConstants.creditsPackageStandardAmount,
      priceSol: AppConstants.creditsPackageStandardSol,
      priceUsdc: AppConstants.creditsPackageStandardUsdc,
      priceSkr: AppConstants.creditsPackageStandardSkr,
    ),
    CreditPackage(
      id: 'pro',
      name: 'Pro',
      creditAmount: AppConstants.creditsPackageProAmount,
      priceSol: AppConstants.creditsPackageProSol,
      priceUsdc: AppConstants.creditsPackageProUsdc,
      priceSkr: AppConstants.creditsPackageProSkr,
    ),
  ];
}
