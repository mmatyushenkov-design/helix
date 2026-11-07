import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Локальные файлы приложения без зависимости от сервера.
/// Все пути в API относительные: абсолютный путь зависит от платформы.
class LocalFileStorage {
  LocalFileStorage({Directory? rootDirectory}) : _rootDirectory = rootDirectory;

  final Directory? _rootDirectory;

  Future<Directory> root() async {
    final base = _rootDirectory ??
        Directory(p.join(
            (await getApplicationSupportDirectory()).path, 'WorkoutTracker'));
    await base.create(recursive: true);
    return base;
  }

  Future<File> _resolve(String relativePath) async {
    if (relativePath.trim().isEmpty || p.isAbsolute(relativePath)) {
      throw ArgumentError.value(
          relativePath, 'relativePath', 'Ожидается относительный путь');
    }
    final rootDir = await root();
    final normalized = p.normalize(relativePath);
    final rootPath = p.canonicalize(rootDir.path);
    final filePath = p.canonicalize(p.join(rootDir.path, normalized));
    if (filePath == rootPath || !p.isWithin(rootPath, filePath)) {
      throw ArgumentError.value(
          relativePath, 'relativePath', 'Путь выходит за папку приложения');
    }
    return File(filePath);
  }

  Future<File> writeBytes(String relativePath, List<int> bytes) async {
    final file = await _resolve(relativePath);
    await file.parent.create(recursive: true);
    final temporary =
        File('${file.path}.tmp-${DateTime.now().microsecondsSinceEpoch}');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      // rename атомарен в пределах одной файловой системы. На Windows сначала
      // убираем старую цель, потому что rename там не заменяет существующий файл.
      if (Platform.isWindows && await file.exists()) await file.delete();
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
    return file;
  }

  Future<Uint8List> readBytes(String relativePath) async {
    final file = await _resolve(relativePath);
    return file.readAsBytes();
  }

  Future<bool> exists(String relativePath) async =>
      (await _resolve(relativePath)).exists();

  Future<void> delete(String relativePath) async {
    final file = await _resolve(relativePath);
    if (await file.exists()) await file.delete();
  }
}
