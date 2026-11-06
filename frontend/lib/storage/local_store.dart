/// Условный экспорт: на вебе — localStorage, на нативных платформах — SQLite.
library;

export 'local_store_web.dart' if (dart.library.ffi) 'local_store_io.dart';
