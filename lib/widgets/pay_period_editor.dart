// lib/widgets/pay_period_editor.dart (v4)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pay_period.dart';
import '../repositories/break_rules_repository.dart';

typedef OnPeriodChanged = void Function(List<DayHours> days);

class PayPeriodEditor extends StatefulWidget {
  /// Payday (the last week shown will contain this date).
  final DateTime paymentDate;
  /// Default daily hours applied when user taps "Use default".
  final double defaultDailyHours;
  final OnPeriodChanged onChanged;

  const PayPeriodEditor({
    super.key,
    required this.paymentDate,
    required this.defaultDailyHours,
    required this.onChanged,
  });

  @override
  State<PayPeriodEditor> createState() => _PayPeriodEditorState();
}

class _PayPeriodEditorState extends State<PayPeriodEditor> {
  final _breakRepo = BreakRulesRepository();
  late List<DayHours> _days; // 28 days Mon..Sun x 4
  final Map<DateTime, TextEditingController> _baseCtrls = {};
  final Map<DateTime, TextEditingController> _extraCtrls = {};
  final Map<DateTime, double> _paidCache = {};
  final _df = DateFormat('EEE dd/MM'); // Mon 05/08

  late DateTime _week4Monday;
  late DateTime _week3Monday;
  late DateTime _otCutoff; // Wednesday of week 3 (inclusive)

  @override
  void initState() {
    super.initState();
    _buildCalendar();
  }

  DateTime _mondayOf(DateTime d) {
    // DateTime weekday: Mon=1 ... Sun=7
    final int diff = d.weekday - DateTime.monday;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: diff));
  }

  void _buildCalendar() {
    // Week 4 is the week containing paymentDate (Mon..Sun)
    _week4Monday = _mondayOf(widget.paymentDate);
    final periodStart = _week4Monday.subtract(const Duration(days: 21)); // 3 weeks before -> Week 1 Monday
    _week3Monday = _week4Monday.subtract(const Duration(days: 7));
    _otCutoff = _week3Monday.add(const Duration(days: 2)); // Wed of week 3

    _days = List.generate(28, (i) => DayHours(date: periodStart.add(Duration(days: i))));
    // init controllers
    for (final d in _days) {
      _baseCtrls[d.date] = TextEditingController(text: d.baseHours == 0 ? '' : d.baseHours.toString());
      _extraCtrls[d.date] = TextEditingController(text: d.extraHours == 0 ? '' : d.extraHours.toString());
    }
    _recalcAll();
    widget.onChanged(_days);
  }

  @override
  void didUpdateWidget(covariant PayPeriodEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paymentDate != widget.paymentDate) {
      // rebuild dates when payment date changes
      for (final c in _baseCtrls.values) { c.dispose(); }
      for (final c in _extraCtrls.values) { c.dispose(); }
      _baseCtrls.clear();
      _extraCtrls.clear();
      _paidCache.clear();
      _buildCalendar();
      setState((){});
    }
  }

  bool _isAfterOtCutoff(DateTime d) => d.isAfter(_otCutoff);

  Future<void> _recalcPaid(DayHours dh) async {
    // Overtime counted only up to and including Wednesday of Week 3
    final includedExtra = _isAfterOtCutoff(dh.date) ? 0.0 : dh.extraHours;
    final totalForBreaks = dh.baseHours + includedExtra;
    final breakMin = await _breakRepo.breakFor(totalForBreaks);
    final paid = ((totalForBreaks * 60) - breakMin) / 60.0;
    setState(() {
      _paidCache[dh.date] = paid < 0 ? 0 : paid;
    });
  }

  Future<void> _recalcAll() async {
    for (final d in _days) {
      await _recalcPaid(d);
    }
  }

  void _notify() => widget.onChanged(_days);

  @override
  void dispose() {
    for (final c in _baseCtrls.values) c.dispose();
    for (final c in _extraCtrls.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weeks = List.generate(4, (w) => _days.sublist(w * 7, (w + 1) * 7));

    // Totals
    double totalBase = 0, totalExtraIncluded = 0, totalPaid = 0;
    for (final d in _days) {
      totalBase += d.baseHours;
      final includedExtra = _isAfterOtCutoff(d.date) ? 0.0 : d.extraHours;
      totalExtraIncluded += includedExtra;
      totalPaid += (_paidCache[d.date] ?? 0);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Default daily hours:', style: TextStyle(color: Colors.white70)),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: TextField(
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'e.g. 4',
                  hintStyle: TextStyle(color: Colors.white38),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                ),
                onSubmitted: (v) {
                  final h = double.tryParse(v) ?? 0;
                  setState(() {
                    for (final d in _days) {
                      d.baseHours = h;
                      _baseCtrls[d.date]!.text = h == 0 ? '' : h.toString();
                    }
                  });
                  _recalcAll();
                  _notify();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        for (var w = 0; w < weeks.length; w++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Week ${w + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          for (final day in weeks[w]) _dayRow(day),
          const Divider(color: Colors.white12),
        ],

        const SizedBox(height: 8),
        _totalsRow(totalBase, totalExtraIncluded, totalPaid),
      ],
    );
  }

  Widget _totalsRow(double base, double extra, double paid) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Expanded(child: Text('Base: ${base.toStringAsFixed(2)}h', style: const TextStyle(color: Colors.white))),
          Expanded(child: Text('Overtime: ${extra.toStringAsFixed(2)}h', style: const TextStyle(color: Color(0xFF9CC9FF)))),
          Expanded(child: Text('Paid after breaks: ${paid.toStringAsFixed(2)}h', style: const TextStyle(color: Color(0xFF7EE787)))),
        ],
      ),
    );
  }

  Widget _dayRow(DayHours day) {
    final paid = _paidCache[day.date];
    final afterCutoff = _isAfterOtCutoff(day.date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(_df.format(day.date), style: const TextStyle(color: Colors.white)),
          ),
          // Base hours
          Expanded(
            child: TextField(
              controller: _baseCtrls[day.date],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Base',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
              onChanged: (v) {
                day.baseHours = double.tryParse(v) ?? 0;
                _recalcPaid(day);
                _notify();
              },
            ),
          ),
          const SizedBox(width: 6),
          // Extra (overtime) hours
          Expanded(
            child: TextField(
              controller: _extraCtrls[day.date],
              enabled: !afterCutoff,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Extra',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: afterCutoff ? Colors.white24 : Colors.white54),
                ),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                fillColor: afterCutoff ? const Color(0xFF2A2A2A) : null,
                filled: afterCutoff,
                helperText: afterCutoff ? 'Not counted after Wed of W3' : null,
                helperStyle: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              onChanged: (v) {
                day.extraHours = double.tryParse(v) ?? 0;
                _recalcPaid(day);
                _notify();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white70),
            tooltip: 'Use default',
            onPressed: () {
              final h = widget.defaultDailyHours;
              day.baseHours = h;
              _baseCtrls[day.date]!.text = h == 0 ? '' : h.toString();
              _recalcPaid(day);
              _notify();
            },
          ),
          SizedBox(
            width: 110,
            child: Text(
              paid == null ? '' : '${paid.toStringAsFixed(2)}h',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
