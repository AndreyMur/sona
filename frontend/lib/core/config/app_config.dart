/// Конфигурация приложения.
abstract final class AppConfig {
  const AppConfig._();

  /// Базовый URL прокси Sona (можно переопределить через `--dart-define`).
  static const String apiBaseUrl = String.fromEnvironment(
    'SONA_API_BASE_URL',
    defaultValue: 'https://aidailyplanner.ru',
  );

  /// Таймаут соединения с прокси.
  static const Duration connectTimeout = Duration(seconds: 10);

  /// Таймаут ответа (STT/NLU могут занимать несколько секунд).
  static const Duration receiveTimeout = Duration(seconds: 30);
}
