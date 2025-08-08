
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/recurring_income.dart';
import '../models/pay_period.dart' as pp;
import '../models/pay_period_instance.dart';
import '../repositories/recurring_income_repository.dart';
import '../repositories/pay_period_instance_repository.dart';
import '../repositories/break_rules_repository.dart';
import 'pay_period_instance_edit_page.dart';

class PayPeriodInstanceListPage extends StatefulWidget {
  const PayPeriodInstanceListPage({super.key});

  @override
  State<PayPeriodInstanceListPage> createState() => _PayPeriodInstanceListPageState();
}

class _PayPeriodInstanceListPageState extends State<PayPeriodInstanceListPage> {
  final _templatesRepo = RecurringIncomeRepository();
  final _instRepo = PayPeriodInstanceRepository();

  @override
  void initState() {
    super.initState();
  }

  Future<List<_Row>> _load() async {
    final templates = await _templatesRepo.load();
    final now = DateTime.now();
    final rows = <_Row>[];
    for (final t in templates.where((t) => t.enabled)) {
      final nextPayday = _nextOnOrAfter(t.firstPaymentDate, t.cycle, now);
      final ps = _periodStartFor(nextPayday, t.cycle);
      final pe = _periodEndFor(nextPayday, t.cycle);
      var inst = await _instRepo.findByTemplateAndPayment(t.id, nextPayday);
      if (inst == null) {
        // seed days from template if available
        final List<pp.DayHours> days = t.periodDays?.map((e) => pp.DayHours(date: e.date, baseHours: e.baseHours, extraHours: e.extraHours)).toList() ??
            _buildDays(ps, pe);
        inst = PayPeriodInstance(
          id: const Uuid().v4(),
          templateId: t.id,
          templateName: t.name,
          periodStart: ps,
          periodEnd: pe,
          paymentDate: nextPayday,
          days: days,
          carryInHours: 0,
          manualAdjustment: 0,
        );
        await _instRepo.upsert(inst);
      }
      rows.add(_Row(t, inst));
    }
    rows.sort((a,b)=> a.instance.paymentDate.compareTo(b.instance.paymentDate));
    return rows;
  }

  List<pp.DayHours> _buildDays(DateTime start, DateTime end) {
    final days=<pp.DayHours>[];
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
        step = const Duration(days: 7); break;
      case PayCycle.every2Weeks:
        step = const Duration(days: 14); break;
      case PayCycle.every4Weeks:
        step = const Duration(days: 28); break;
      case PayCycle.monthly:
        step = const Duration(days: 0); break;
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

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();
    return Scaffold(
      // Darken the background to match the rest of the application
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Pay periods'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<_Row>>(
        future: _load(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return const Center(
              child: Text(
                'No templates enabled.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              return Card(
                color: const Color(0xFF1C1C1E),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(
                    r.template.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Period ${df.format(r.instance.periodStart)} – ${df.format(r.instance.periodEnd)}  •  Payday ${df.format(r.instance.paymentDate)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PayPeriodInstanceEditPage(
                          template: r.template,
                          instance: r.instance,
                        ),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Row {
  final RecurringIncome template;
  final PayPeriodInstance instance;
  _Row(this.template, this.instance);
}
