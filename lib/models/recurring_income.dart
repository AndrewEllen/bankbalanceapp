
// lib/models/recurring_income.dart
import 'dart:convert';
import 'pay_period.dart';
import 'deductions.dart';

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

  /// Advanced only
  final bool advanced;
  final double? hourly;
  final double? overtimeHourly;
  final double? defaultDailyHours;
  final List<DayHours>? periodDays;

  /// OPTIONAL: Persist the deductions used to compute NET for this income.
  final DeductionsSettings? deductions;

  RecurringIncome({
    required this.id,
    required this.name,
    required this.amount,
    required this.cycle,
    required this.firstPaymentDate,
    required this.enabled,
    this.advanced = false,
    this.hourly,
    this.overtimeHourly,
    this.defaultDailyHours,
    this.periodDays,
    this.deductions,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'cycle': cycle.index,
    'firstPaymentDate': firstPaymentDate.toIso8601String(),
    'enabled': enabled,
    'advanced': advanced,
    if (hourly != null) 'hourly': hourly,
    if (overtimeHourly != null) 'overtimeHourly': overtimeHourly,
    if (defaultDailyHours != null) 'defaultDailyHours': defaultDailyHours,
    if (periodDays != null) 'periodDays': periodDays!.map((e) => e.toJson()).toList(),
    if (deductions != null) 'deductions': deductions!.toJson(),
  };

  static RecurringIncome fromJson(Map<String, dynamic> j) => RecurringIncome(
    id: j['id'] as String,
    name: j['name'] as String,
    amount: (j['amount'] as num).toDouble(),
    cycle: () {
      final raw = j['cycle'];
      if (raw is num) return PayCycle.values[raw.toInt()];
      if (raw is String) {
        // Match by enum name
        return PayCycle.values.firstWhere(
              (e) => e.toString().split('.').last == raw,
          orElse: () => PayCycle.every4Weeks, // fallback default
        );
      }
      return PayCycle.every4Weeks;
    }(),
    firstPaymentDate: DateTime.parse(j['firstPaymentDate'] as String),
    enabled: j['enabled'] as bool? ?? true,
    advanced: j['advanced'] as bool? ?? false,
    hourly: (j['hourly'] as num?)?.toDouble(),
    overtimeHourly: (j['overtimeHourly'] as num?)?.toDouble(),
    defaultDailyHours: (j['defaultDailyHours'] as num?)?.toDouble(),
    periodDays: (j['periodDays'] as List?)
      ?.map((e) => DayHours.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
    deductions: j['deductions'] == null ? null
      : DeductionsSettings.fromJson(Map<String, dynamic>.from(j['deductions'] as Map)),
  );

  DateTime? nextPaymentAfter(DateTime anchor, {int maxHops = 240}) {
    if (!enabled) return null;
    final a = DateTime(anchor.year, anchor.month, anchor.day);
    var d = DateTime(firstPaymentDate.year, firstPaymentDate.month, firstPaymentDate.day);
    if (d.isAfter(a)) return d;

    for (var i = 0; i < maxHops; i++) {
      d = _addCycle(d, cycle);
      if (d.isAfter(a)) return d;
    }
    return null;
  }

  static DateTime _addCycle(DateTime d, PayCycle c) {
    switch (c) {
      case PayCycle.everyWeek:    return d.add(const Duration(days: 7));
      case PayCycle.every2Weeks:  return d.add(const Duration(days: 14));
      case PayCycle.every4Weeks:  return d.add(const Duration(days: 28));
      case PayCycle.monthly:
        final y = d.year, m = d.month + 1;
        final dim = _daysInMonth(y, m);
        final day = d.day <= dim ? d.day : dim;
        return DateTime(y, m, day);
    }
  }

  static int _daysInMonth(int year, int month) {
    final firstOfNext = (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    return firstOfNext.subtract(const Duration(days: 1)).day;
  }

}

String encodeRecurring(List<RecurringIncome> r) =>
    jsonEncode(r.map((e) => e.toJson()).toList());

List<RecurringIncome> decodeRecurring(String s) =>
    (jsonDecode(s) as List).map((e) => RecurringIncome.fromJson(e)).toList();
