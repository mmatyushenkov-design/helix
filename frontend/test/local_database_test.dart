import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workout_tracker_frontend/state/app_state.dart';
import 'package:workout_tracker_frontend/storage/file_storage_io.dart';
import 'package:workout_tracker_frontend/storage/local_database.dart';
import 'package:workout_tracker_frontend/storage/local_store_io.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('SQLite: нормализованный снапшот сохраняется и восстанавливается', () async {
    final db = LocalDatabase(factory: databaseFactoryFfi, databasePath: inMemoryDatabasePath);
    final state = AppState()..seed();
    await db.writeSnapshot(state.toJson());

    final snapshot = await db.readSnapshot();
    expect(snapshot, isNotNull);
    final restored = AppState()..seed();
    restored.loadJson(snapshot!);
    expect(restored.cycles.length, state.cycles.length);
    expect(restored.cycles.first.days.first.sets.length, 3);
    expect(restored.log.length, state.log.length);
    expect(restored.accent.toARGB32(), state.accent.toARGB32());

    final rawDb = await db.open();
    expect((await rawDb.query('cycles')).length, state.cycles.length);
    expect((await rawDb.query('workout_entries')).isNotEmpty, isTrue);
    expect((await rawDb.query('workout_sets')).isNotEmpty, isTrue);
    expect((await rawDb.query('exercises')).length, greaterThanOrEqualTo(3));
    await db.close();
  });

  test('Миграция: старый JSON из kv переносится в нормализованные таблицы', () async {
    final directory = await Directory.systemTemp.createTemp('workout-tracker-migration-');
    final path = p.join(directory.path, 'legacy.db');
    final state = AppState()..seed();
    final legacy = LocalDatabase(factory: databaseFactoryFfi, databasePath: path);
    final legacyDb = await legacy.open();
    await legacyDb.insert('kv', {'key': 'snapshot', 'value': jsonEncode(state.toJson())});
    await legacy.close();

    final store = LocalStore(factory: databaseFactoryFfi, databasePath: path);
    final raw = await store.read();
    expect(raw, isNotNull);
    expect((jsonDecode(raw!) as Map<String, dynamic>)['cycles'], hasLength(state.cycles.length));
    await store.close();

    final normalizedDb = LocalDatabase(factory: databaseFactoryFfi, databasePath: path);
    final normalized = await normalizedDb.readSnapshot();
    expect(normalized, isNotNull);
    expect(normalized!['cycles'], hasLength(state.cycles.length));
    final db = await normalizedDb.open();
    expect((await db.query('workout_sets')).isNotEmpty, isTrue);
    expect((await db.query('kv')).single['value'], isNotEmpty);
    await normalizedDb.close();
    await directory.delete(recursive: true);
  });

  test('FileStorage: файлы остаются локальными, а выход за корень запрещён', () async {
    final directory = await Directory.systemTemp.createTemp('workout-tracker-files-');
    final storage = LocalFileStorage(rootDirectory: directory);
    await storage.writeBytes('media/exercise/demo.txt', [1, 2, 3, 4]);

    expect(await storage.exists('media/exercise/demo.txt'), isTrue);
    expect(await storage.readBytes('media/exercise/demo.txt'), orderedEquals([1, 2, 3, 4]));
    await expectLater(storage.writeBytes('../outside.txt', [5]), throwsArgumentError);

    await storage.delete('media/exercise/demo.txt');
    expect(await storage.exists('media/exercise/demo.txt'), isFalse);
    await directory.delete(recursive: true);
  });
}
