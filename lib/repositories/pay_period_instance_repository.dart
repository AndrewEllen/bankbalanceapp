// lib/repositories/pay_period_instance_repository.dart
import 'package:bankbalanceapp/models/pay_period_instance.dart';
import 'package:bankbalanceapp/services/local_store.dart';

class PayPeriodInstanceRepository {
  static const _kKey = 'pay_period_instances_v1';

  Future<List<PayPeriodInstance>> getAll() async {
    final s = await LocalStore.instance.readString(_kKey) ?? '[]';
    return decodePayPeriodInstances(s);
  }

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
}