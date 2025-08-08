import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/recurring_expense.dart';
// Import PayCycle from recurring_income to label cycles for expenses
import '../models/recurring_income.dart';
import '../repositories/recurring_expense_repository.dart';
import 'recurring_expense_edit_page.dart';
// Import PayCycle from recurring_income to label cycles.
import '../models/recurring_income.dart';

/// Body‑only widget that lists all recurring expenses. Like the income list
/// view, this widget omits the [Scaffold] and [AppBar] so that it can be
/// inserted into a tab or another page. Each expense shows its name, the
/// next payment date (or "Disabled"), and the amount. A switch toggles
/// whether the expense is enabled. Tapping an item opens the edit page.
class RecurringExpensesListView extends StatefulWidget {
  const RecurringExpensesListView({super.key});

  @override
  State<RecurringExpensesListView> createState() => _RecurringExpensesListViewState();
}

class _RecurringExpensesListViewState extends State<RecurringExpensesListView> {
  final _repo = RecurringExpenseRepository();
  List<RecurringExpense> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.loadAll();
    if (mounted) {
      setState(() => _items = list);
    }
  }

  Future<void> _toggleEnabled(RecurringExpense item, bool value) async {
    final updated = item.copyWith(enabled: value);
    await _repo.upsert(updated);
    await _load();
  }

  Future<void> _deleteItem(RecurringExpense item) async {
    await _repo.delete(item.id);
    await _load();
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
      default:
        return '';
    }
  }

  DateTime? _nextPayment(RecurringExpense e) {
    // Determine the next payment date after today. Mirror the logic from
    // RecurringIncome.nextPaymentAfter. Uses the expense's firstPaymentDate as
    // the anchor.
    final now = DateTime.now();
    DateTime next = e.firstPaymentDate;
    while (next.isBefore(now)) {
      switch (e.cycle) {
        case PayCycle.everyWeek:
          next = next.add(const Duration(days: 7));
          break;
        case PayCycle.every2Weeks:
          next = next.add(const Duration(days: 14));
          break;
        case PayCycle.every4Weeks:
          next = next.add(const Duration(days: 28));
          break;
        case PayCycle.monthly:
          next = DateTime(next.year, next.month + 1, next.day);
          break;
      }
    }
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMEd();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final it = _items[i];
          String subtitleText;
          if (!it.enabled) {
            subtitleText = '${_cycleLabel(it.cycle)} • Disabled';
          } else {
            final next = _nextPayment(it);
            if (next == null) {
              subtitleText = _cycleLabel(it.cycle);
            } else {
              subtitleText = '${_cycleLabel(it.cycle)} • Next: ${df.format(next)}';
            }
          }
          return Card(
            color: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              title: Text(
                it.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                subtitleText,
                style: const TextStyle(color: Colors.white70),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: it.enabled,
                    onChanged: (val) => _toggleEnabled(it, val),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white70),
                    tooltip: 'Delete',
                    onPressed: () => _deleteItem(it),
                  ),
                ],
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RecurringExpenseEditPage(existing: it)),
                );
                await _load();
              },
            ),
          );
        },
      ),
    );
  }
}