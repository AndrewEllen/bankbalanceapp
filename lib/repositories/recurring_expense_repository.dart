import 'dart:convert';

import '../models/recurring_expense.dart';
import '../services/local_store.dart';

/// Repository for managing [RecurringExpense] objects. Uses [LocalStore]
/// to persist a list of recurring expenses. Expenses are stored under a
/// dedicated key and will survive app restarts.
class RecurringExpenseRepository {
  static const _storageKey = 'recurring_expenses';
  final _store = LocalStore.instance;

  /// Load all recurring expenses from storage.
  Future<List<RecurringExpense>> loadAll() async {
    final raw = await _store.readString(_storageKey);
    if (raw == null) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((e) => RecurringExpense.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Persist the provided list of expenses to storage.
  Future<void> _saveAll(List<RecurringExpense> items) async {
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await _store.saveString(_storageKey, encoded);
  }

  /// Add or update a recurring expense. If an existing item with the same id
  /// exists it will be replaced, otherwise it will be appended.
  Future<void> upsert(RecurringExpense item) async {
    final items = await loadAll();
    final idx = items.indexWhere((e) => e.id == item.id);
    if (idx == -1) {
      items.add(item);
    } else {
      items[idx] = item;
    }
    await _saveAll(items);
  }

  /// Delete a recurring expense by id.
  Future<void> delete(String id) async {
    final items = await loadAll();
    items.removeWhere((e) => e.id == id);
    await _saveAll(items);
  }

  /// Clear all expenses (for testing purposes).
  Future<void> clear() async {
    // Clearing is implemented by saving an empty array to the key. LocalStore
    // does not expose a remove() method, so persisting an empty list
    // effectively resets the storage.
    await _store.saveString(_storageKey, jsonEncode([]));
  }
}