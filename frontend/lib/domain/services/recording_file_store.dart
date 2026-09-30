/// Порт файлового хранилища для аудиозаписей.
abstract interface class RecordingFileStore {
  /// Создаёт путь для нового файла записи (`.m4a`).
  Future<String> createRecordingPath();

  /// Удаляет файл, если он существует.
  Future<void> deleteIfExists(String path);
}
