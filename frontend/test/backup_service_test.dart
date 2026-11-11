import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:workout_tracker_frontend/models/models.dart';
import 'package:workout_tracker_frontend/state/app_state.dart';
import 'package:workout_tracker_frontend/storage/backup_service_io.dart';
import 'package:workout_tracker_frontend/storage/file_storage_io.dart';

void main() {
  test('ZIP backup/restore: snapshot, контрольная сумма и локальные media',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('workout-tracker-backup-');
    addTearDown(() => directory.delete(recursive: true));
    final storage = LocalFileStorage(rootDirectory: directory);
    final service = LocalBackupService(storage: storage);
    await storage.writeBytes(
        'media/exercise/demo.txt', utf8.encode('local-media'));
    final state = AppState()..seed();
    state.language = 'en';
    state.weightUnit = WeightUnit.lb;

    final path = await service.createBackup(state.toJson());
    expect(await File(path).exists(), isTrue);
    expect(await service.backups(), hasLength(1));

    final restored = await service.restoreBackup(path);
    expect(restored['language'], 'en');
    expect(restored['weightUnit'], 'lb');
    expect(restored['cycles'], hasLength(state.cycles.length));
    expect(utf8.decode(await storage.readBytes('media/exercise/demo.txt')),
        'local-media');
  });

  test('Экспорт для отправки использует имя файла, совместимое с Windows',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('workout-tracker-export-');
    addTearDown(() => directory.delete(recursive: true));
    final storage = LocalFileStorage(rootDirectory: directory);
    final service = LocalBackupService(storage: storage);

    final state = AppState()..seed();
    final path = await service.createExportZip(state.toJson());

    expect(
      p.basename(path).toLowerCase(),
      matches(r'^workout-save-\d{4}\.\d{2}\.\d{2}-\d{2}-\d{2}-\d{2}\.zip$'),
    );
    expect(p.basename(path), isNot(contains(':')));
  });
}
