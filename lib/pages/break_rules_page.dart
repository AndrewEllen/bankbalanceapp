// lib/pages/break_rules_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/break_models.dart';
import '../repositories/break_rules_repository.dart';

class BreakRulesPage extends StatefulWidget {
  const BreakRulesPage({super.key});

  @override
  State<BreakRulesPage> createState() => _BreakRulesPageState();
}

class _BreakRulesPageState extends State<BreakRulesPage> {
  final _repo = BreakRulesRepository();
  List<BreakTemplate> _templates = [];
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await _repo.loadTemplates();
    final id = await _repo.loadSelectedTemplateId() ?? t.first.id;
    setState(() {
      _templates = t;
      _selectedId = id;
    });
  }

  void _addCustomRule() {
    final idx = _templates.indexWhere((t) => t.id == 'custom');
    if (idx < 0) return;
    final template = _templates[idx];
    final rules = List<BreakRule>.from(template.rules);
    rules.add(const BreakRule(thresholdHours: 0, breakMinutes: 0));
    _templates[idx] = BreakTemplate(id: template.id, name: template.name, rules: rules);
    setState(() {});
  }

  Future<void> _save() async {
    await _repo.saveTemplates(_templates);
    if (_selectedId != null) {
      await _repo.saveSelectedTemplateId(_selectedId!);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Break Rules'), backgroundColor: Colors.black, foregroundColor: Colors.white),
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton(
        onPressed: _addCustomRule,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final t in _templates) ...[
            RadioListTile<String>(
              value: t.id,
              groupValue: _selectedId,
              onChanged: (v) => setState(() => _selectedId = v),
              title: Text(t.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              activeColor: Colors.deepPurple,
            ),
            if (t.id == 'custom')
              _CustomRulesEditor(
                rules: t.rules,
                onChanged: (newRules) {
                  final idx = _templates.indexWhere((e) => e.id == t.id);
                  _templates[idx] = BreakTemplate(id: t.id, name: t.name, rules: newRules);
                },
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final r in t.rules)
                      Text('≥ ${r.thresholdHours.toStringAsFixed(2)}h → ${r.breakMinutes} min',
                          style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            const Divider(color: Colors.white12),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            child: const Text('Save'),
          )
        ],
      ),
    );
  }
}

class _CustomRulesEditor extends StatefulWidget {
  final List<BreakRule> rules;
  final ValueChanged<List<BreakRule>> onChanged;
  const _CustomRulesEditor({required this.rules, required this.onChanged});

  @override
  State<_CustomRulesEditor> createState() => _CustomRulesEditorState();
}

class _CustomRulesEditorState extends State<_CustomRulesEditor> {
  late List<BreakRule> _rules;

  @override
  void initState() {
    super.initState();
    _rules = List<BreakRule>.from(widget.rules);
    if (_rules.isEmpty) {
      _rules = const [BreakRule(thresholdHours: 4, breakMinutes: 15)];
    }
  }

  void _update(int i, {double? hours, int? minutes}) {
    _rules[i] = _rules[i].copyWith(
      thresholdHours: hours ?? _rules[i].thresholdHours,
      breakMinutes: minutes ?? _rules[i].breakMinutes,
    );
    widget.onChanged(_rules);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < _rules.length; i++)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    controller: TextEditingController(text: _rules[i].thresholdHours.toStringAsFixed(2)),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Threshold (hours)',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                    ),
                    onChanged: (v) => _update(i, hours: double.tryParse(v) ?? _rules[i].thresholdHours),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    controller: TextEditingController(text: _rules[i].breakMinutes.toString()),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Break (min)',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                    ),
                    onChanged: (v) => _update(i, minutes: int.tryParse(v) ?? _rules[i].breakMinutes),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    _rules.removeAt(i);
                    widget.onChanged(_rules);
                    setState(() {});
                  },
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              _rules.add(const BreakRule(thresholdHours: 0, breakMinutes: 0));
              widget.onChanged(_rules);
              setState(() {});
            },
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add rule', style: TextStyle(color: Colors.white)),
          ),
        )
      ],
    );
  }
}
