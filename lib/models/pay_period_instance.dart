// lib/models/pay_period_instance.dart
import 'dart:convert';
import 'pay_period.dart' as pp;

class PayPeriodInstance {
  final String id; // unique id
  final String templateId; // recurring income id
  late String templateName;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime paymentDate;

  /// Per-day hours (re-use your existing DayHours model).
  final List<pp.DayHours> days;

  /// Paid hours carried in from previous period (AFTER breaks).
  final double carryInHours;

  /// Manual adjustment in hours (+/-), AFTER breaks.
  final double manualAdjustment;

  /// For simple templates: an ad-hoc override amount (£) for this instance only.
  final double? simpleOverrideAmount;

  /// Paid hours carried out to the next period (AFTER breaks). This value is
  /// computed when editing a pay period and is used to seed the carry‑in
  /// hours of the subsequent period. In the UI this field is read‑only.
  final double carryOutHours;

  /// Whether this pay period has been closed/finalised. A closed period
  /// should no longer be editable and will be treated as final. Currently
  /// there is no UI for closing a period so this defaults to `false` and
  /// can be ignored.
  final bool closed;

  PayPeriodInstance({
    required this.id,
    required this.templateId,
    this.templateName = "Pay Period",
    required this.periodStart,
    required this.periodEnd,
    required this.paymentDate,
    required this.days,
    this.carryInHours = 0.0,
    this.manualAdjustment = 0.0,
    this.simpleOverrideAmount,
    this.carryOutHours = 0.0,
    this.closed = false,
  });


  PayPeriodInstance copyWith({
    String? id,
    String? templateId,
    String? templateName, // NEW
    DateTime? periodStart,
    DateTime? periodEnd,
    DateTime? paymentDate,
    List<pp.DayHours>? days,
    double? carryInHours,
    double? manualAdjustment,
    double? simpleOverrideAmount,
    double? carryOutHours,
    bool? closed,
  }) {
    return PayPeriodInstance(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      templateName: templateName ?? this.templateName, // NEW
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      paymentDate: paymentDate ?? this.paymentDate,
      days: days ?? this.days,
      carryInHours: carryInHours ?? this.carryInHours,
      manualAdjustment: manualAdjustment ?? this.manualAdjustment,
      simpleOverrideAmount: simpleOverrideAmount ?? this.simpleOverrideAmount,
      carryOutHours: carryOutHours ?? this.carryOutHours,
      closed: closed ?? this.closed,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateId': templateId,
        'templateName': templateName,
        'periodStart': periodStart.toIso8601String(),
        'periodEnd': periodEnd.toIso8601String(),
        'paymentDate': paymentDate.toIso8601String(),
        'days': days
            .map((d) => {
                  'date': d.date.toIso8601String(),
                  'baseHours': d.baseHours,
                  'extraHours': d.extraHours,
                })
            .toList(),
        'carryInHours': carryInHours,
        'manualAdjustment': manualAdjustment,
        'simpleOverrideAmount': simpleOverrideAmount,
    'carryOutHours': carryOutHours,
    'closed': closed,
      };

  static PayPeriodInstance fromJson(Map<String, dynamic> j) {
    final rawDays = (j['days'] as List?) ?? const [];
    final parsedDays = rawDays.map<pp.DayHours>((e) {
      final m = (e as Map).cast<String, dynamic>();
      return pp.DayHours(
        date: DateTime.parse(m['date'] as String),
        baseHours: (m['baseHours'] as num?)?.toDouble() ?? 0.0,
        extraHours: (m['extraHours'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();

    return PayPeriodInstance(
      id: j['id'] as String,
      templateId: j['templateId'] as String,
      templateName: j['templateName'] as String? ?? '',
      periodStart: DateTime.parse(j['periodStart'] as String),
      periodEnd: DateTime.parse(j['periodEnd'] as String),
      paymentDate: DateTime.parse(j['paymentDate'] as String),
      days: parsedDays,
      carryInHours: (j['carryInHours'] as num?)?.toDouble() ?? 0.0,
      manualAdjustment: (j['manualAdjustment'] as num?)?.toDouble() ?? 0.0,
      simpleOverrideAmount: (j['simpleOverrideAmount'] as num?)?.toDouble(),
      carryOutHours: (j['carryOutHours'] as num?)?.toDouble() ?? 0.0,
      closed: j['closed'] as bool? ?? false,
    );
  }
}

// ---- Safe JSON helpers (avoid dependency on any other file) ---------------

List<dynamic> _jsonDecodeListSafe(String s) {
  try {
    final v = json.decode(s);
    if (v is List) return v;
    return const [];
  } catch (_) {
    return const [];
  }
}

String _jsonEncodeSafe(Object v) => json.encode(v);

// Public helpers to mirror your encode/decode style
List<PayPeriodInstance> decodePayPeriodInstances(String s) {
  final List<dynamic> raw = _jsonDecodeListSafe(s);
  return raw.map((e) => PayPeriodInstance.fromJson((e as Map).cast<String, dynamic>())).toList();
}

String encodePayPeriodInstances(List<PayPeriodInstance> list) {
  return _jsonEncodeSafe(list.map((e) => e.toJson()).toList());
}