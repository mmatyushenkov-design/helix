import 'package:shared_preferences/shared_preferences.dart';

/// Веб-реализация: JSON-снапшот состояния в localStorage через SharedPreferences.
class LocalStore {
  static const _key = 'snapshot';

  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(_key);

  Future<void> write(String value) async =>
      (await SharedPreferences.getInstance()).setString(_key, value);
}
