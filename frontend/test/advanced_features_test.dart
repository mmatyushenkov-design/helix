import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workout_tracker_frontend/models/models.dart';
import 'package:workout_tracker_frontend/state/app_state.dart';
import 'package:workout_tracker_frontend/storage/local_database.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('Единицы: конвертация kg/lb и km/mi обратима', () {
    expect(displayToKg(kgToDisplay(100, WeightUnit.lb), WeightUnit.lb),
        closeTo(100, 1e-9));
    expect(kgToDisplay(100, WeightUnit.lb), closeTo(220.46226218, 1e-9));
    expect(
        displayToMeters(
            metersToDisplay(5000, DistanceUnit.mi), DistanceUnit.mi),
        closeTo(5000, 1e-9));
    expect(metersToDisplay(5000, DistanceUnit.km), 5);
  });

  test('Все четыре формата подхода сохраняются без потерь', () {
    final entries = [
      DiaryEntry(
          name: 'Жим',
          recordFormat: RecordFormat.weightReps,
          sets: [DiarySet(w: 100, reps: 5, rir: 2)]),
      DiaryEntry(
          name: 'Планка',
          recordFormat: RecordFormat.weightTime,
          sets: [DiarySet(w: 20, durationSec: 75)]),
      DiaryEntry(
          name: 'Вис',
          recordFormat: RecordFormat.timeReps,
          sets: [DiarySet(reps: 3, durationSec: 45)]),
      DiaryEntry(
          name: 'Бег',
          recordFormat: RecordFormat.timeDistance,
          sets: [DiarySet(durationSec: 1500, distanceM: 5000)]),
    ];
    final restored = [
      for (final entry in entries)
        DiaryEntry.fromJson(
            jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>),
    ];
    for (var i = 0; i < entries.length; i++) {
      expect(restored[i].recordFormat, entries[i].recordFormat);
      expect(restored[i].sets.single.toJson(), entries[i].sets.single.toJson());
      expect(restored[i].id, entries[i].id);
    }
  });

  test('UUID: новые сущности уникальны, старые числовые id стабильны', () {
    final uuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    final a = DiaryEntry(name: 'Тест', sets: const []);
    final b = DiaryEntry(name: 'Тест', sets: const []);
    expect(a.id, isNot(b.id));
    expect(uuid.hasMatch(a.id), isTrue);
    final legacy =
        DiaryEntry.fromJson({'id': 42, 'name': 'Тест', 'sets': const []});
    final sameLegacy =
        DiaryEntry.fromJson({'id': 42, 'name': 'Другое', 'sets': const []});
    expect(legacy.id, sameLegacy.id);
    expect(uuid.hasMatch(legacy.id), isTrue);
  });

  test(
      'Шаблон добавляет запланированные подходы всех форматов в выбранный день',
      () {
    final state = AppState()..seed();
    final date = DateTime(2020, 1, 1);
    final bench = state.exerciseByName('Жим лёжа')!;
    final run = state.exerciseByName('Бег')!;
    final template = WorkoutTemplate(name: 'Тестовая тренировка', items: [
      TemplateItem(
          exerciseId: bench.id, sets: [DiarySet(w: 80, reps: 5, rir: 2)]),
      TemplateItem(
          exerciseId: run.id,
          sets: [DiarySet(durationSec: 1200, distanceM: 3000)]),
    ]);
    state.applyTemplate(template, date);

    final entries = state.entriesOf(date);
    expect(entries, hasLength(2));
    expect(entries[0].recordFormat, RecordFormat.weightReps);
    expect(entries[0].sets.single.planned, isTrue);
    expect(entries[0].sets.single.w, 80);
    expect(entries[1].recordFormat, RecordFormat.timeDistance);
    expect(entries[1].sets.single.distanceM, 3000);
    expect(entries.every((e) => e.templateItemId != null), isTrue);
  });

  test('SQLite: UUID, форматы и шаблоны переживают roundtrip', () async {
    final db = LocalDatabase(
        factory: databaseFactoryFfi, databasePath: inMemoryDatabasePath);
    addTearDown(db.close);
    final state = AppState()..seed();
    final run = state.exerciseByName('Бег')!;
    final entry = state.addEntry(
      DateTime(2020, 1, 1),
      run.nameRu,
      exerciseId: run.id,
      presetSets: [DiarySet(durationSec: 900, distanceM: 2500)],
    );
    state.saveTemplate(WorkoutTemplate(name: 'Кардио', items: [
      TemplateItem(
          exerciseId: run.id,
          sets: [DiarySet(durationSec: 900, distanceM: 2500)]),
    ]));
    await db.writeSnapshot(state.toJson());

    final restored = AppState()..seed();
    restored.loadJson((await db.readSnapshot())!);
    expect(restored.cycles.map((c) => c.id), state.cycles.map((c) => c.id));
    expect(restored.templates.single.name, 'Кардио');
    expect(restored.templates.single.items.single.sets.single.distanceM, 2500);
    final restoredEntry = restored.log.values
        .expand((entries) => entries)
        .singleWhere((e) => e.id == entry.id);
    expect(restoredEntry.recordFormat, RecordFormat.timeDistance);
    expect(restoredEntry.sets.single.durationSec, 900);
    expect(restoredEntry.sets.single.distanceM, 2500);

    final raw = await db.open();
    expect(await raw.query('workout_templates'), hasLength(1));
    expect(await raw.query('workout_template_items'), hasLength(1));
  });
}
