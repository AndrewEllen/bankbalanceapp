// lib/repositories/break_rules_repository.dart
import '../models/break_models.dart';
import '../services/local_store.dart';

class BreakRulesRepository {
  static const _kKeySelectedTemplate = 'break_template_selected_id';
  static const _kKeyTemplates = 'break_templates_json';

  /// Load all templates. If none saved, returns Tesco + an empty Custom template.
  Future<List<BreakTemplate>> loadTemplates() async {
    final raw = await LocalStore.instance.readString(_kKeyTemplates);
    if (raw == null) {
      return [
        BreakTemplate.tescoDefault(),
        const BreakTemplate(id: 'custom', name: 'Custom', rules: []),
      ];
    }
    return decodeTemplates(raw);
  }

  Future<void> saveTemplates(List<BreakTemplate> templates) async {
    await LocalStore.instance.saveString(_kKeyTemplates, encodeTemplates(templates));
  }

  Future<String?> loadSelectedTemplateId() async {
    return LocalStore.instance.readString(_kKeySelectedTemplate);
  }

  Future<void> saveSelectedTemplateId(String id) async {
    await LocalStore.instance.saveString(_kKeySelectedTemplate, id);
  }

  /// Compute unpaid break minutes for a given shift.
  Future<int> breakFor(double shiftHours) async {
    final templates = await loadTemplates();
    final selId = await loadSelectedTemplateId();
    final current = templates.firstWhere(
      (t) => t.id == selId,
      orElse: () => templates.first,
    );
    return current.breakFor(shiftHours);
  }
}
