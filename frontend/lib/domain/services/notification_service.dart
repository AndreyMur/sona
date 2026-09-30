/// Порт доставки локальных уведомлений приложения.
abstract interface class SonaNotifications {
  /// Инициализирует плагин (идемпотентно).
  Future<void> initialize();

  /// Показывает уведомление.
  Future<void> show({required int id, required String title, required String body});

  /// Планирует повторяющееся ежедневное напоминание.
  Future<void> scheduleDailyReminder({required int hour, required int minute});

  /// Отменяет ежедневное напоминание.
  Future<void> cancelDailyReminder();
}
