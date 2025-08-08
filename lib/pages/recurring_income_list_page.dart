import 'recurring_tabs_page.dart';
// lib/pages/recurring_income_list_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recurring_income.dart';
import '../repositories/recurring_income_repository.dart';
import 'recurring_income_edit_page.dart';

class RecurringIncomeListPage extends StatefulWidget {
  const RecurringIncomeListPage({super.key});

  @override
  State<RecurringIncomeListPage> createState() => _RecurringIncomeListPageState();
}

class _RecurringIncomeListPageState extends State<RecurringIncomeListPage> {
  final _repo = RecurringIncomeRepository();
  List<RecurringIncome> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.load();
    setState(() => _items = list);
  }

  String _cycleLabel(PayCycle c) {
    switch (c) {
      case PayCycle.everyWeek: return 'Every week';
      case PayCycle.every2Weeks: return 'Every 2 weeks';
      case PayCycle.every4Weeks: return 'Every 4 weeks';
      case PayCycle.monthly: return 'Monthly';
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMEd();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Income'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
          actions: [IconButton(icon: Icon(Icons.view_week), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_)=> const RecurringTabsPage())); })]
      ),
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringIncomeEditPage()));
          await _load();
        },
        label: const Text('Add Income'),
        icon: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
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
                title: Text(it.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '${_cycleLabel(it.cycle)} • Next: ${df.format(next ?? DateTime.now())}',
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: Text('£${it.amount.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => RecurringIncomeEditPage(existing: it)));
                  await _load();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
