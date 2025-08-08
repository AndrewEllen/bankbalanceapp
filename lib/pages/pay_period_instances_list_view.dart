import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/recurring_income_repository.dart';
import '../repositories/pay_period_instance_repository.dart';
import '../models/recurring_income.dart';
import '../models/pay_period_instance.dart';
import '../models/pay_period.dart';
import '../services/pay_period_scheduler.dart';
import 'pay_period_instance_edit_page.dart';

class PayPeriodInstancesListView extends StatefulWidget {
  const PayPeriodInstancesListView({super.key});

  @override
  State<PayPeriodInstancesListView> createState() => _PayPeriodInstancesListViewState();
}

class _PayPeriodInstancesListViewState extends State<PayPeriodInstancesListView> {
  final _recRepo = RecurringIncomeRepository();
  final _instRepo = PayPeriodInstanceRepository();
  late Future<List<PayPeriodInstance>> _future;

  @override
  void initState() {
    super.initState();
    _future = _ensureAndLoad();
  }

  Future<List<PayPeriodInstance>> _ensureAndLoad() async {
    final templates = await _recRepo.load();
    await PayPeriodScheduler.ensureCurrentInstances(templates);
    final all = await _instRepo.getAll();
    final now = DateTime.now();
    // show active or upcoming within next period window
    final visible = all.where((p) =>
      !now.isBefore(DateTime(p.periodStart.year, p.periodStart.month, p.periodStart.day)) &&
      !now.isAfter(DateTime(p.periodEnd.year, p.periodEnd.month, p.periodEnd.day))
    ).toList()
      ..sort((a,b) => a.paymentDate.compareTo(b.paymentDate));
    return visible;
  }

  Future<void> _refresh() async {
    final list = await _ensureAndLoad();
    if (!mounted) return;
    setState(() { _future = Future.value(list); });
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();
    return FutureBuilder<List<PayPeriodInstance>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return const Center(
            child: Text('No active pay periods yet. They will appear automatically when a new period starts.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
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
                  title: Text(it.templateName, style: const TextStyle(color: Colors.white)),
                  subtitle: Text('Period: ${df.format(it.periodStart)} – ${df.format(it.periodEnd)}\nPayday: ${df.format(it.paymentDate)}', style: const TextStyle(color: Colors.white70)),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                  onTap: () async {
                    // Need the template to edit
                    final templates = await _recRepo.load();
                    final t = templates.firstWhere((t) => t.id == it.templateId);
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => PayPeriodInstanceEditPage(template: t, instance: it)));
                    _refresh();
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