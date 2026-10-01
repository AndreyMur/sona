import '../../domain/services/data_export_store.dart';
import 'file_data_export_store_stub.dart'
    if (dart.library.io) 'file_data_export_store_io.dart' as platform;

/// Сохраняет резервную копию в файловой системе устройства.
///
/// На веб-платформе `dart:io` недоступен — используется заглушка
/// (см. `file_data_export_store_stub.dart`).
class FileDataExportStore implements DataExportStore {
  @override
  Future<String> write(String fileName, String content) =>
      platform.writeExportFile(fileName, content);
}
