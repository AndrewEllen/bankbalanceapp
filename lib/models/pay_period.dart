// lib/models/pay_period.dart
class DayHours {
  final DateTime date;
  double baseHours;
  double extraHours;

  DayHours({
    required this.date,
    this.baseHours = 0,
    this.extraHours = 0,
  });

  double get total => baseHours + extraHours;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'baseHours': baseHours,
    'extraHours': extraHours,
  };

  static DayHours fromJson(Map<String, dynamic> j) => DayHours(
    date: DateTime.parse(j['date'] as String),
    baseHours: (j['baseHours'] as num?)?.toDouble() ?? 0.0,
    extraHours: (j['extraHours'] as num?)?.toDouble() ?? 0.0,
  );
}
