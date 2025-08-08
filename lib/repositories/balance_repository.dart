import '../services/local_store.dart';

/// Repository for persisting the user's manual balance. The balance is stored
/// as a double under a dedicated key in [LocalStore]. The manual balance
/// represents the user's account balance at the moment they set it. Incomes
/// and expenses can be added or subtracted from this value to compute a
/// projected balance.
class BalanceRepository {
  static const _storageKey = 'manual_balance';
  final _store = LocalStore.instance;

  /// Load the manual balance from storage. Returns 0.0 if none is stored.
  Future<double> getBalance() async {
    final raw = await _store.readString(_storageKey);
    if (raw == null) return 0.0;
    return double.tryParse(raw) ?? 0.0;
  }

  /// Save a new manual balance to storage.
  Future<void> setBalance(double balance) async {
    await _store.saveString(_storageKey, balance.toString());
  }

  /// Clear the stored balance (for testing).
  Future<void> clear() async {
    // Persist an empty string to effectively clear the balance. LocalStore
    // does not expose a remove() method.
    await _store.saveString(_storageKey, '0');
  }
}