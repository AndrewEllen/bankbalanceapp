import 'package:flutter/material.dart';
import '../repositories/recurring_income_repository.dart';
import '../models/recurring_income.dart';

/// BODY-ONLY view that can be embedded under a TabBarView.
/// Keep this scaffold-less so it is safe to reuse.
class RecurringIncomeListView extends StatefulWidget {
  const RecurringIncomeListView({super.key});

  @override
  State<RecurringIncomeListView> createState() => _RecurringIncomeListViewState();
}

class _RecurringIncomeListViewState extends State<RecurringIncomeListView> {
  final _repo = RecurringIncomeRepository();
  late Future<List<RecurringIncome>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.load();
  }

  Future<void> _refresh() async {
    final list = await _repo.load();
    if (!mounted) return;
    setState(() { _future = Future.value(list); });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RecurringIncome>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return const Center(
            child: Text('No templates yet.\nTap + to add one.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final it = items[i];
              return Card(
                color: const Color(0xFF1C1C1E),
                child: ListTile(
                  title: Text(it.name, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    it.advanced ? 'Advanced • ${it.cycle.name}' : 'Simple • ${it.cycle.name}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: Switch(
                    value: it.enabled,
                    onChanged: (v) async {
                      final updated = it.copyWith(enabled: v);
                      await _repo.upsert(updated);
                      _refresh();
                    },
                  ),
                  onTap: () async {
                    // Leave your existing navigation to the edit page here
                    // (not included to avoid touching other routes).
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

/// Optional standalone page that uses the body view inside a Scaffold.
/// We removed the "tabs" action to avoid navigating to a page that hosts this page again.
class RecurringIncomeListPage extends StatelessWidget {
  const RecurringIncomeListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Income'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: const RecurringIncomeListView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to your existing "add template" page.
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}