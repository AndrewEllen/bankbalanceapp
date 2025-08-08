// lib/models/pay_period_instance.dart
import 'dart:convert';
import 'pay_period.dart' as pp;

class PayPeriodInstance {
  final String id; // unique id
  final String templateId; // recurring income id
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

  const PayPeriodInstance({
    required this.id,
    required this.templateId,
    required this.periodStart,
    required this.periodEnd,
    required this.paymentDate,
    required this.days,
    this.carryInHours = 0.0,
    this.manualAdjustment = 0.0,
    this.simpleOverrideAmount,
  });

  PayPeriodInstance copyWith({
    String? id,
    String? templateId,
    DateTime? periodStart,
    DateTime? periodEnd,
    DateTime? paymentDate,
    List<pp.DayHours>? days,
    double? carryInHours,
    double? manualAdjustment,
    double? simpleOverrideAmount,
  }) {
    return PayPeriodInstance(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      paymentDate: paymentDate ?? this.paymentDate,
      days: days ?? this.days,
      carryInHours: carryInHours ?? this.carryInHours,
      manualAdjustment: manualAdjustment ?? this.manualAdjustment,
      simpleOverrideAmount: simpleOverrideAmount ?? this.simpleOverrideAmount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateId': templateId,
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
      periodStart: DateTime.parse(j['periodStart'] as String),
      periodEnd: DateTime.parse(j['periodEnd'] as String),
      paymentDate: DateTime.parse(j['paymentDate'] as String),
      days: parsedDays,
      carryInHours: (j['carryInHours'] as num?)?.toDouble() ?? 0.0,
      manualAdjustment: (j['manualAdjustment'] as num?)?.toDouble() ?? 0.0,
      simpleOverrideAmount: (j['simpleOverrideAmount'] as num?)?.toDouble(),
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