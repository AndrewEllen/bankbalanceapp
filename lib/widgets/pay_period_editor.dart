
// lib/widgets/pay_period_editor.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pay_period.dart' as pp;
import '../repositories/break_rules_repository.dart';

/// Editor for a 4-week pay period (Mon–Sun x4) ending in the
/// week that contains the given [paymentDate].
/// - Supports base + extra hours per day.
/// - After the OT cut‑off (Wed of Week 3) extra is ignored.
/// - "Paid" hours use your BreakRulesRepository to subtract breaks.
class PayPeriodEditor extends StatefulWidget {
  /// Payday (falls somewhere in week 4). We derive the 28‑day window from this.
  final DateTime paymentDate;

  /// Default hours/day used by the ✨ quick‑fill button.
  final double defaultDailyHours;

  /// Optional seed values to prefill day fields.
  final List<pp.DayHours>? initialDays;

  /// Emits the full list whenever anything changes (after frame to avoid setState loops).
  final ValueChanged<List<pp.DayHours>> onChanged;

  const PayPeriodEditor({
    super.key,
    required this.paymentDate,
    required this.defaultDailyHours,
    required this.onChanged,
    this.initialDays,
  });

  @override
  State<PayPeriodEditor> createState() => _PayPeriodEditorState();
}

class _PayPeriodEditorState extends State<PayPeriodEditor> {
  // Data for the 28 days, Monday‑Sunday x 4 weeks.
  late final List<pp.DayHours> _days;
  final Map<DateTime, TextEditingController> _baseCtrls = {};
  final Map<DateTime, TextEditingController> _extraCtrls = {};
  final Map<DateTime, double> _paidCache = {};

  final _defaultHoursCtrl = TextEditingController();
  final _breakRepo = BreakRulesRepository();

  final _chipDf = DateFormat('MM/dd');
  final _dowDf  = DateFormat('EEE'); // Mon, Tue, ...

  @override
  void initState() {
    super.initState();
    _defaultHoursCtrl.text = _toText(widget.defaultDailyHours);

    // Build 28‑day period: Week 4 is the week containing payday.
    final week4Mon = _mondayOf(widget.paymentDate);
    final start = week4Mon.subtract(const Duration(days: 21)); // Monday of week1
    _days = List.generate(28, (i) {
      final d = DateTime(start.year, start.month, start.day).add(Duration(days: i));
      return pp.DayHours(date: d);
    });

    // Prefill from initialDays (if provided)
    final map = {
      for (final d in (widget.initialDays ?? const <pp.DayHours>[]))
        _dateOnly(d.date): d,
    };

    for (final d in _days) {
      _baseCtrls[d.date] = TextEditingController(text: _toText(map[d.date]?.baseHours ?? 0));
      _extraCtrls[d.date] = TextEditingController(text: _toText(map[d.date]?.extraHours ?? 0));
      _paidCache[d.date] = 0;
    }

    // Calculate initial paid values.
    _recalcAll();
  }

  @override
  void dispose() {
    for (final c in _baseCtrls.values) c.dispose();
    for (final c in _extraCtrls.values) c.dispose();
    _defaultHoursCtrl.dispose();
    super.dispose();
  }

  // ---------- Helpers ----------

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _mondayOf(DateTime d) {
    final only = _dateOnly(d);
    final diff = only.weekday - DateTime.monday;
    return only.subtract(Duration(days: diff));
  }

  bool _isAfterOtCutoff(DateTime d) {
    // Week 4 Monday
    final w4m = _mondayOf(widget.paymentDate);
    final w3m = w4m.subtract(const Duration(days: 7));
    final cutoff = w3m.add(const Duration(days: 2)); // Wed of Week 3
    return !_dateOnly(d).isBefore(cutoff);
  }

  String _toText(double v) => v == 0 ? '' : v.toString();

