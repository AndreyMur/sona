/// Хранилище файлов экспорта данных пользователя.
abstract interface class DataExportStore {
  /// Сохраняет [content] под именем [fileName].
  ///
  /// Возвращает путь (или иной локатор) сохранённого файла для показа
  /// пользователю.
  Future<String> write(String fileName, String content);
}
