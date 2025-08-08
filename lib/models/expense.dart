import 'package:flutter/foundation.dart';

/// Model representing a one-off expense. Unlike [RecurringExpense], a plain
/// [Expense] occurs only once at a specific date. These are logged manually
/// by the user.
@immutable
class Expense {
  final String id;
  final String name;
  final double amount;
  final DateTime date;
  /// Whether this transaction is an income (true) or expense (false). Default
  /// is false (expense). This field determines the sign when computing
  /// balances. If true, the amount will be treated as income (added).
  final bool income;
  /// Category of the transaction (e.g., Grocery, Dining, Salary). Used for
  /// display and grouping. Optional.
  final String? category;

  const Expense({
    required this.id,
    required this.name,
    required this.amount,
    required this.date,
    this.income = false,
    this.category,
  });

  Expense copyWith({
    String? id,
    String? name,
    double? amount,
    DateTime? date,
    bool? income,
    String? category,
  }) {
    return Expense(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      income: income ?? this.income,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'date': date.toIso8601String(),
      'income': income,
      'category': category,
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      income: json['income'] == true,
      category: json['category'] as String?,
    );
  }
}