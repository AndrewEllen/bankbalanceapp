import 'package:flutter/material.dart';
import '../repositories/recurring_income_repository.dart';
import '../models/recurring_income.dart';
import '../models/recurring_income_copy.dart';
import 'recurring_income_edit_page.dart';

/// BODY-ONLY view that can be embedded under a TabBarView.
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

  Future<void> _delete(RecurringIncome it) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text('Delete "${it.name}"? This does not remove any existing pay periods already created.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    await _repo.remove(it.id);
    await _refresh();
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
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No templates yet. Tap + to add one.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringIncomeEditPage()));
                    _refresh();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New template'),
                ),
              ],
            ),
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
              return Dismissible(
                key: ValueKey(it.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  await _delete(it);
                  return false; // we call refresh manually
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.redAccent,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: Card(
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
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => RecurringIncomeEditPage(existing: it)));
                      _refresh();
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}