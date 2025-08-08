import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/recurring_income.dart';
import '../models/pay_period.dart' as pp;
import '../models/pay_period_instance.dart';
import '../repositories/recurring_income_repository.dart';
import '../repositories/pay_period_instance_repository.dart';
import '../repositories/break_rules_repository.dart';
import '../services/deductions_service.dart';
import '../extensions/recurring_extensions.dart';
import 'pay_period_instance_edit_page.dart';

/// Body‑only widget that lists live pay period instances. This view ensures
/// that a current instance exists for each enabled recurring income template
/// and displays computed gross/net amounts. It does not include a
/// [Scaffold] or [AppBar] and is intended for use within a tabbed page.
class PayPeriodInstancesListView extends StatefulWidget {
  const PayPeriodInstancesListView({super.key});

  @override
  State<PayPeriodInstancesListView> createState() => _PayPeriodInstancesListViewState();
}

class _PayPeriodInstancesListViewState extends State<PayPeriodInstancesListView> {
  final _templatesRepo = RecurringIncomeRepository();
  final _instRepo = PayPeriodInstanceRepository();
  final _breakRepo = BreakRulesRepository();
  final _deductionsService = const DeductionsService();

  late Future<List<_RowData>> _futureRows;

  @override
  void initState() {
    super.initState();
    _futureRows = _loadRows();
  }

  Future<void> _reload() async {
    setState(() {
      _futureRows = _loadRows();
    });
  }

  Future<List<_RowData>> _loadRows() async {
    final templates = await _templatesRepo.load();
    final now = DateTime.now();
    final rows = <_RowData>[];
    for (final t in templates.where((t) => t.enabled)) {
      // Determine the next payday on or after today.
      final nextPayday = _nextOnOrAfter(t.firstPaymentDate, t.cycle, now);
      // Derive period start/end based on the payday and cycle.
      final ps = _periodStartFor(nextPayday, t.cycle);
      final pe = _periodEndFor(nextPayday, t.cycle);

      // Look up an existing instance for this payment date.
      var inst = await _instRepo.findByTemplateAndPayment(t.id, nextPayday);
      // If not found, create one and persist. Seed days from template if available.
      if (inst == null) {
        // Compute carry‑in hours from previous instance.
        final prevPayday = _previousPayday(t.firstPaymentDate, t.cycle, nextPayday);
        final prevInst = await _instRepo.findByTemplateAndPayment(t.id, prevPayday);
        final carryIn = prevInst?.carryOutHours ?? 0.0;
        // Build days list: copy from template if it has saved periodDays.
        final List<pp.DayHours> days = t.periodDays
                ?.map((e) => pp.DayHours(date: e.date, baseHours: e.baseHours, extraHours: e.extraHours))
                .toList() ??
            _buildDays(ps, pe);
        inst = PayPeriodInstance(
          id: const Uuid().v4(),
          templateId: t.id,
          templateName: t.name,
          periodStart: ps,
          periodEnd: pe,
          paymentDate: nextPayday,
          days: days,
          carryInHours: carryIn,
          manualAdjustment: 0,
          simpleOverrideAmount: null,
          carryOutHours: 0,
          closed: false,
        );
        await _instRepo.upsert(inst);
      }
      // Compute display amount and update carryOutHours if needed.
      String amountLabel;
      double newCarryOut = 0;
      if (t.advanced && (t.hourly ?? 0) > 0) {
        // Calculate paid hours per day after breaks and cut‑off.
        double dayPaidIncluded = 0.0;
        double carryOutPaid = 0.0;
        for (final d in inst.days) {
          final baseOnly = await _paidHoursAfterBreaks(d.baseHours);
          final withExtra = await _paidHoursAfterBreaks(d.baseHours + d.extraHours);
          final extraPaidPortion = (withExtra - baseOnly).clamp(0, double.infinity);
          if (_isAfterOtCutoff(d.date, inst.paymentDate)) {
            // Extra after cutoff carries to next period.
            carryOutPaid += extraPaidPortion;
            dayPaidIncluded += baseOnly;
          } else {
            dayPaidIncluded += withExtra;
          }
        }
        final totalPaid = dayPaidIncluded + inst.carryInHours + inst.manualAdjustment;
        final hourlyRate = t.hourly ?? 0;
        final gross = totalPaid * hourlyRate;
        if (hourlyRate == 0) {
          amountLabel = '—';
        } else if (t.deductions != null) {
          final ded = _deductionsService.computeNetForPeriod(
            periodGross: gross,
            periodsPerYear: t.cycle.periodsPerYear,
            s: t.deductions!,
          );
          final net = ded['net'] ?? gross;
          amountLabel = '£${net.toStringAsFixed(2)}';
        } else {
          amountLabel = '£${gross.toStringAsFixed(2)}';
        }
        newCarryOut = carryOutPaid;
      } else {
        // Simple template.
        final amount = inst.simpleOverrideAmount ?? t.amount;
        amountLabel = amount > 0 ? '£${amount.toStringAsFixed(2)}' : '—';
      }
      // Update carryOutHours on instance if it changed.
      if (newCarryOut != inst.carryOutHours) {
        inst = inst.copyWith(carryOutHours: newCarryOut);
        await _instRepo.upsert(inst);
      }
      rows.add(_RowData(t, inst, amountLabel));
    }
    // Sort by payment date ascending.
    rows.sort((a, b) => a.instance.paymentDate.compareTo(b.instance.paymentDate));
    return rows;
  }

