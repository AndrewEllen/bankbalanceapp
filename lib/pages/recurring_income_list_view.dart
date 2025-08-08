import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/recurring_income.dart';
import '../repositories/recurring_income_repository.dart';
import 'recurring_income_edit_page.dart';
import '../extensions/recurring_extensions.dart';

/// Body‑only widget that lists all recurring income templates. This view does
/// not include its own [Scaffold] or [AppBar]; it is intended to be placed
/// inside a larger page (e.g. a tab). The styling, colours and behaviour
/// mirror the original `RecurringIncomeListPage` but without the wrapper.
class RecurringIncomeListView extends StatefulWidget {
  const RecurringIncomeListView({super.key});

  @override
  State<RecurringIncomeListView> createState() => _RecurringIncomeListViewState();
}

class _RecurringIncomeListViewState extends State<RecurringIncomeListView> {
  final _repo = RecurringIncomeRepository();
  List<RecurringIncome> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.load();
    if (mounted) {
      setState(() => _items = list);
    }
  }

  Future<void> _toggleEnabled(RecurringIncome item, bool value) async {
    // Use the extension copyWith to update the enabled flag.
    final updated = item.copyWith(enabled: value);
    await _repo.upsert(updated);
    await _load();
  }

  Future<void> _deleteItem(RecurringIncome item) async {
    await _repo.remove(item.id);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMEd();
    // Surround in RefreshIndicator for pull‑to‑refresh behaviour.
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final it = _items[i];
          final next = it.nextPaymentAfter(DateTime.now());
          return Card(
            color: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              title: Text(
                it.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${_cycleLabel(it.cycle)} • Next: ${df.format(next ?? DateTime.now())}',
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
                  MaterialPageRoute(builder: (_) => RecurringIncomeEditPage(existing: it)),
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