  Future<void> _recalcPaid(pp.DayHours day) async {
    final base = double.tryParse(_baseCtrls[day.date]?.text.trim() ?? '') ?? 0.0;
    final extra = double.tryParse(_extraCtrls[day.date]?.text.trim() ?? '') ?? 0.0;

    day.baseHours = base;
    day.extraHours = extra;

    final includedExtra = _isAfterOtCutoff(day.date) ? 0.0 : extra;
    final total = base + includedExtra;

    final breakMin = await _breakRepo.breakFor(total);
    final paid = ((total * 60) - breakMin) / 60.0;
    _paidCache[day.date] = paid < 0 ? 0 : paid;

    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onChanged(_days);
      });
    }
  }

  Future<void> _recalcAll() async {
    for (final d in _days) {
      await _recalcPaid(d);
    }
  }

  double get _totalPaid =>
      _days.fold(0.0, (sum, d) => sum + (_paidCache[d.date] ?? 0.0));

  double get _totalBase =>
      _days.fold(0.0, (sum, d) => sum + (double.tryParse(_baseCtrls[d.date]?.text.trim() ?? '') ?? 0.0));

  double get _totalExtraIncluded =>
      _days.fold(0.0, (sum, d) {
        final extra = double.tryParse(_extraCtrls[d.date]?.text.trim() ?? '') ?? 0.0;
        return sum + (_isAfterOtCutoff(d.date) ? 0.0 : extra);
      });

  List<List<pp.DayHours>> get _weeks {
    final weeks = <List<pp.DayHours>>[];
    for (int w = 0; w < 4; w++) {
      weeks.add(_days.sublist(w * 7, (w + 1) * 7));
    }
    return weeks;
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    const cardColor = Color(0xFF1C1C1E);
    const border = OutlineInputBorder(borderSide: BorderSide(color: Colors.white24));
    const densePad = EdgeInsets.symmetric(horizontal: 8, vertical: 8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pay period (Mon–Sun x 4; payday in last week)',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        // Default hours control
        Row(
          children: [
            const Text('Default hrs/day', style: TextStyle(color: Colors.white70)),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: TextField(
                controller: _defaultHoursCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: densePad,
                  enabledBorder: border, focusedBorder: border,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Use the ✨ button on a day to apply',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Four weeks
        ..._weeks.indexed.map((entry) {
          final wIdx = entry.$1;
          final days = entry.$2;
          return Card(
            color: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.white12),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Week ${wIdx + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const _HeaderRow(),
                  const SizedBox(height: 4),
                  ...days.map(_dayRow),
                ],
              ),
            ),
          );
        }),

        const Divider(height: 24, color: Colors.white24),

        // Totals wrap to avoid overflow on small screens.
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _totalsCard('Totals', [
              'Base: ${_totalBase.toStringAsFixed(2)} h',
              'Extra (incl.): ${_totalExtraIncluded.toStringAsFixed(2)} h',
              'Paid (after breaks): ${_totalPaid.toStringAsFixed(2)} h',
            ]),
          ],
        ),
      ],
    );
  }

  Widget _totalsCard(String title, List<String> lines) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ...lines.map((t) => Text(t, style: const TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }

  Widget _dayRow(pp.DayHours day) {
    final afterCutoff = _isAfterOtCutoff(day.date);
    final paid = _paidCache[day.date] ?? 0.0;

    const border = OutlineInputBorder(borderSide: BorderSide(color: Colors.white24));
    const densePad = EdgeInsets.symmetric(horizontal: 8, vertical: 8);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          // Date chip
          Container(
            width: 54,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade700,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Text(_dowDf.format(day.date).toUpperCase(),
                    style: const TextStyle(color: Colors.white70, fontSize: 10)),
                Text(_chipDf.format(day.date),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Base
          Expanded(
            child: TextField(
              controller: _baseCtrls[day.date],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _recalcPaid(day),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Base', labelStyle: TextStyle(color: Colors.white54),
                contentPadding: densePad, enabledBorder: border, focusedBorder: border,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Extra
          Expanded(
            child: TextField(
              controller: _extraCtrls[day.date],
              enabled: !afterCutoff,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _recalcPaid(day),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Extra', labelStyle: const TextStyle(color: Colors.white54),
                contentPadding: densePad, enabledBorder: border, focusedBorder: border,
                helperText: afterCutoff ? 'OT cutoff' : null,
                helperStyle: const TextStyle(fontSize: 10, color: Colors.orangeAccent),
                helperMaxLines: 1,
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Quick fill default
          IconButton(
            tooltip: 'Use default',
            icon: const Icon(Icons.auto_fix_high, size: 18, color: Colors.white70),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              final h = double.tryParse(_defaultHoursCtrl.text.trim())
                  ?? widget.defaultDailyHours;
              _baseCtrls[day.date]!.text = h == 0 ? '' : h.toString();
              _recalcPaid(day);
            },
          ),

          // Paid summary
          const SizedBox(width: 4),
          SizedBox(
            width: 74,
            child: Text(
              '${paid.toStringAsFixed(2)} h',
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        SizedBox(width: 54), // date chip space
        SizedBox(width: 8),
        Expanded(child: Text('Base', style: TextStyle(color: Colors.white54))),
        SizedBox(width: 8),
        Expanded(child: Text('Extra', style: TextStyle(color: Colors.white54))),
        SizedBox(width: 26), // icon
        SizedBox(width: 78, child: Align(
          alignment: Alignment.centerRight,
          child: Text('Paid', style: TextStyle(color: Colors.white54)),
        )),
      ],
    );
  }
}
