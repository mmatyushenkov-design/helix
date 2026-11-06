/// Веб-fallback: браузер не даёт приложению свободно писать в файловую систему.
class LocalBackupService {
  Future<String> createBackup(Map<String, dynamic> snapshot) async =>
      throw UnsupportedError('ZIP-backup доступен в нативной версии');
  Future<Map<String, dynamic>> restoreBackup(String path) async =>
      throw UnsupportedError('Импорт ZIP доступен в нативной версии');
  Future<String> exportCsv(Map<String, dynamic> snapshot) async =>
      throw UnsupportedError('CSV-экспорт доступен в нативной версии');
}
