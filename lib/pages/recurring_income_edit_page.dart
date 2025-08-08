
// lib/pages/recurring_income_edit_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/recurring_income.dart';
import '../models/pay_period.dart';
import '../repositories/recurring_income_repository.dart';
import '../widgets/pay_period_editor.dart';
import '../services/deductions_service.dart';
import '../models/deductions.dart';
import '../repositories/break_rules_repository.dart';

class RecurringIncomeEditPage extends StatefulWidget {
  final RecurringIncome? existing;
  const RecurringIncomeEditPage({super.key, this.existing});

  @override
  State<RecurringIncomeEditPage> createState() => _RecurringIncomeEditPageState();
}

class _RecurringIncomeEditPageState extends State<RecurringIncomeEditPage> {
  // common
  PayCycle _cycle = PayCycle.every4Weeks;
  DateTime _firstDate = DateTime.now(); // payday
  bool _enabled = true;

  // simple
  final _name = TextEditingController();
  final _amount = TextEditingController();

  // advanced
  final _hourly = TextEditingController();       // base hourly
  final _overtimeHourly = TextEditingController(); // optional overtime hourly (future use)
  double _defaultDaily = 0;
  List<DayHours> _periodDays = [];
  DeductionsSettings _deductions = const DeductionsSettings();
  final _deductionsService = const DeductionsService();
  final _breakRepo = BreakRulesRepository();

  final _repo = RecurringIncomeRepository();
  bool _advanced = false;

