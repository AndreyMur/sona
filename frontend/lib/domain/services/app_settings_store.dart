import '../models/app_settings.dart';

/// Хранилище пользовательских настроек.
abstract interface class AppSettingsStore {
  /// Загружает сохранённые настройки (или значения по умолчанию).
  Future<AppSettings> load();

  /// Полностью перезаписывает настройки.
  Future<void> save(AppSettings settings);
}
