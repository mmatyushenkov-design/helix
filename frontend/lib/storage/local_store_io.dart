import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'local_database.dart';

/// Нативное локальное хранилище.
///
/// Наружу сохраняется прежний JSON-интерфейс для AppState, внутри данные
/// записываются в нормализованные SQLite-таблицы. Старый JSON в kv остаётся
/// резервной копией и источником одноразовой миграции.
class LocalStore {
  LocalStore({DatabaseFactory? factory, String? databasePath})
      : _database = LocalDatabase(factory: factory, databasePath: databasePath);

  static const _key = 'snapshot';
  final LocalDatabase _database;

  Future<String?> read() async {
    final normalized = await _database.readSnapshot();
    if (normalized != null) return jsonEncode(normalized);

    final db = await _database.open();
    final rows = await db.query('kv', where: 'key = ?', whereArgs: [_key]);
    if (rows.isEmpty) return null;
    final raw = rows.first['value'] as String;
    try {
      final snapshot = jsonDecode(raw) as Map<String, dynamic>;
      await _database.writeSnapshot(snapshot);
      return jsonEncode(snapshot);
    } catch (_) {
      // Повреждённый старый JSON не мешает приложению открыться на сидах.
      return raw;
    }
  }

  Future<void> write(String value) async {
    final snapshot = jsonDecode(value) as Map<String, dynamic>;
    await _database.writeSnapshot(snapshot);
    final db = await _database.open();
    await db.insert(
      'kv',
      {'key': _key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> close() => _database.close();
}
