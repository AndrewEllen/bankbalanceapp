import 'package:uuid/uuid.dart';
import '../models/recurring_income.dart';
import '../models/pay_period_instance.dart';
import '../models/pay_period.dart';
import '../repositories/pay_period_instance_repository.dart';

class PayPeriodScheduler {
  static final _instRepo = PayPeriodInstanceRepository();

  /// Ensure there is an instance for each enabled template covering 'now'.
  static Future<void> ensureCurrentInstances(List<RecurringIncome> templates, {DateTime? now}) async {
    now ??= DateTime.now();
    for (final t in templates.where((e) => e.enabled)) {
      final bounds = _currentBoundsFor(t, now);
      if (bounds == null) continue;
      final existing = await _instRepo.findByTemplateAndPayment(t.id, bounds.payday);
      if (existing == null) {
        // seed days
        final days = List<DayHours>.generate(bounds.lengthInDays, (i) {
          final d = DateTime(bounds.start.year, bounds.start.month, bounds.start.day).add(Duration(days: i));
          return DayHours(date: d, baseHours: t.defaultDailyHours ?? 0, extraHours: 0);
        });
        final inst = PayPeriodInstance(
          id: const Uuid().v4(),
          templateId: t.id,
          templateName: t.name,
          periodStart: bounds.start,
          periodEnd: bounds.end,
          paymentDate: bounds.payday,
          days: days,
          carryInHours: 0,
          manualAdjustment: 0,
          simpleOverrideAmount: t.advanced ? null : t.amount,
        );
        await _instRepo.upsert(inst);
      }
    }
  }

  /// Period bounds for the template that contains 'now', else null.
  static _Bounds? _currentBoundsFor(RecurringIncome t, DateTime now) {
    switch (t.cycle) {
      case PayCycle.every4Weeks:
        return _boundsFor4Weeks(t.firstPaymentDate, now);
      case PayCycle.every2Weeks:
        return _boundsForNWeeks(t.firstPaymentDate, now, 2);
      case PayCycle.everyWeek:
        return _boundsForNWeeks(t.firstPaymentDate, now, 1);
      case PayCycle.monthly:
        return _boundsForMonthly(t.firstPaymentDate, now);
    }
  }

  static _Bounds _boundsForNWeeks(DateTime firstPayday, DateTime now, int n) {
    final step = Duration(days: 7 * n);
    final daysSince = now.difference(_dateOnly(firstPayday)).inDays;
    int k = (daysSince / (7 * n)).floor();
    DateTime payday = _dateOnly(firstPayday).add(step * k);
    while (now.isAfter(payday)) {
      k += 1;
      payday = _dateOnly(firstPayday).add(step * k);
    }
    // current period is the one ending at this payday
    final weekNMonday = payday.subtract(Duration(days: payday.weekday - DateTime.monday));
    final start = weekNMonday.subtract(Duration(days: 7 * (n - 1)));
    final end = weekNMonday.add(const Duration(days: 6));
    // If now before start, back up one period
    if (now.isBefore(start)) {
      final prevPayday = payday.subtract(step);
      final prevWeekNMon = prevPayday.subtract(Duration(days: prevPayday.weekday - DateTime.monday));
      final prevStart = prevWeekNMon.subtract(Duration(days: 7 * (n - 1)));
      final prevEnd = prevWeekNMon.add(const Duration(days: 6));
      return _Bounds(prevStart, prevEnd, prevPayday);
    }
    return _Bounds(start, end, payday);
  }

  static _Bounds _boundsFor4Weeks(DateTime firstPayday, DateTime now) {
    final step = const Duration(days: 28);
    final base = _dateOnly(firstPayday);
    final diffDays = now.difference(base).inDays;
    int k = (diffDays / 28).floor();
    DateTime payday = base.add(step * k);
    // find the period where now is within start..end; if before start, back up
    while (true) {
      final week4Mon = payday.subtract(Duration(days: payday.weekday - DateTime.monday));
      final start = week4Mon.subtract(const Duration(days: 21));
      final end = week4Mon.add(const Duration(days: 6));
      if (now.isBefore(start)) {
        k -= 1;
        payday = base.add(step * k);
        continue;
      }
      if (now.isAfter(end)) {
        k += 1;
        payday = base.add(step * k);
        continue;
      }
      return _Bounds(start, end, payday);
    }
  }

  static _Bounds _boundsForMonthly(DateTime firstPayday, DateTime now) {
    // Period runs from the day after previous payday to the payday (inclusive week ending Sunday).
    final base = DateTime(firstPayday.year, firstPayday.month, firstPayday.day);
    DateTime payday = base;
    while (!now.isBefore(payday)) {
      final nextMonth = DateTime(payday.year, payday.month + 1, 1);
      final day = payday.day;
      final lastDay = DateTime(nextMonth.year, nextMonth.month, 0).day;
      final targetDay = day.clamp(1, lastDay);
      payday = DateTime(nextMonth.year, nextMonth.month, targetDay);
    }
    // Now payday is next payday; current period ends the Sunday of its week
    final weekMon = payday.subtract(Duration(days: payday.weekday - DateTime.monday));
    final end = weekMon.add(const Duration(days: 6));
    // previous payday (approx previous month same day, bounded by month length)
    final prevMonth = DateTime(payday.year, payday.month - 1, 1);
    final lastPrev = DateTime(prevMonth.year, prevMonth.month, 0).day;
    final prevPayday = DateTime(prevMonth.year, prevMonth.month, payday.day.clamp(1, lastPrev));
    final prevWeekMon = prevPayday.subtract(Duration(days: prevPayday.weekday - DateTime.monday));
    final start = prevWeekMon.add(const Duration(days: 7)); // Monday after previous payday week
    return _Bounds(start, end, payday);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

class _Bounds {
  final DateTime start;
  final DateTime end;
  final DateTime payday;
  _Bounds(this.start, this.end, this.payday);

  int get lengthInDays => end.difference(start).inDays + 1;
}