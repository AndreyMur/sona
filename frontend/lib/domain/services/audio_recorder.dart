/// Порт записи аудио.
///
/// Реализация отвечает за разрешение на микрофон и запись файла `.m4a`
/// (16 кГц, mono).
abstract interface class AudioRecorderPort {
  /// Проверяет и при необходимости запрашивает доступ к микрофону.
  Future<bool> hasPermission();

  /// Начинает запись в файл [path].
  Future<void> start(String path);

  /// Останавливает запись и возвращает путь к файлу.
  Future<String?> stop();

  /// Прерывает запись и удаляет файл.
  Future<void> cancel();

  /// Освобождает ресурсы.
  Future<void> dispose();
}
