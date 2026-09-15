
class Transaction {
  const Transaction({
    required this.type,
    required this.amount,
    required this.symbol,
    required this.description,
    required this.timestamp,
    required this.isIncoming,
  });

  final String type;
  final String amount;
  final String symbol;
  final String description;
  final String timestamp;
  final bool isIncoming;
}
