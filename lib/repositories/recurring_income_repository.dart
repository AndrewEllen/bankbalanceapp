// lib/repositories/recurring_income_repository.dart
import '../models/recurring_income.dart';
import '../services/local_store.dart';

class RecurringIncomeRepository {
  static const _kKey = 'recurring_incomes_json';

  Future<List<RecurringIncome>> load() async {
    final raw = await LocalStore.instance.readString(_kKey);
    if (raw == null) return [];
    return decodeRecurring(raw);
  }

  Future<void> save(List<RecurringIncome> list) async {
    await LocalStore.instance.saveString(_kKey, encodeRecurring(list));
  }

  Future<void> upsert(RecurringIncome item) async {
    final list = await load();
    final idx = list.indexWhere((e) => e.id == item.id);
    if (idx >= 0) {
      list[idx] = item;
    } else {
      list.add(item);
    }
    await save(list);
  }

  Future<void> remove(String id) async {
    final list = await load();
    list.removeWhere((e) => e.id == id);
    await save(list);
  }
}
