import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/features/credits/domain/entities/credit_package.dart';
import 'package:symbians/features/credits/ui/cubits/credits_cubit.dart';
import 'package:symbians/features/credits/ui/cubits/credits_state.dart';
import 'package:symbians/gen/assets.gen.dart';

/// Bottom-sheet modal for purchasing credits.
///
/// Shows 3 packages × 3 currencies. Calls [CreditsCubit.purchaseCredits] on
/// confirm. Pops with `true` when purchase succeeds (caller can then proceed).
class BuyCreditsModal extends StatefulWidget {
  const BuyCreditsModal({super.key});

  /// Convenience helper to show the modal.
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<CreditsCubit>(),
        child: const BuyCreditsModal(),
      ),
    );
  }

  @override
  State<BuyCreditsModal> createState() => _BuyCreditsModalState();
}

class _BuyCreditsModalState extends State<BuyCreditsModal> {
  CreditPackage _selected = CreditPackage.all[1]; // default: Standard
  String _currency = 'USDC';

  static const _currencies = ['SOL', 'USDC', 'SKR'];

  Future<void> _buy() async {
    final cubit = context.read<CreditsCubit>();
    final success = await cubit.purchaseCredits(
      package: _selected,
      currency: _currency,
    );
    if (success && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: BlocBuilder<CreditsCubit, CreditsState>(
            builder: (context, state) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Title row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Buy Credits',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              'Current balance: ${state.balance} credits',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Package selector
                  Text(
                    'Choose a package',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: CreditPackage.all
                        .map((pkg) => Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: pkg != CreditPackage.all.last ? 8 : 0,
                                ),
                                child: _PackageCard(
                                  package: pkg,
                                  currency: _currency,
                                  isSelected: _selected == pkg,
                                  onTap: () =>
                                      setState(() => _selected = pkg),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 20),

                  // Currency selector
                  Text(
                    'Pay with',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _currencies
                        .map((c) => Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: c != _currencies.last ? 8 : 0,
                                ),
                                child: _CurrencyChip(
                                  currency: c,
                                  assetImage: _iconFor(c),
                                  isSelected: _currency == c,
                                  onTap: () => setState(() => _currency = c),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),

                  // Error message
                  if (state.error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        state.error!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.error,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: state.isLoading ? null : _buy,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textInverse,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: state.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textInverse,
                              ),
                            )
                          : Text(
                              'Buy ${_selected.creditAmount} credits '
                              '· ${_formatPrice(_selected.priceFor(_currency))} $_currency',
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  AssetGenImage _iconFor(String currency) => switch (currency) {
        'SOL' => Assets.icons.solana,
        'USDC' => Assets.icons.usdc,
        _ => Assets.icons.seeker,
      };

  String _formatPrice(double price) {
    if (price >= 100) return price.toStringAsFixed(0);
    if (price >= 1) return price.toStringAsFixed(2);
    return price.toStringAsFixed(3);
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.currency,
    required this.isSelected,
    required this.onTap,
  });

  final CreditPackage package;
  final String currency;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              package.name,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${package.creditAmount}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              'credits',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.currency,
    required this.assetImage,
    required this.isSelected,
    required this.onTap,
  });

  final String currency;
  final AssetGenImage assetImage;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            assetImage.image(width: 18, height: 18, fit: BoxFit.contain),
            const SizedBox(width: 6),
            Text(
              currency,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
