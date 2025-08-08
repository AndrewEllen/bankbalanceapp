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

  const Expense({
    required this.id,
    required this.name,
    required this.amount,
    required this.date,
  });

  Expense copyWith({
    String? id,
    String? name,
    double? amount,
    DateTime? date,
  }) {
    return Expense(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
    );
  }
}