  // UI controllers for deductions (persist into _deductions on change)
  final _unionMonthlyCtrl = TextEditingController();
  final _pensionPctCtrl   = TextEditingController();
  final _pensionCapCtrl   = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _amount.text = e.amount.toStringAsFixed(2);
      _cycle = e.cycle;
      _firstDate = e.firstPaymentDate;
      _enabled = e.enabled;
      _advanced = e.advanced;
      if (_advanced) {
        if (e.hourly != null) _hourly.text = e.hourly!.toStringAsFixed(2);
        if (e.overtimeHourly != null) _overtimeHourly.text = e.overtimeHourly!.toStringAsFixed(2);
        _defaultDaily = e.defaultDailyHours ?? 0;
        _periodDays = List<DayHours>.from(e.periodDays ?? []);
      }
      if (e.deductions != null) {
        _deductions = e.deductions!;
      }
    }

    // Seed deductions UI
    _unionMonthlyCtrl.text = _deductions.unionMonthly == 0 ? '' : _deductions.unionMonthly.toStringAsFixed(2);
    _pensionPctCtrl.text   = _deductions.pensionRate == 0 ? '' : (_deductions.pensionRate * 100).toStringAsFixed(2);
    _pensionCapCtrl.text   = _deductions.pensionCap == 0 ? '' : _deductions.pensionCap.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _hourly.dispose();
    _overtimeHourly.dispose();
    _unionMonthlyCtrl.dispose();
    _pensionPctCtrl.dispose();
    _pensionCapCtrl.dispose();
    super.dispose();
  }

  int get _periodsPerYear {
    switch (_cycle) {
      case PayCycle.everyWeek: return 52;
      case PayCycle.every2Weeks: return 26;
      case PayCycle.every4Weeks: return 13;
      case PayCycle.monthly: return 12;
    }
  }

  Future<double> _paidFor(double total) async {
    final breakMin = await _breakRepo.breakFor(total);
    final paid = ((total * 60) - breakMin) / 60.0;
    return paid < 0 ? 0 : paid;
  }

  Future<void> _save() async {
    if (!_advanced) {
      final name = _name.text.trim();
      final amt = double.tryParse(_amount.text.trim()) ?? 0.0;
      if (name.isEmpty || amt <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter name and amount')));
        return;
      }
      final id = widget.existing?.id ?? const Uuid().v4();
      final item = RecurringIncome(
        id: id,
        name: name,
        amount: amt,
        cycle: _cycle,
        firstPaymentDate: _firstDate,
        enabled: _enabled,
        advanced: false,
      );
      await _repo.upsert(item);
      if (mounted) Navigator.pop(context);
      return;
    }

    final base = double.tryParse(_hourly.text.trim()) ?? 0.0;
    if (base <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter hourly rate')));
      return;
    }

    // Refresh deductions from UI
    final unionMonthly = double.tryParse(_unionMonthlyCtrl.text.trim()) ?? 0.0;
    final pensionPct   = (double.tryParse(_pensionPctCtrl.text.trim()) ?? 0.0) / 100.0;
    final pensionCap   = double.tryParse(_pensionCapCtrl.text.trim()) ?? 0.0;
    _deductions = _deductions.copyWith(
      unionMonthly: unionMonthly,
      pensionRate: pensionPct,
      pensionCap: pensionCap,
    );

    // Sum paid hours (with break deduction) per day.
    double totalPaidHours = 0;
    for (final d in _periodDays) {
      final includedExtra = _isAfterOtCutoff(d.date, _firstDate) ? 0.0 : d.extraHours;
      final totalForBreaks = d.baseHours + includedExtra;
      totalPaidHours += await _paidFor(totalForBreaks);
    }

    final periodGross = totalPaidHours * base;
    final res = _deductionsService.computeNetForPeriod(
      periodGross: periodGross,
      periodsPerYear: _periodsPerYear,
      s: _deductions,
    );

    final name = _name.text.trim().isEmpty ? 'Payroll (${_cycle.name})' : _name.text.trim();
    final id = widget.existing?.id ?? const Uuid().v4();
    final item = RecurringIncome(
      id: id,
      name: name,
      amount: res['net'] ?? periodGross,
      cycle: _cycle,
      firstPaymentDate: _firstDate,
      enabled: _enabled,
      advanced: true,
      hourly: base,
      overtimeHourly: double.tryParse(_overtimeHourly.text.trim()),
      defaultDailyHours: _defaultDaily,
      periodDays: _periodDays,
      deductions: _deductions,
    );
    await _repo.upsert(item);
    if (mounted) Navigator.pop(context);
  }

  bool _isAfterOtCutoff(DateTime date, DateTime payday) {
    // Week 4 Monday
    final int diff = payday.weekday - DateTime.monday;
    final week4Monday = DateTime(payday.year, payday.month, payday.day).subtract(Duration(days: diff));
    final week3Monday = week4Monday.subtract(const Duration(days: 7));
    final cutoff = week3Monday.add(const Duration(days: 2)); // Wed of W3
    return date.isAfter(cutoff) || date.isAtSameMomentAs(cutoff);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMEd();
    const card = Color(0xFF1C1C1E);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add Recurring Income' : 'Edit Recurring Income'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Toggle simple vs advanced
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Simple')),
                      ButtonSegment(value: true, label: Text('Advanced')),
                    ],
                    selected: {_advanced},
                    onSelectionChanged: (s) => setState(() => _advanced = s.first),
                    style: const ButtonStyle(
                      foregroundColor: WidgetStatePropertyAll(Colors.white),
                      backgroundColor: WidgetStatePropertyAll(Color(0xFF1C1C1E)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Common: pay cycle + first date + enabled
                  DropdownButtonFormField<PayCycle>(
                    value: _cycle,
                    dropdownColor: card,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Pay Cycle',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                    ),
                    items: const [
                      DropdownMenuItem(value: PayCycle.everyWeek, child: Text('Every week', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: PayCycle.every2Weeks, child: Text('Every 2 weeks', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: PayCycle.every4Weeks, child: Text('Every 4 weeks', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: PayCycle.monthly, child: Text('Monthly', style: TextStyle(color: Colors.white))),
                    ],
                    onChanged: (v) => setState(() => _cycle = v ?? _cycle),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    tileColor: card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.white24)),
                    title: const Text('Payment date', style: TextStyle(color: Colors.white70)),
                    subtitle: Text(df.format(_firstDate), style: const TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.calendar_month, color: Colors.white70),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDate: _firstDate,
                      );
                      if (d != null) setState(() => _firstDate = d);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                    title: const Text('Enabled', style: TextStyle(color: Colors.white)),
                    activeColor: Colors.deepPurple,
                  ),
                  const SizedBox(height: 16),

                  if (!_advanced) ...[
                    TextField(
                      controller: _name,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Amount (£)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: _hourly,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Hourly rate (£)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _overtimeHourly,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Overtime hourly (optional)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Pay period (Mon–Sun x 4; payday in last week)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    PayPeriodEditor(
                      paymentDate: _firstDate,
                      defaultDailyHours: _defaultDaily,
                      initialDays: _periodDays.isNotEmpty ? _periodDays : (widget.existing?.periodDays ?? const []),
                      onChanged: (days) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() { _periodDays = days; });
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _deductionsCard(),
                  ],
                ],
              ),
            ),
            // Pinned Save button above nav
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.black,
                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, -2))],
              ),
              child: SafeArea(
                top: false,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  child: const Text('Save'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deductionsCard() {
    const card = Color(0xFF1C1C1E);
    const border = OutlineInputBorder(borderSide: BorderSide(color: Colors.white24));
    const pad = EdgeInsets.symmetric(horizontal: 8, vertical: 8);
    return Card(
      color: card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Deductions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 170,
                  child: TextField(
                    controller: _unionMonthlyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Union monthly (£)',
                      labelStyle: TextStyle(color: Colors.white70),
                      contentPadding: pad, enabledBorder: border, focusedBorder: border,
                    ),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _pensionPctCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Pension %',
                      labelStyle: TextStyle(color: Colors.white70),
                      contentPadding: pad, enabledBorder: border, focusedBorder: border,
                    ),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: TextField(
                    controller: _pensionCapCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Pension cap/month (£)',
                      labelStyle: TextStyle(color: Colors.white70),
                      contentPadding: pad, enabledBorder: border, focusedBorder: border,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Union is a flat monthly amount. Pension is % with optional monthly cap.',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 16),
            // Button to open the global break rules editor. This allows users to
            // adjust break calculation settings while editing a template.
            TextButton.icon(
              onPressed: () async {
                await Navigator.pushNamed(context, '/break-rules');
              },
              icon: const Icon(Icons.timer_off, color: Colors.deepPurple),
              label: const Text(
                'Edit Break Rules',
                style: TextStyle(color: Colors.deepPurple),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
