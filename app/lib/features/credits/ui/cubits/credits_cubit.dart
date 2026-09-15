import 'package:flutter/foundation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import 'package:symbians/core/constants/app_constants.dart';
import 'package:symbians/features/credits/domain/entities/credit_package.dart';
import 'package:symbians/features/credits/ui/cubits/credits_state.dart';

/// Manages the user's AI prompt credit balance.
///
/// Credits are stored locally via [HydratedCubit] and persisted across
/// restarts. Backend integration is marked with TODO comments below.
class CreditsCubit extends HydratedCubit<CreditsState> {
  CreditsCubit() : super(const CreditsState());

  // ── Deduct ───────────────────────────────────────────────────────────────

  /// Deducts [AppConstants.creditsPerMessage] credits when the user sends a
  /// message. Returns true if the deduction succeeded (enough balance).
  bool deductCredit() {
    if (!state.canSend) return false;
    emit(state.copyWith(balance: state.balance - AppConstants.creditsPerMessage));
    return true;
  }

  // ── Purchase ─────────────────────────────────────────────────────────────

  /// Processes a credit purchase for the given [package] paid in [currency].
  ///
  /// Currently simulates an instant purchase (no wallet transaction).
  /// TODO: Replace the body with a backend call to verify the on-chain
  /// Solana transaction and credit the balance server-side.
  Future<bool> purchaseCredits({
    required CreditPackage package,
    required String currency,
  }) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      // TODO: Build + sign Solana SPL transfer for package.priceFor(currency),
      // send to backend manage_balance edge function, verify on-chain, then
      // credit the balance returned from the server.

      // Simulated network delay.
      await Future.delayed(const Duration(milliseconds: 600));

      final newBalance = state.balance + package.creditAmount;
      emit(state.copyWith(balance: newBalance, isLoading: false));

      debugPrint(
        '[CreditsCubit] Purchased ${package.creditAmount} credits '
        'for ${package.priceFor(currency)} $currency. '
        'New balance: $newBalance',
      );

      return true;
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Purchase failed: $e',
        ),
      );
      return false;
    }
  }

  void clearError() => emit(state.copyWith(error: null));

  // ── HydratedCubit ────────────────────────────────────────────────────────

  @override
  CreditsState? fromJson(Map<String, dynamic> json) {
    try {
      return CreditsState.fromJson(json);
    } catch (_) {
      return const CreditsState();
    }
  }

  @override
  Map<String, dynamic>? toJson(CreditsState state) => state.toJson();
}
