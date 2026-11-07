import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'file_storage_io.dart';

/// Локальные ZIP-backup и CSV. Облако не используется.
class LocalBackupService {
  LocalBackupService({LocalFileStorage? storage})
      : storage = storage ?? LocalFileStorage();
  final LocalFileStorage storage;

  Future<String> createBackup(Map<String, dynamic> snapshot) async {
    final data = utf8.encode(jsonEncode(snapshot));
    final manifest = utf8.encode(jsonEncode({
      'backup_version': 1,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'sha256': sha256.convert(data).toString(),
    }));
    final archive = Archive()
      ..addFile(ArchiveFile('manifest.json', manifest.length, manifest))
      ..addFile(ArchiveFile('data.json', data.length, data));

    final rootDir = await storage.root();
    final media = Directory(p.join(rootDir.path, 'media'));
    if (await media.exists()) {
      for (final entity in media.listSync(recursive: true)) {
        if (entity is! File) continue;
        final bytes = await entity.readAsBytes();
        final relative =
            p.relative(entity.path, from: rootDir.path).replaceAll('\\', '/');
        archive.addFile(ArchiveFile(relative, bytes.length, bytes));
      }
    }
    final zip = ZipEncoder().encode(archive);
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final file =
        await storage.writeBytes('backups/workout-backup-$stamp.zip', zip);
    return file.path;
  }

  Future<Map<String, dynamic>> restoreBackup(String path) async {
    final bytes = await File(path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final manifestFile = archive.findFile('manifest.json');
    final dataFile = archive.findFile('data.json');
    if (manifestFile == null || dataFile == null) {
      throw const FormatException('В ZIP нет manifest.json или data.json');
    }
    final manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>))
        as Map<String, dynamic>;
    if (manifest['backup_version'] != 1) {
      throw const FormatException('Неподдерживаемая версия backup');
    }
    final dataBytes = dataFile.content as List<int>;
    if (sha256.convert(dataBytes).toString() != manifest['sha256']) {
      throw const FormatException('Контрольная сумма backup не совпадает');
    }
    final snapshot = jsonDecode(utf8.decode(dataBytes)) as Map<String, dynamic>;
    for (final file in archive.files) {
      if (!file.isFile || !file.name.startsWith('media/')) continue;
      await storage.writeBytes(file.name, file.content as List<int>);
    }
    return snapshot;
  }

  Future<List<File>> backups() async {
    final rootDir = await storage.root();
    final directory = Directory(p.join(rootDir.path, 'backups'));
    if (!await directory.exists()) return [];
    final files = [
      for (final entity in directory.listSync())
        if (entity is File && entity.path.endsWith('.zip')) entity
    ]..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<String> exportCsv(Map<String, dynamic> snapshot) async {
    String escape(Object? value) =>
        '"${(value ?? '').toString().replaceAll('"', '""')}"';
    final rows = <String>[
      'date,exercise,format,weight_kg,reps,duration_sec,distance_m,rir,planned',
    ];
    final log = snapshot['log'] as Map<String, dynamic>? ?? {};
    for (final date in log.keys.toList()..sort()) {
      for (final entry in log[date] as List) {
        for (final set in entry['sets'] as List) {
          rows.add([
            date,
            escape(entry['name']),
            entry['recordFormat'] ?? 'WEIGHT_REPS',
            set['w'] ?? 0,
            set['reps'] ?? 0,
            set['durationSec'] ?? 0,
            set['distanceM'] ?? 0,
            set['rir'] ?? 0,
            set['planned'] == true,
          ].join(','));
        }
      }
    }
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final file = await storage.writeBytes(
        'exports/workout-export-$stamp.csv', utf8.encode(rows.join('\n')));
    return file.path;
  }
}
