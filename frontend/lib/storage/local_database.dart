import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/models.dart';

/// Локальная нормализованная SQLite. JSON нужен только на границе текущего
/// AppState и для переносимого backup; все данные внутри лежат в таблицах.
class LocalDatabase {
  LocalDatabase({DatabaseFactory? factory, String? databasePath})
      : _factory = factory,
        _databasePath = databasePath;

  static const schemaVersion = 3;
  static final _localUserId = stableId('user', 'local');
  final DatabaseFactory? _factory;
  final String? _databasePath;
  Database? _db;

  Future<Database> open() async {
    if (_db != null) return _db!;
    final factory = _factory ?? _defaultFactory();
    final path = _databasePath ??
        p.join(await factory.getDatabasesPath(), 'workout_tracker.db');
    _db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, _) => _createSchema(db),
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion >= 2 && oldVersion < 3) {
            await db.execute(
                'ALTER TABLE workout_template_sets ADD COLUMN planned INTEGER NOT NULL DEFAULT 0');
          }
          await _createSchema(db);
        },
      ),
    );
    await _db!.execute('PRAGMA foreign_keys = ON');
    await _createSchema(_db!);
    await _seedMuscles(_db!);
    return _db!;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static DatabaseFactory _defaultFactory() {
    if (Platform.isAndroid || Platform.isIOS) return databaseFactory;
    sqfliteFfiInit();
    return databaseFactoryFfi;
  }

  static String _now() => DateTime.now().toUtc().toIso8601String();
  static String _entityId(String kind, Object? raw) =>
      raw is int ? stableId(kind, raw) : raw?.toString() ?? newId();

  static Future<void> _createSchema(DatabaseExecutor db) async {
    const statements = [
      'CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      'CREATE TABLE IF NOT EXISTS app_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      '''CREATE TABLE IF NOT EXISTS exercises (
        id TEXT PRIMARY KEY, slug TEXT NOT NULL UNIQUE, owner_id TEXT,
        record_format TEXT NOT NULL DEFAULT 'WEIGHT_REPS', default_step_kg REAL,
        is_custom INTEGER NOT NULL DEFAULT 0, is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT)''',
      '''CREATE TABLE IF NOT EXISTS exercise_translations (
        exercise_id TEXT NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
        language_code TEXT NOT NULL, name TEXT NOT NULL, description TEXT,
        PRIMARY KEY (exercise_id, language_code))''',
      '''CREATE TABLE IF NOT EXISTS muscle_groups (
        id TEXT PRIMARY KEY, code TEXT NOT NULL UNIQUE, position INTEGER NOT NULL)''',
      '''CREATE TABLE IF NOT EXISTS muscles (
        id TEXT PRIMARY KEY, group_id TEXT NOT NULL REFERENCES muscle_groups(id),
        code TEXT NOT NULL UNIQUE, position INTEGER NOT NULL)''',
      '''CREATE TABLE IF NOT EXISTS exercise_muscles (
        exercise_id TEXT NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
        muscle_id TEXT NOT NULL REFERENCES muscles(id), role TEXT NOT NULL,
        PRIMARY KEY (exercise_id, muscle_id))''',
      '''CREATE TABLE IF NOT EXISTS cycles (
        id TEXT PRIMARY KEY, legacy_id INTEGER UNIQUE, owner_id TEXT,
        exercise_id TEXT NOT NULL REFERENCES exercises(id), best_weight_kg REAL NOT NULL,
        best_reps INTEGER NOT NULL, tm_kg REAL NOT NULL, step_kg REAL NOT NULL,
        weight_offset_kg REAL NOT NULL DEFAULT 0, current_day INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT)''',
      '''CREATE TABLE IF NOT EXISTS cycle_days (
        id TEXT PRIMARY KEY, cycle_id TEXT NOT NULL REFERENCES cycles(id) ON DELETE CASCADE,
        position INTEGER NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        deleted_at TEXT, UNIQUE (cycle_id, position))''',
      '''CREATE TABLE IF NOT EXISTS cycle_sets (
        id TEXT PRIMARY KEY, day_id TEXT NOT NULL REFERENCES cycle_days(id) ON DELETE CASCADE,
        position INTEGER NOT NULL, weight_kg REAL, pct INTEGER, reps INTEGER,
        duration_sec INTEGER, distance_m REAL, rir INTEGER, UNIQUE (day_id, position))''',
      '''CREATE TABLE IF NOT EXISTS workout_entries (
        id TEXT PRIMARY KEY, legacy_id INTEGER UNIQUE, owner_id TEXT, date TEXT NOT NULL,
        exercise_id TEXT NOT NULL REFERENCES exercises(id), record_format TEXT NOT NULL DEFAULT 'WEIGHT_REPS',
        cycle_id TEXT REFERENCES cycles(id), cycle_day INTEGER, source_template_item_id TEXT,
        position INTEGER NOT NULL DEFAULT 0, done INTEGER NOT NULL DEFAULT 0,
        bumped INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT)''',
      '''CREATE TABLE IF NOT EXISTS workout_sets (
        id TEXT PRIMARY KEY, entry_id TEXT NOT NULL REFERENCES workout_entries(id) ON DELETE CASCADE,
        position INTEGER NOT NULL, weight_kg REAL, reps INTEGER, duration_sec INTEGER,
        distance_m REAL, rir INTEGER, planned INTEGER NOT NULL DEFAULT 0,
        UNIQUE (entry_id, position))''',
      '''CREATE TABLE IF NOT EXISTS workout_templates (
        id TEXT PRIMARY KEY, owner_id TEXT, name TEXT NOT NULL, description TEXT,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT)''',
      '''CREATE TABLE IF NOT EXISTS workout_template_items (
        id TEXT PRIMARY KEY, template_id TEXT NOT NULL REFERENCES workout_templates(id) ON DELETE CASCADE,
        exercise_id TEXT NOT NULL REFERENCES exercises(id), position INTEGER NOT NULL,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT,
        UNIQUE (template_id, position))''',
      '''CREATE TABLE IF NOT EXISTS workout_template_sets (
        id TEXT PRIMARY KEY, item_id TEXT NOT NULL REFERENCES workout_template_items(id) ON DELETE CASCADE,
        position INTEGER NOT NULL, weight_kg REAL, reps INTEGER, duration_sec INTEGER,
        distance_m REAL, rir INTEGER, planned INTEGER NOT NULL DEFAULT 0,
        UNIQUE (item_id, position))''',
      '''CREATE TABLE IF NOT EXISTS user_settings (
        user_id TEXT PRIMARY KEY, language_code TEXT NOT NULL DEFAULT 'ru',
        weight_unit TEXT NOT NULL DEFAULT 'kg', distance_unit TEXT NOT NULL DEFAULT 'km',
        theme TEXT NOT NULL DEFAULT 'dark', accent INTEGER, sync_enabled INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL)''',
      '''CREATE TABLE IF NOT EXISTS local_files (
        id TEXT PRIMARY KEY, owner_id TEXT, entity_type TEXT, entity_id TEXT, kind TEXT NOT NULL,
        relative_path TEXT NOT NULL, mime_type TEXT NOT NULL, size_bytes INTEGER NOT NULL,
        sha256 TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT)''',
      '''CREATE TABLE IF NOT EXISTS outbox_operations (
        id TEXT PRIMARY KEY, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL,
        operation TEXT NOT NULL, payload_json TEXT NOT NULL, created_at TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0, last_error TEXT)''',
      'CREATE TABLE IF NOT EXISTS sync_state (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      'CREATE INDEX IF NOT EXISTS idx_entries_date ON workout_entries(date, position)',
      'CREATE INDEX IF NOT EXISTS idx_entries_exercise ON workout_entries(exercise_id, date)',
      'CREATE INDEX IF NOT EXISTS idx_sets_entry ON workout_sets(entry_id, position)',
    ];
    for (final statement in statements) {
      await db.execute(statement);
    }
  }

  static Future<void> _seedMuscles(DatabaseExecutor db) async {
    for (var gi = 0; gi < muscleCatalog.length; gi++) {
      final group = muscleCatalog[gi];
      final groupId = stableId('muscle-group', group.code);
      await db.insert(
          'muscle_groups', {'id': groupId, 'code': group.code, 'position': gi},
          conflictAlgorithm: ConflictAlgorithm.ignore);
      for (var mi = 0; mi < group.muscles.length; mi++) {
        final muscle = group.muscles[mi];
        await db.insert(
            'muscles',
            {
              'id': stableId('muscle', muscle.code),
              'group_id': groupId,
              'code': muscle.code,
              'position': mi,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  Future<Map<String, dynamic>?> readSnapshot() async {
    final db = await open();
    final marker = await db.query('app_meta',
        where: 'key = ?', whereArgs: ['snapshot_initialized']);
    if (marker.isEmpty) return null;
    final exercises = <Map<String, dynamic>>[];
    for (final row in await db.query('exercises')) {
      final translations = await db.query('exercise_translations',
          where: 'exercise_id = ?', whereArgs: [row['id']]);
      String name(String lang, String fallback) {
        for (final t in translations) {
          if (t['language_code'] == lang) return t['name'] as String;
        }
        return fallback;
      }

      final links = await db.query('exercise_muscles',
          where: 'exercise_id = ?', whereArgs: [row['id']]);
      final primary = <String>[], secondary = <String>[];
      for (final link in links) {
        final muscle = await db.query('muscles',
            where: 'id = ?', whereArgs: [link['muscle_id']], limit: 1);
        if (muscle.isEmpty) continue;
        (link['role'] == 'primary' ? primary : secondary)
            .add(muscle.first['code'] as String);
      }
      final ru = name('ru', 'Упражнение');
      exercises.add({
        'id': row['id'],
        'nameRu': ru,
        'nameEn': name('en', ru),
        'format': row['record_format'],
        'defaultStepKg': row['default_step_kg'] ?? 5,
        'primaryMuscles': primary,
        'secondaryMuscles': secondary,
        'isCustom': row['is_custom'] == 1,
        'archived': row['is_archived'] == 1,
      });
    }

    final cycleRows = await db.query('cycles',
        where: 'deleted_at IS NULL', orderBy: 'created_at ASC');
    final cycleIds = <String, Object>{};
    final cycles = <Map<String, dynamic>>[];
    for (final row in cycleRows) {
      final id = row['id'] as String;
      final exposedId = row['legacy_id'] ?? id;
      cycleIds[id] = exposedId;
      final days = <Map<String, dynamic>>[];
      final dayRows = await db.query('cycle_days',
          where: 'cycle_id = ? AND deleted_at IS NULL',
          whereArgs: [id],
          orderBy: 'position ASC');
      for (final day in dayRows) {
        final sets = await db.query('cycle_sets',
            where: 'day_id = ?',
            whereArgs: [day['id']],
            orderBy: 'position ASC');
        days.add({
          'sets': [for (final set in sets) _cycleSetJson(set)]
        });
      }
      cycles.add({
        'id': exposedId,
        'exerciseId': row['exercise_id'],
        'name': await _exerciseName(db, row['exercise_id'] as String),
        'bestW': row['best_weight_kg'],
        'bestR': row['best_reps'],
        'tm': row['tm_kg'],
        'step': row['step_kg'],
        'wOffset': row['weight_offset_kg'],
        'curDay': row['current_day'],
        'days': days,
      });
    }

    final log = <String, List<Map<String, dynamic>>>{};
    final entryRows = await db.query('workout_entries',
        where: 'deleted_at IS NULL',
        orderBy: 'date ASC, position ASC, created_at ASC');
    for (final row in entryRows) {
      final sets = await db.query('workout_sets',
          where: 'entry_id = ?',
          whereArgs: [row['id']],
          orderBy: 'position ASC');
      final cycleId = row['cycle_id'] as String?;
      log.putIfAbsent(row['date'] as String, () => []).add({
        'id': row['legacy_id'] ?? row['id'],
        'exerciseId': row['exercise_id'],
        'name': await _exerciseName(db, row['exercise_id'] as String),
        'recordFormat': row['record_format'],
        'cycleId': cycleId == null ? null : cycleIds[cycleId] ?? cycleId,
        'dayIdx': row['cycle_day'],
        'templateItemId': row['source_template_item_id'],
        'done': row['done'] == 1,
        'bumped': row['bumped'] == 1,
        'sets': [for (final set in sets) _diarySetJson(set)],
      });
    }

    final templates = <Map<String, dynamic>>[];
    for (final row
        in await db.query('workout_templates', where: 'deleted_at IS NULL')) {
      final items = <Map<String, dynamic>>[];
      final itemRows = await db.query('workout_template_items',
          where: 'template_id = ? AND deleted_at IS NULL',
          whereArgs: [row['id']],
          orderBy: 'position ASC');
      for (final item in itemRows) {
        final sets = await db.query('workout_template_sets',
            where: 'item_id = ?',
            whereArgs: [item['id']],
            orderBy: 'position ASC');
        items.add({
          'id': item['id'],
          'exerciseId': item['exercise_id'],
          'sets': [for (final s in sets) _diarySetJson(s)]
        });
      }
      templates.add({
        'id': row['id'],
        'name': row['name'],
        'description': row['description'] ?? '',
        'items': items
      });
    }
    final settings = await db.query('user_settings',
        where: 'user_id = ?', whereArgs: [_localUserId]);
    final setting = settings.isEmpty ? null : settings.first;
    return {
      'schemaVersion': 2,
      'exercises': exercises,
      'cycles': cycles,
      'templates': templates,
      'log': log,
      'accent': setting?['accent'],
      'language': setting?['language_code'] ?? 'ru',
      'weightUnit': setting?['weight_unit'] ?? 'kg',
      'distanceUnit': setting?['distance_unit'] ?? 'km',
    };
  }

  static Map<String, dynamic> _cycleSetJson(Map<String, dynamic> row) => {
        'w': row['weight_kg'],
        'pct': row['pct'],
        'reps': row['reps'] ?? 0,
        'rir': row['rir'] ?? 0,
        'durationSec': row['duration_sec'] ?? 0,
        'distanceM': row['distance_m'] ?? 0,
      };

  static Map<String, dynamic> _diarySetJson(Map<String, dynamic> row) => {
        'w': row['weight_kg'] ?? 0,
        'reps': row['reps'] ?? 0,
        'rir': row['rir'] ?? 0,
        'durationSec': row['duration_sec'] ?? 0,
        'distanceM': row['distance_m'] ?? 0,
        'planned': row['planned'] == 1,
      };

  Future<void> writeSnapshot(Map<String, dynamic> snapshot) async {
    final db = await open();
    final now = _now();
    final cycles = [
      for (final c in snapshot['cycles'] as List? ?? const [])
        Map<String, dynamic>.from(c as Map)
    ];
    final log = snapshot['log'] as Map<String, dynamic>? ?? {};
    final templates = [
      for (final t in snapshot['templates'] as List? ?? const [])
        Map<String, dynamic>.from(t as Map)
    ];
    final exercises = <String, Map<String, dynamic>>{
      for (final e in snapshot['exercises'] as List? ?? const [])
        (e['id'] ?? exerciseIdForName(e['nameRu'] as String)).toString():
            Map<String, dynamic>.from(e as Map),
    };
    void ensure(String? id, String name) {
      final key = id ?? exerciseIdForName(name);
      exercises.putIfAbsent(
          key,
          () => {
                'id': key,
                'nameRu': name,
                'nameEn': name,
                'format': 'WEIGHT_REPS'
              });
    }

    for (final c in cycles) {
      ensure(c['exerciseId']?.toString(), c['name'] as String);
    }
    for (final entries in log.values) {
      for (final e in entries as List) {
        ensure(e['exerciseId']?.toString(), e['name'] as String);
      }
    }

    await db.transaction((txn) async {
      await txn.delete('workout_sets');
      await txn.delete('workout_entries');
      await txn.delete('cycle_sets');
      await txn.delete('cycle_days');
      await txn.delete('cycles');
      await txn.delete('workout_template_sets');
      await txn.delete('workout_template_items');
      await txn.delete('workout_templates');
      await txn.delete('exercise_muscles');
      await txn.delete('exercise_translations');
      await txn.delete('exercises');

      for (final entry in exercises.entries) {
        final id = entry.key;
        final e = entry.value;
        final ru =
            e['nameRu'] as String? ?? e['name'] as String? ?? 'Упражнение';
        await txn.insert('exercises', {
          'id': id,
          'slug': e['slug'] ?? 'exercise:$id',
          'owner_id': _localUserId,
          'record_format': e['format'] ?? 'WEIGHT_REPS',
          'default_step_kg': e['defaultStepKg'] ?? 5,
          'is_custom': e['isCustom'] == true ? 1 : 0,
          'is_archived': e['archived'] == true ? 1 : 0,
          'created_at': now,
          'updated_at': now,
        });
        for (final (lang, name) in [
          ('ru', ru),
          ('en', e['nameEn'] as String? ?? ru)
        ]) {
          await txn.insert('exercise_translations', {
            'exercise_id': id,
            'language_code': lang,
            'name': name,
          });
        }
        for (final role in ['primary', 'secondary']) {
          final key = role == 'primary' ? 'primaryMuscles' : 'secondaryMuscles';
          for (final code in e[key] as List? ?? const []) {
            await txn.insert(
                'exercise_muscles',
                {
                  'exercise_id': id,
                  'muscle_id': stableId('muscle', code),
                  'role': role,
                },
                conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
      }

      for (final c in cycles) {
        final id = _entityId('cycle', c['id']);
        final exerciseId = c['exerciseId']?.toString() ??
            exerciseIdForName(c['name'] as String);
        await txn.insert('cycles', {
          'id': id,
          'legacy_id': c['id'] is int ? c['id'] : null,
          'owner_id': _localUserId,
          'exercise_id': exerciseId,
          'best_weight_kg': c['bestW'],
          'best_reps': c['bestR'],
          'tm_kg': c['tm'],
          'step_kg': c['step'],
          'weight_offset_kg': c['wOffset'] ?? 0,
          'current_day': c['curDay'],
          'created_at': now,
          'updated_at': now,
        });
        final days = c['days'] as List;
        for (var di = 0; di < days.length; di++) {
          final dayId = stableId('cycle-day', '$id/$di');
          await txn.insert('cycle_days', {
            'id': dayId,
            'cycle_id': id,
            'position': di,
            'created_at': now,
            'updated_at': now,
          });
          final sets = days[di]['sets'] as List;
          for (var si = 0; si < sets.length; si++) {
            final s = sets[si];
            await txn.insert('cycle_sets', {
              'id': stableId('cycle-set', '$id/$di/$si'),
              'day_id': dayId,
              'position': si,
              'weight_kg': s['w'],
              'pct': s['pct'],
              'reps': s['reps'],
              'rir': s['rir'],
              'duration_sec': s['durationSec'] ?? 0,
              'distance_m': s['distanceM'] ?? 0,
            });
          }
        }
      }

      for (final dateEntry in log.entries) {
        final entries = dateEntry.value as List;
        for (var ei = 0; ei < entries.length; ei++) {
          final e = entries[ei];
          final id = _entityId('entry', e['id']);
          final cycleId =
              e['cycleId'] == null ? null : _entityId('cycle', e['cycleId']);
          await txn.insert('workout_entries', {
            'id': id,
            'legacy_id': e['id'] is int ? e['id'] : null,
            'owner_id': _localUserId,
            'date': dateEntry.key,
            'exercise_id':
                e['exerciseId'] ?? exerciseIdForName(e['name'] as String),
            'record_format': e['recordFormat'] ?? 'WEIGHT_REPS',
            'cycle_id': cycleId,
            'cycle_day': e['dayIdx'],
            'source_template_item_id': e['templateItemId'],
            'position': ei,
            'done': e['done'] == true ? 1 : 0,
            'bumped': e['bumped'] == true ? 1 : 0,
            'created_at': now,
            'updated_at': now,
          });
          final sets = e['sets'] as List;
          for (var si = 0; si < sets.length; si++) {
            await txn.insert('workout_sets', {
              'id': stableId('entry-set', '$id/$si'),
              'entry_id': id,
              'position': si,
              ..._setColumns(sets[si], planned: sets[si]['planned'] == true),
            });
          }
        }
      }

      for (final t in templates) {
        final templateId = t['id'].toString();
        await txn.insert('workout_templates', {
          'id': templateId,
          'owner_id': _localUserId,
          'name': t['name'],
          'description': t['description'] ?? '',
          'created_at': now,
          'updated_at': now,
        });
        final items = t['items'] as List? ?? const [];
        for (var ii = 0; ii < items.length; ii++) {
          final item = items[ii];
          final itemId = item['id'].toString();
          await txn.insert('workout_template_items', {
            'id': itemId,
            'template_id': templateId,
            'exercise_id': item['exerciseId'],
            'position': ii,
            'created_at': now,
            'updated_at': now,
          });
          final sets = item['sets'] as List? ?? const [];
          for (var si = 0; si < sets.length; si++) {
            await txn.insert('workout_template_sets', {
              'id': stableId('template-set', '$itemId/$si'),
              'item_id': itemId,
              'position': si,
              ..._setColumns(sets[si]),
            });
          }
        }
      }

      await txn.insert(
          'user_settings',
          {
            'user_id': _localUserId,
            'language_code': snapshot['language'] ?? 'ru',
            'weight_unit': snapshot['weightUnit'] ?? 'kg',
            'distance_unit': snapshot['distanceUnit'] ?? 'km',
            'theme': 'dark',
            'accent': snapshot['accent'],
            'sync_enabled': 0,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert(
          'app_meta', {'key': 'snapshot_initialized', 'value': '1'},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  static Map<String, dynamic> _setColumns(Map<String, dynamic> s,
          {bool planned = false}) =>
      {
        'weight_kg': s['w'] ?? 0,
        'reps': s['reps'] ?? 0,
        'duration_sec': s['durationSec'] ?? 0,
        'distance_m': s['distanceM'] ?? 0,
        'rir': s['rir'] ?? 0,
        if (s.containsKey('planned') || planned)
          'planned': planned || s['planned'] == true ? 1 : 0,
      };

  static Future<String> _exerciseName(DatabaseExecutor db, String id) async {
    final rows = await db.query('exercise_translations',
        where: 'exercise_id = ?',
        whereArgs: [id],
        orderBy: "language_code = 'ru' DESC",
        limit: 1);
    return rows.isEmpty ? 'Упражнение' : rows.first['name'] as String;
  }
}
