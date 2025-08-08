import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'recurring_income.dart'; // for PayCycle

/// Model representing a recurring expense. A recurring expense is similar to a
/// recurring income template but represents money leaving the account. It
/// supports the same pay cycle enumeration as recurring income. There is no
/// advanced hourly mode because expenses are a simple fixed amount on a
/// recurring schedule.
@immutable
class RecurringExpense {
  final String id;
  final String name;
  final double amount;
  final PayCycle cycle;
  final DateTime firstPaymentDate;
  final bool enabled;

  const RecurringExpense({
    required this.id,
    required this.name,
    required this.amount,
    required this.cycle,
    required this.firstPaymentDate,
    this.enabled = true,
  });

  RecurringExpense copyWith({
    String? id,
    String? name,
    double? amount,
    PayCycle? cycle,
    DateTime? firstPaymentDate,
    bool? enabled,
  }) {
    return RecurringExpense(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      cycle: cycle ?? this.cycle,
      firstPaymentDate: firstPaymentDate ?? this.firstPaymentDate,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'cycle': cycle.name,
      'firstPaymentDate': firstPaymentDate.toIso8601String(),
      'enabled': enabled,
    };
  }

  factory RecurringExpense.fromJson(Map<String, dynamic> json) {
    return RecurringExpense(
      id: json['id'] as String,
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      cycle: PayCycle.values.firstWhere(
        (e) => e.name == json['cycle'],
        orElse: () => PayCycle.every4Weeks,
      ),
      firstPaymentDate: DateTime.parse(json['firstPaymentDate'] as String),
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}