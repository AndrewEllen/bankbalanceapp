// lib/services/local_store.dart
import 'package:shared_preferences/shared_preferences.dart';

/// A tiny abstraction over SharedPreferences so we can swap it later if needed.
class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();

  Future<void> saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String?> readString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }
}
