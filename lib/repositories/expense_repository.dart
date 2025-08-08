import 'dart:convert';

import '../models/expense.dart';
import '../services/local_store.dart';

/// Repository for managing one-off [Expense] items. Uses [LocalStore] to
/// persist a list of expenses. Expenses are stored under a dedicated key
/// and will survive app restarts.
class ExpenseRepository {
  static const _storageKey = 'expenses';
  final _store = LocalStore.instance;

  /// Load all logged expenses.
  Future<List<Expense>> loadAll() async {
    final raw = await _store.readString(_storageKey);
    if (raw == null) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveAll(List<Expense> items) async {
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await _store.saveString(_storageKey, encoded);
  }

  /// Add a new expense. Items are appended to the end of the list.
  Future<void> add(Expense expense) async {
    final items = await loadAll();
    items.add(expense);
    await _saveAll(items);
  }

  /// Delete an expense by id.
  Future<void> delete(String id) async {
    final items = await loadAll();
    items.removeWhere((e) => e.id == id);
    await _saveAll(items);
  }

  /// Insert or update an expense. If an expense with the same id exists
  /// it will be replaced; otherwise it will be appended. This helper
  /// simplifies editing existing expenses on the home page.
  Future<void> upsert(Expense expense) async {
    final items = await loadAll();
    final idx = items.indexWhere((e) => e.id == expense.id);
    if (idx == -1) {
      items.add(expense);
    } else {
      items[idx] = expense;
    }
    await _saveAll(items);
  }

  /// Clear all expenses.
  Future<void> clear() async {
    // Persist an empty array to clear expenses. LocalStore does not expose
    // a remove() method.
    await _store.saveString(_storageKey, jsonEncode([]));
  }
}