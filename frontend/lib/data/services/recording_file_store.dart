import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/services/recording_file_store.dart';

/// Хранит временные файлы записей в каталоге приложения.
class TemporaryRecordingFileStore implements RecordingFileStore {
  @override
  Future<String> createRecordingPath() async {
    final directory = await getTemporaryDirectory();
    final name = 'sona_${DateTime.now().millisecondsSinceEpoch}.m4a';
    return p.join(directory.path, name);
  }

  @override
  Future<void> deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
