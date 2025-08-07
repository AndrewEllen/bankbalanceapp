// lib/models/break_models.dart
import 'dart:convert';

class BreakRule {
  final double thresholdHours;
  final int breakMinutes;

  const BreakRule({required this.thresholdHours, required this.breakMinutes});

  BreakRule copyWith({double? thresholdHours, int? breakMinutes}) => BreakRule(
        thresholdHours: thresholdHours ?? this.thresholdHours,
        breakMinutes: breakMinutes ?? this.breakMinutes,
      );

  Map<String, dynamic> toJson() => {
        'thresholdHours': thresholdHours,
        'breakMinutes': breakMinutes,
      };

  static BreakRule fromJson(Map<String, dynamic> json) => BreakRule(
        thresholdHours: (json['thresholdHours'] as num).toDouble(),
        breakMinutes: (json['breakMinutes'] as num).toInt(),
      );
}

class BreakTemplate {
  final String id;
  final String name;
  final List<BreakRule> rules;

  const BreakTemplate({required this.id, required this.name, required this.rules});

  /// Returns unpaid break minutes for [shiftHours].
  /// Applies the largest rule whose threshold is <= shiftHours.
  int breakFor(double shiftHours) {
    int minutes = 0;
    final sorted = List<BreakRule>.from(rules); // clone before sorting to avoid unmodifiable list issue
    sorted.sort((a, b) => a.thresholdHours.compareTo(b.thresholdHours));
    for (final r in sorted) {
      if (shiftHours >= r.thresholdHours) minutes = r.breakMinutes;
    }
    return minutes;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rules': rules.map((e) => e.toJson()).toList(),
      };

  static BreakTemplate fromJson(Map<String, dynamic> json) => BreakTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        rules: (json['rules'] as List).map((e) => BreakRule.fromJson(e)).toList(),
      );

  static BreakTemplate tescoDefault() => const BreakTemplate(
        id: 'tesco',
        name: 'Tesco',
        rules: [
          BreakRule(thresholdHours: 4.0, breakMinutes: 15),
          BreakRule(thresholdHours: 6.0, breakMinutes: 30),
          BreakRule(thresholdHours: 8.0, breakMinutes: 60),
          BreakRule(thresholdHours: 9.0, breakMinutes: 90),
        ],
      );
}

String encodeTemplates(List<BreakTemplate> t) => jsonEncode(t.map((e)=>e.toJson()).toList());
List<BreakTemplate> decodeTemplates(String s) =>
    (jsonDecode(s) as List).map((e) => BreakTemplate.fromJson(e)).toList();
