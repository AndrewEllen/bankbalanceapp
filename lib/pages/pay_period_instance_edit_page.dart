
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/recurring_income.dart';
import '../models/pay_period.dart' as pp;
import '../models/pay_period_instance.dart';
import '../repositories/pay_period_instance_repository.dart';
import '../repositories/break_rules_repository.dart';
import '../services/deductions_service.dart';
import '../widgets/pay_period_editor.dart';

class PayPeriodInstanceEditPage extends StatefulWidget {
  final RecurringIncome template;
  final PayPeriodInstance instance;
  const PayPeriodInstanceEditPage({
    super.key,
    required this.template,
    required this.instance,
  });

  @override
  State<PayPeriodInstanceEditPage> createState() => _PayPeriodInstanceEditPageState();
}

class _PayPeriodInstanceEditPageState extends State<PayPeriodInstanceEditPage> {
  final _repo = PayPeriodInstanceRepository();
  final _breaks = BreakRulesRepository();
  final _deductions = const DeductionsService();

  late PayPeriodInstance _inst;

  final _carryInCtrl = TextEditingController();
  final _adjustCtrl = TextEditingController();
  final _simpleAmountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _inst = widget.instance;
    _carryInCtrl.text = _inst.carryInHours.toStringAsFixed(2);
    _adjustCtrl.text = _inst.manualAdjustment.toStringAsFixed(2);
    if (!widget.template.advanced) {
      _simpleAmountCtrl.text = (widget.instance.simpleOverrideAmount ?? widget.template.amount).toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _carryInCtrl.dispose();
    _adjustCtrl.dispose();
    _simpleAmountCtrl.dispose();
    super.dispose();
  }

  Future<double> _paidHoursAfterBreaks(double hours) async {
    final mins = await _breaks.breakFor(hours);
    final paid = ((hours * 60) - mins) / 60.0;
    return paid < 0 ? 0 : paid;
  }

  bool _isAfterOtCutoff(DateTime date, DateTime payday) {
    // Week 4 Monday
    final int diff = payday.weekday - DateTime.monday;
    final week4Monday = DateTime(payday.year, payday.month, payday.day).subtract(Duration(days: diff));
    final week3Monday = week4Monday.subtract(const Duration(days: 7));
    final cutoff = week3Monday.add(const Duration(days: 2)); // Wed of W3
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(cutoff);
  }

  int _periodsPerYear(PayCycle c) {
    switch (c) {
      case PayCycle.everyWeek: return 52;
      case PayCycle.every2Weeks: return 26;
      case PayCycle.every4Weeks: return 13;
      case PayCycle.monthly: return 12;
    }
  }

  Future<Map<String, double>> _recalcTotals(List<pp.DayHours> days) async {
    double dayPaidIncluded = 0.0;
    double carryOutPaid = 0.0;
    for (final d in days) {
      final withExtra = await _paidHoursAfterBreaks(d.baseHours + d.extraHours);
      final baseOnly = await _paidHoursAfterBreaks(d.baseHours);
      final extraPaidPortion = (withExtra - baseOnly).clamp(0, double.infinity);
      if (_isAfterOtCutoff(d.date, _inst.paymentDate)) {
        // exclude from this period, carry to next
        carryOutPaid += extraPaidPortion;
        dayPaidIncluded += baseOnly;
      } else {
        dayPaidIncluded += withExtra;
      }
    }
    final carryIn = double.tryParse(_carryInCtrl.text.trim()) ?? 0.0;
    final adjust = double.tryParse(_adjustCtrl.text.trim()) ?? 0.0;
    final totalPaid = dayPaidIncluded + carryIn + adjust;
    return {
      'paidIncluded': dayPaidIncluded,
      'carryOutPaid': carryOutPaid,
      'totalPaid': totalPaid,
    };
  }

  Future<void> _save() async {
    if (!widget.template.advanced) {
      final amt = double.tryParse(_simpleAmountCtrl.text.trim()) ?? widget.template.amount;
      final updated = _inst.copyWith(simpleOverrideAmount: amt);
      await _repo.upsert(updated);
      if (mounted) Navigator.pop(context, {'saved': true});
      return;
    }

    // For advanced templates, compute carry‑out hours before saving.
    final totals = await _recalcTotals(_inst.days);
    final carryOutPaid = totals['carryOutPaid'] ?? 0.0;
    final updated = _inst.copyWith(
      carryInHours: double.tryParse(_carryInCtrl.text.trim()) ?? 0.0,
      manualAdjustment: double.tryParse(_adjustCtrl.text.trim()) ?? 0.0,
      days: _inst.days,
      carryOutHours: carryOutPaid,
    );
    await _repo.upsert(updated);
    if (mounted) Navigator.pop(context, {'saved': true});
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    final df = DateFormat.yMMMd();
    final hourly = t.hourly ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Pay period • ${t.name}'),
      ),
      body: FutureBuilder<Map<String, double>>(
        future: _recalcTotals(_inst.days),
        builder: (context, snap) {
          final totals = snap.data ?? {'paidIncluded': 0.0, 'carryOutPaid': 0.0, 'totalPaid': 0.0};
          final gross = hourly > 0 ? totals['totalPaid']! * hourly : 0.0;
          final periodsPerYear = _periodsPerYear(t.cycle);
          final ded = hourly > 0 && t.deductions != null
              ? const DeductionsService().computeNetForPeriod(
                  periodGross: gross, periodsPerYear: periodsPerYear, s: t.deductions!)
              : const {'gross': 0.0, 'pension': 0.0, 'tax': 0.0, 'ni': 0.0, 'union': 0.0, 'net': 0.0};

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(child: Text('Start: ${df.format(_inst.periodStart)}')),
                  Expanded(child: Text('End: ${df.format(_inst.periodEnd)}')),
                  Expanded(child: Text('Payday: ${df.format(_inst.paymentDate)}')),
                ],
              ),
              const SizedBox(height: 12),
              if (t.advanced) ...[
                PayPeriodEditor(
                  paymentDate: _inst.paymentDate,
                  defaultDailyHours: t.defaultDailyHours ?? 8,
                  initialDays: _inst.days,
                  onChanged: (d) {
                    setState(() {
                      _inst = _inst.copyWith(days: d);
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _carryInCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Carry‑in hours (paid)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _adjustCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Manual adj. (hours)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Summary', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('Included paid (after breaks): ${totals['paidIncluded']!.toStringAsFixed(2)} h'),
                        Text('Carry‑out to next (paid): ${totals['carryOutPaid']!.toStringAsFixed(2)} h'),
                        Text('Carry‑in + adj.: ${(double.tryParse(_carryInCtrl.text) ?? 0 + (double.tryParse(_adjustCtrl.text) ?? 0)).toStringAsFixed(2)} h'),
                        const Divider(),
                        if (hourly == 0) const Text('Set hourly on the template to see gross/net.')
                        else ...[
                          Text('Gross: £${ded['gross']!.toStringAsFixed(2)}'),
                          Text('Pension: £${ded['pension']!.toStringAsFixed(2)}'),
                          Text('Tax: £${ded['tax']!.toStringAsFixed(2)}'),
                          Text('NI: £${ded['ni']!.toStringAsFixed(2)}'),
                          Text('Union: £${ded['union']!.toStringAsFixed(2)}'),
                          const SizedBox(height: 4),
                          Text('Net: £${ded['net']!.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _simpleAmountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount this period (£)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ),
      ),
    );
  }
}
