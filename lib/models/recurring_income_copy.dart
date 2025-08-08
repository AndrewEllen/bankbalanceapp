// lib/models/recurring_income_copy.dart
import 'recurring_income.dart';
import 'pay_period.dart';
import 'deductions.dart';

extension RecurringIncomeCopy on RecurringIncome {
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