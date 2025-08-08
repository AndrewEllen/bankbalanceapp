import '../models/recurring_income.dart';
import '../models/pay_period.dart';
import '../models/deductions.dart';

/// Non‑invasive helpers for the RecurringIncome model and PayCycle enum.
///
/// These extensions provide a `copyWith` method for `RecurringIncome` and a
/// convenience getter on `PayCycle` to convert a cycle into the number of
/// periods per year. They live outside of the model class to avoid
/// modifying the original generated/immutable data structures.

extension RecurringIncomeX on RecurringIncome {
  /// Returns a new [RecurringIncome] based on this one with the provided
  /// fields overridden. Fields left as `null` will fall back to the
  /// corresponding value on this object.
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
    DeductionsSettings? deductions,
  }) {
    return RecurringIncome(
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
      deductions: deductions ?? this.deductions,
    );
  }
}

extension PayCycleX on PayCycle {
  /// Returns the number of pay periods in a year for this [PayCycle].
  int get periodsPerYear {
    switch (this) {
      case PayCycle.everyWeek:
        return 52;
      case PayCycle.every2Weeks:
        return 26;
      case PayCycle.every4Weeks:
        return 13;
      case PayCycle.monthly:
        return 12;
    }
  }
}