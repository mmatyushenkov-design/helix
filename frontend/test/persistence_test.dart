import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker_frontend/state/app_state.dart';
import 'package:workout_tracker_frontend/storage/local_store_io.dart';

void main() {
  test('Снапшот состояния: сериализация и восстановление без потерь', () {
    final before = appState;
    final c = before.cycles.first;
    c.tm += c.step; // имитируем изменение
    before.exercises.first.favorite = true;
    final moved = before.exercises.first;
    final target = before.exercises[2];
    before.moveExercise(moved, target, true);
    before.goToTab(1);

    final restored = AppState()..seed();
    restored.loadJson(
        jsonDecode(jsonEncode(before.toJson())) as Map<String, dynamic>);

    expect(restored.cycles.length, before.cycles.length);
    expect(restored.cycles.first.tm, c.tm);
    expect(restored.cycles.first.days.length, c.days.length);
    expect(restored.log.length, before.log.length);
    expect(restored.accent.toARGB32(), before.accent.toARGB32());
    expect(restored.exercises[2].favorite, isTrue);
    expect(restored.exercises.map((e) => e.id).toList(),
        before.exercises.map((e) => e.id).toList());
    // id продолжаются без коллизий
    final nc = restored.addCycle('Жим стоя');
    expect(restored.cycles.any((x) => x.id == nc.id && !identical(x, nc)),
        isFalse);
  });

  test('SQLite: запись и чтение снапшота', () async {
    final store = LocalStore();
    await store.write(jsonEncode(appState.toJson()));
    final raw = await store.read();
    expect(raw, isNotNull);
    final j = jsonDecode(raw!) as Map<String, dynamic>;
    expect((j['cycles'] as List).length, appState.cycles.length);
  });
}
