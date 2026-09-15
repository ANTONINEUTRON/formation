/// Represents a token balance in the user's connected wallet.
class WalletBalance {
  const WalletBalance({
    required this.currency,
    required this.amount,
  });

  /// Token symbol, e.g. 'SOL', 'USDC', 'SKR'.
  final String currency;

  /// Token amount in human-readable units (not lamports/raw).
  final double amount;

  WalletBalance copyWith({String? currency, double? amount}) {
    return WalletBalance(
      currency: currency ?? this.currency,
      amount: amount ?? this.amount,
    );
  }

  Map<String, dynamic> toJson() => {
        'currency': currency,
        'amount': amount,
      };

  factory WalletBalance.fromJson(Map<String, dynamic> json) => WalletBalance(
        currency: json['currency'] as String,
        amount: (json['amount'] as num).toDouble(),
      );
}
