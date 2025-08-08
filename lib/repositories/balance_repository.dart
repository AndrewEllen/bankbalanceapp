import 'dart:convert';
import '../services/local_store.dart';

/// Repository for persisting the user's manual balance. The balance is stored
/// as a double under a dedicated key in [LocalStore]. The manual balance
/// represents the user's account balance at the moment they set it. Incomes
/// and expenses can be added or subtracted from this value to compute a
/// projected balance.
class BalanceRepository {
  static const _storageKey = 'manual_balance';
  final _store = LocalStore.instance;

  /// Data structure representing the stored manual balance and the timestamp
  /// when it was set. The [value] is the manual balance, and [setDate] is
  /// when it was recorded. Storing the timestamp allows us to compute
  /// incomes and expenses only after the balance was set.
  static const _dateKey = 'manual_balance_date';

  /// Load the manual balance from storage. Returns 0.0 if none is stored.
  /// If the stored value is a JSON object with `value` and `timestamp`,
  /// parse accordingly. Otherwise, interpret the raw string as a number.
  Future<double> getBalance() async {
    final raw = await _store.readString(_storageKey);
    if (raw == null || raw.isEmpty) return 0.0;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded.containsKey('value')) {
        return double.tryParse(decoded['value'].toString()) ?? 0.0;
      }
    } catch (_) {
      // ignore and fall through
    }
    return double.tryParse(raw) ?? 0.0;
  }

  /// Load both the manual balance and the timestamp when it was set. If no
  /// timestamp is stored the current time is returned. If the stored value
  /// is not JSON, the timestamp defaults to now.
  Future<Map<String, dynamic>> getBalanceData() async {
    final raw = await _store.readString(_storageKey);
    if (raw == null || raw.isEmpty) {
      // No manual balance set yet – use zero and epoch timestamp so that
      // all historical incomes and expenses are included in the balance.
      return {
        'value': 0.0,
        'timestamp': DateTime.fromMillisecondsSinceEpoch(0),
      };
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded.containsKey('value')) {
        final value = double.tryParse(decoded['value'].toString()) ?? 0.0;
        final tsStr = decoded['timestamp']?.toString();
        DateTime ts;
        if (tsStr != null) {
          ts = DateTime.tryParse(tsStr) ?? DateTime.now();
        } else {
          ts = DateTime.now();
        }
        return {
          'value': value,
          'timestamp': ts,
        };
      }
    } catch (_) {
      // ignore parse error
    }
    final val = double.tryParse(raw) ?? 0.0;
    return {
      'value': val,
      'timestamp': DateTime.now(),
    };
  }

  /// Save a new manual balance to storage. Stores both the value and
  /// timestamp as a JSON string. Persisting the timestamp allows the
  /// application to ignore incomes and expenses that occurred before the
  /// manual balance was set.
  Future<void> setBalance(double balance) async {
    final payload = jsonEncode({
      'value': balance,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await _store.saveString(_storageKey, payload);
  }

  /// Clear the stored balance (for testing). Sets the value to 0.0 and
  /// timestamp to now.
  Future<void> clear() async {
    final payload = jsonEncode({
      'value': 0.0,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await _store.saveString(_storageKey, payload);
  }
}