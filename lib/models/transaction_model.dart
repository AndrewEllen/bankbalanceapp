
class TransactionModel {
  TransactionModel({
    required this.transactionAmount,
    required this.transactionTime,
    required this.income,
    this.category,
    this.description,
  });

  /// The absolute amount of the transaction. Positive value; sign is determined
  /// by [income].
  double transactionAmount;
  /// When the transaction occurred.
  DateTime transactionTime;
  /// True if this transaction is an income; false if expense.
  bool income;
  /// Category of the transaction, e.g. Grocery, Dining.
  String? category;
  /// Optional description.
  String? description;
}