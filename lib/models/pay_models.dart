// lib/models/pay_models.dart

/// Pay rate representation. You can either supply [hourly] directly, or
/// provide a [multiplier] to be applied to [baseHourly]. If both are given,
/// [hourly] wins.
class PayRate {
  final double? hourly;
  final double? multiplier; // e.g. 1.25
  final double? baseHourly;

  const PayRate({this.hourly, this.multiplier, this.baseHourly});

  double resolve() {
    if (hourly != null) return hourly!;
    if (multiplier != null && baseHourly != null) {
      return baseHourly! * multiplier!;
    }
    return baseHourly ?? 0.0;
  }

  Map<String, dynamic> toJson() => {
        'hourly': hourly,
        'multiplier': multiplier,
        'baseHourly': baseHourly,
      };

  static PayRate fromJson(Map<String, dynamic> json) => PayRate(
        hourly: (json['hourly'] as num?)?.toDouble(),
        multiplier: (json['multiplier'] as num?)?.toDouble(),
        baseHourly: (json['baseHourly'] as num?)?.toDouble(),
      );
}

/// A single day's entry of work hours. [baseHours] are the
/// auto-filled pattern hours; [extraHours] are manual additions.
class ShiftEntry {
  final DateTime date;
  final double baseHours;
  final double extraHours;

  const ShiftEntry({required this.date, required this.baseHours, this.extraHours = 0});

  double get totalHours => baseHours + extraHours;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'baseHours': baseHours,
        'extraHours': extraHours,
      };

  static ShiftEntry fromJson(Map<String, dynamic> json) => ShiftEntry(
        date: DateTime.parse(json['date'] as String),
        baseHours: (json['baseHours'] as num).toDouble(),
        extraHours: (json['extraHours'] as num).toDouble(),
      );
}
