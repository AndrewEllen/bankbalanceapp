import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/recurring_expense.dart';
import '../models/recurring_income.dart'; // for PayCycle
import '../repositories/recurring_expense_repository.dart';

/// Page for adding or editing a [RecurringExpense]. A recurring expense has a
/// simple fixed amount and a pay cycle. This page reuses the dark theme used
/// throughout the app. The user can choose the first payment date, cycle and
/// whether the expense is enabled. No advanced hourly mode is offered for
/// expenses.
class RecurringExpenseEditPage extends StatefulWidget {
  final RecurringExpense? existing;
  const RecurringExpenseEditPage({super.key, this.existing});

  @override
  State<RecurringExpenseEditPage> createState() => _RecurringExpenseEditPageState();
}

class _RecurringExpenseEditPageState extends State<RecurringExpenseEditPage> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  PayCycle _cycle = PayCycle.every4Weeks;
  DateTime _firstDate = DateTime.now();
  bool _enabled = true;
  final _repo = RecurringExpenseRepository();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _amountCtrl.text = e.amount.toStringAsFixed(2);
      _cycle = e.cycle;
      _firstDate = e.firstPaymentDate;
      _enabled = e.enabled;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.deepPurple,
              onPrimary: Colors.white,
              surface: Color(0xFF1C1C1E),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.black,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _firstDate) {
      setState(() => _firstDate = picked);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (name.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter name and amount')));
      return;
    }
    final id = widget.existing?.id ?? const Uuid().v4();
    final item = RecurringExpense(
      id: id,
      name: name,
      amount: amount,
      cycle: _cycle,
      firstPaymentDate: _firstDate,
      enabled: _enabled,
    );
    await _repo.upsert(item);
    if (mounted) Navigator.pop(context);
  }

  String _cycleLabel(PayCycle c) {
    switch (c) {
      case PayCycle.everyWeek:
        return 'Every week';
      case PayCycle.every2Weeks:
        return 'Every 2 weeks';
      case PayCycle.every4Weeks:
        return 'Every 4 weeks';
      case PayCycle.monthly:
        return 'Monthly';
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMEd();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add Recurring Expense' : 'Edit Recurring Expense'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white54),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.deepPurple),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '£',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white54),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.deepPurple),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Cycle', style: TextStyle(color: Colors.white70)),
                  const SizedBox(width: 16),
                  DropdownButton<PayCycle>(
                    value: _cycle,
                    dropdownColor: Colors.black,
                    style: const TextStyle(color: Colors.white),
                    underline: Container(height: 1, color: Colors.deepPurple),
                    onChanged: (c) => setState(() => _cycle = c!),
                    items: PayCycle.values.map((e) {
                      return DropdownMenuItem(
                        value: e,
                        child: Text(_cycleLabel(e)),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('First payment', style: TextStyle(color: Colors.white70)),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: _selectDate,
                    child: Text(df.format(_firstDate), style: const TextStyle(color: Colors.deepPurple)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _enabled,
                onChanged: (val) => setState(() => _enabled = val),
                title: const Text('Enabled', style: TextStyle(color: Colors.white)),
                activeColor: Colors.deepPurple,
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}