import 'dart:async';
import 'dart:convert';

import '../state/app_state.dart';
import '../storage/local_store.dart';

/// Загружает локальный снапшот и подписывается на автосохранение.
/// На нативных платформах LocalStore внутри использует нормализованную SQLite;
/// JSON остаётся только форматом обмена с текущим AppState и резервной копией.
Future<void> initPersistence() async {
  final store = LocalStore();
  final raw = await store.read();
  var loaded = false;
  if (raw != null) {
    try {
      appState.loadJson(jsonDecode(raw) as Map<String, dynamic>);
      loaded = true;
    } catch (_) {
      // Битый снапшот — остаёмся на сидах и сохраняем их как новую копию.
    }
  }
  if (!loaded) await store.write(jsonEncode(appState.toJson()));

  Timer? debounce;
  Future<void> writes = Future<void>.value();
  appState.addListener(() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), () {
      final snapshot = jsonEncode(appState.toJson());
      // Сохранения выполняются по очереди, чтобы медленная SQLite-запись не
      // перезаписала более новое состояние старым снапшотом.
      writes = writes.then((_) => store.write(snapshot)).onError((_, __) {});
    });
  });
}
