/// Бюджеты производительности приложения (ТЗ, раздел 12).
abstract final class AppPerformanceBudget {
  const AppPerformanceBudget._();

  /// Холодный запуск до первого кадра — не более 1,5 секунды.
  static const Duration startup = Duration(milliseconds: 1500);

  /// Максимальный размер приложения — 60 МБ.
  static const int maxAppSizeBytes = 60 * 1024 * 1024;
}

/// Замер холодного запуска от старта `main()` до первого отрисованного кадра.
///
/// Замер — прокси реального времени запуска: включает инициализацию
/// биндингов, открытие зашифрованной БД и первый кадр UI. Значение
/// используется в debug-логе и в тестах бюджета запуска.
abstract final class StartupMetrics {
  static final Stopwatch _stopwatch = Stopwatch();
  static Duration? _firstFrame;

  /// Начинает отсчёт. Повторные вызовы без [reset] игнорируются.
  static void start() {
    if (_stopwatch.isRunning || _firstFrame != null) return;
    _stopwatch.start();
  }

  /// Фиксирует первый кадр (вызывается из post-frame callback).
  static void markFirstFrame() {
    if (_firstFrame != null) return;
    _firstFrame = _stopwatch.elapsed;
    _stopwatch.stop();
  }

  /// Время до первого кадра или `null`, если кадр ещё не отрисован.
  static Duration? get firstFrame => _firstFrame;

  /// Уложился ли запуск в бюджет [AppPerformanceBudget.startup].
  static bool get withinBudget {
    final value = _firstFrame;
    return value == null || isWithinBudget(value);
  }

  /// Проверяет, укладывается ли замер [elapsed] в бюджет запуска.
  static bool isWithinBudget(Duration elapsed) =>
      elapsed <= AppPerformanceBudget.startup;

  /// Сбрасывает замер (для тестов и повторных запусков).
  static void reset() {
    _stopwatch
      ..stop()
      ..reset();
    _firstFrame = null;
  }
}
