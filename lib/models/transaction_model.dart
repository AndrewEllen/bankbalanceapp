
class TransactionModel {

  TransactionModel({
    required this.transactionAmount,
    required this.transactionTime,
    required this.income,

  });

  double transactionAmount;
  DateTime transactionTime;
  bool income;

}