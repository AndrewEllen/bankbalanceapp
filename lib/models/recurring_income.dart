// lib/models/recurring_income.dart
import 'dart:convert';
import 'pay_period.dart';

enum PayCycle { everyWeek, every2Weeks, every4Weeks, monthly }

class RecurringIncome {
  final String id;
  final String name;

  /// For Simple mode: fixed amount.
  /// For Advanced mode: this will store the computed NET for the period.
  final double amount;

  final PayCycle cycle;
  final DateTime firstPaymentDate; // this period's payday
  final bool enabled;

  /// Advanced mode fields
  final bool advanced;
  final double? hourly;          // base hourly
  final double? overtimeHourly;  // optional
  final double? defaultDailyHours;
  final List<DayHours>? periodDays; // 4-week grid (28 days ending on payday)

  const RecurringIncome({
    required this.id,
    required this.name,
    required this.amount,
    required this.cycle,
    required this.firstPaymentDate,
    this.enabled = true,
    // advanced
    this.advanced = false,
    this.hourly,
    this.overtimeHourly,
    this.defaultDailyHours,
    this.periodDays,
  });

  RecurringIncome copyWith({
    String? id,
    String? name,
    double? amount,
    PayCycle? cycle,
    DateTime? firstPaymentDate,
    bool? enabled,
    bool? advanced,
    double? hourly,
    double? overtimeHourly,
    double? defaultDailyHours,
    List<DayHours>? periodDays,
  }) => RecurringIncome(
    id: id ?? this.id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    cycle: cycle ?? this.cycle,
    firstPaymentDate: firstPaymentDate ?? this.firstPaymentDate,
    enabled: enabled ?? this.enabled,
    advanced: advanced ?? this.advanced,
    hourly: hourly ?? this.hourly,
    overtimeHourly: overtimeHourly ?? this.overtimeHourly,
    defaultDailyHours: defaultDailyHours ?? this.defaultDailyHours,
    periodDays: periodDays ?? this.periodDays,
  );

  DateTime nextPaymentAfter(DateTime after) {
    if (!enabled) return after;
    var d = firstPaymentDate;
    while (!d.isAfter(after)) {
      d = _addCycle(d, cycle);
    }
    return d;
  }

  static DateTime _addCycle(DateTime d, PayCycle c) {
    switch (c) {
      case PayCycle.everyWeek: return d.add(const Duration(days: 7));
      case PayCycle.every2Weeks: return d.add(const Duration(days: 14));
      case PayCycle.every4Weeks: return d.add(const Duration(days: 28));
      case PayCycle.monthly: return DateTime(d.year, d.month + 1, d.day);
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'cycle': cycle.name,
    'firstPaymentDate': firstPaymentDate.toIso8601String(),
    'enabled': enabled,
    'advanced': advanced,
    'hourly': hourly,
    'overtimeHourly': overtimeHourly,
    'defaultDailyHours': defaultDailyHours,
    'periodDays': periodDays?.map((e) => e.toJson()).toList(),
  };

  static RecurringIncome fromJson(Map<String, dynamic> j) => RecurringIncome(
    id: j['id'] as String,
    name: j['name'] as String,
    amount: (j['amount'] as num).toDouble(),
    cycle: PayCycle.values.firstWhere((e) => e.name == j['cycle']),
    firstPaymentDate: DateTime.parse(j['firstPaymentDate'] as String),
    enabled: j['enabled'] as bool? ?? true,
    advanced: j['advanced'] as bool? ?? false,
    hourly: (j['hourly'] as num?)?.toDouble(),
    overtimeHourly: (j['overtimeHourly'] as num?)?.toDouble(),
    defaultDailyHours: (j['defaultDailyHours'] as num?)?.toDouble(),
    periodDays: (j['periodDays'] as List?)
      ?.map((e) => DayHours.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
  );
}

String encodeRecurring(List<RecurringIncome> r) =>
    jsonEncode(r.map((e) => e.toJson()).toList());

List<RecurringIncome> decodeRecurring(String s) =>
    (jsonDecode(s) as List).map((e) => RecurringIncome.fromJson(e)).toList();
