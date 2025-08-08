// lib/repositories/pay_period_instance_repository.dart
import 'package:bankbalanceapp/models/pay_period_instance.dart';
import 'package:bankbalanceapp/services/local_store.dart';

class PayPeriodInstanceRepository {
  static const _kKey = 'pay_period_instances_v1';

  Future<List<PayPeriodInstance>> getAll() async {
    final s = await LocalStore.instance.readString(_kKey) ?? '[]';
    return decodePayPeriodInstances(s);
  }

  /// Alias for [getAll] to mirror the naming convention used by other
  /// repositories in this project.
  Future<List<PayPeriodInstance>> loadAll() => getAll();

  Future<void> upsert(PayPeriodInstance it) async {
    final list = await getAll();
    final idx = list.indexWhere((e) => e.id == it.id);
    if (idx >= 0) {
      list[idx] = it;
    } else {
      list.add(it);
    }
    await LocalStore.instance.saveString(_kKey, encodePayPeriodInstances(list));
  }

  Future<void> remove(String id) async {
    final list = await getAll();
    list.removeWhere((e) => e.id == id);
    await LocalStore.instance.saveString(_kKey, encodePayPeriodInstances(list));
  }

  /// Alias for [remove]. Provided for symmetry with other repository APIs.
  Future<void> delete(String id) => remove(id);

  /// Returns null if not found.
  Future<PayPeriodInstance?> findByTemplateAndPayment(String templateId, DateTime paymentDate) async {
    final list = await getAll();
    for (final it in list) {
      if (it.templateId == templateId &&
          it.paymentDate.year == paymentDate.year &&
          it.paymentDate.month == paymentDate.month &&
          it.paymentDate.day == paymentDate.day) {
        return it;
      }
    }
    return null;
  }

  /// Find an instance by template and exact period start and end dates.
  /// Returns null if no match is found.
  Future<PayPeriodInstance?> findByTemplateAndDates(String templateId, DateTime periodStart, DateTime periodEnd) async {
    final list = await getAll();
    for (final it in list) {
      if (it.templateId == templateId &&
          it.periodStart.year == periodStart.year &&
          it.periodStart.month == periodStart.month &&
          it.periodStart.day == periodStart.day &&
          it.periodEnd.year == periodEnd.year &&
          it.periodEnd.month == periodEnd.month &&
          it.periodEnd.day == periodEnd.day) {
        return it;
      }
    }
    return null;
  }

  /// Returns the instance whose period window contains the given [date] for the
  /// specified template. Returns null if none found.
  Future<PayPeriodInstance?> currentForTemplate(String templateId, DateTime date) async {
    final list = await getAll();
    for (final it in list) {
      if (it.templateId == templateId && !date.isBefore(it.periodStart) && !date.isAfter(it.periodEnd)) {
        return it;
      }
    }
    return null;
  }
}