  // Build an inclusive list of days between [start] and [end].
  List<pp.DayHours> _buildDays(DateTime start, DateTime end) {
    final days = <pp.DayHours>[];
    var d = DateTime(start.year, start.month, start.day);
    while (!d.isAfter(end)) {
      days.add(pp.DayHours(date: d, baseHours: 0, extraHours: 0));
      d = d.add(const Duration(days: 1));
    }
    return days;
  }

  DateTime _mondayOf(DateTime d) {
    final diff = d.weekday - DateTime.monday;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: diff));
  }

  DateTime _periodStartFor(DateTime payday, PayCycle c) {
    switch (c) {
      case PayCycle.every4Weeks:
        return _mondayOf(payday).subtract(const Duration(days: 21));
      case PayCycle.every2Weeks:
        return _mondayOf(payday).subtract(const Duration(days: 13));
      case PayCycle.everyWeek:
        return _mondayOf(payday);
      case PayCycle.monthly:
        return DateTime(payday.year, payday.month, 1);
    }
  }

  DateTime _periodEndFor(DateTime payday, PayCycle c) {
    switch (c) {
      case PayCycle.every4Weeks:
      case PayCycle.every2Weeks:
      case PayCycle.everyWeek:
        return _mondayOf(payday).add(const Duration(days: 6));
      case PayCycle.monthly:
        final firstNext = DateTime(payday.year, payday.month + 1, 1);
        return firstNext.subtract(const Duration(days: 1));
    }
  }

  DateTime _nextOnOrAfter(DateTime first, PayCycle c, DateTime date) {
    DateTime p = first;
    Duration step;
    switch (c) {
      case PayCycle.everyWeek:
        step = const Duration(days: 7);
        break;
      case PayCycle.every2Weeks:
        step = const Duration(days: 14);
        break;
      case PayCycle.every4Weeks:
        step = const Duration(days: 28);
        break;
      case PayCycle.monthly:
        step = const Duration(days: 0);
        break;
    }
    if (c == PayCycle.monthly) {
      while (p.isBefore(date)) {
        final m = p.month + 1;
        final y = p.year + (m > 12 ? 1 : 0);
        final mm = ((m - 1) % 12) + 1;
        final day = p.day.clamp(1, DateTime(y, mm + 1, 0).day);
        p = DateTime(y, mm, day, p.hour, p.minute, p.second, p.millisecond, p.microsecond);
      }
      return p;
    } else {
      while (p.isBefore(date)) {
        p = p.add(step);
      }
      return p;
    }
  }

  /// Compute the payday immediately preceding [nextPayday] given the first
  /// payment date and cycle. For weekly cycles this subtracts the cycle
  /// duration until reaching the previous payday.
  DateTime _previousPayday(DateTime first, PayCycle c, DateTime nextPayday) {
    // Walk forward until we exceed nextPayday then subtract one step.
    DateTime p = first;
    Duration step;
    switch (c) {
      case PayCycle.everyWeek:
        step = const Duration(days: 7);
        break;
      case PayCycle.every2Weeks:
        step = const Duration(days: 14);
        break;
      case PayCycle.every4Weeks:
        step = const Duration(days: 28);
        break;
      case PayCycle.monthly:
        step = const Duration(days: 0);
        break;
    }
    if (c == PayCycle.monthly) {
      // For monthly, subtract one month.
      final m = nextPayday.month - 1;
      final y = nextPayday.year - (m < 1 ? 1 : 0);
      final mm = ((m - 1) % 12) + 1;
      final day = nextPayday.day.clamp(1, DateTime(y, mm + 1, 0).day);
      return DateTime(y, mm, day, nextPayday.hour, nextPayday.minute, nextPayday.second, nextPayday.millisecond, nextPayday.microsecond);
    } else {
      DateTime prev = first;
      while (!p.isAfter(nextPayday)) {
        prev = p;
        p = p.add(step);
        if (!p.isAfter(nextPayday)) {
          prev = p;
        }
      }
      return prev;
    }
  }

  bool _isAfterOtCutoff(DateTime date, DateTime payday) {
    // Week 4 Monday
    final int diff = payday.weekday - DateTime.monday;
    final week4Monday = DateTime(payday.year, payday.month, payday.day).subtract(Duration(days: diff));
    final week3Monday = week4Monday.subtract(const Duration(days: 7));
    final cutoff = week3Monday.add(const Duration(days: 2)); // Wed of Week 3
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(cutoff);
  }

  Future<double> _paidHoursAfterBreaks(double hours) async {
    final mins = await _breakRepo.breakFor(hours);
    final paid = ((hours * 60) - mins) / 60.0;
    return paid < 0 ? 0 : paid;
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();
    return FutureBuilder<List<_RowData>>(
      future: _futureRows,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snap.data!;
        if (rows.isEmpty) {
          return const Center(child: Text('No templates enabled.', style: TextStyle(color: Colors.white70)));
        }
        return RefreshIndicator(
          onRefresh: () async {
            await _reload();
          },
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              final t = r.template;
              final inst = r.instance;
              return Card(
                color: const Color(0xFF1C1C1E),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(
                    t.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Period ${df.format(inst.periodStart)} – ${df.format(inst.periodEnd)}  •  Payday ${df.format(inst.paymentDate)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: Text(
                    r.amountLabel,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  onTap: () async {
                    final res = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PayPeriodInstanceEditPage(template: t, instance: inst),
                      ),
                    );
                    if (res != null && mounted) {
                      await _reload();
                    }
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Internal helper object to bundle a template, its instance and the
/// formatted amount label.
class _RowData {
  final RecurringIncome template;
  final PayPeriodInstance instance;
  final String amountLabel;
  _RowData(this.template, this.instance, this.amountLabel);
}