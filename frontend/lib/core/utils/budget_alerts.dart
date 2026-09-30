import 'formatters.dart';

/// Тексты, идентификаторы и маркеры уведомлений о бюджете.
///
/// Чистые функции — удобно проверять в тестах.
abstract final class BudgetAlerts {
  const BudgetAlerts._();

  static const int _baseId = 10000;

  /// Идентификаторы классов уведомлений (уникальные интервалы).
  static int idThreshold(int percent) => _baseId + percent;
  static const int idOverBudget = _baseId + 101;
  static const int idAnomaly = _baseId + 102;
  static const int idWeeklyReport = _baseId + 103;
  static const int idDailyReminder = _baseId + 104;

  /// Стабильный id уведомления для ключа лимита «категория::подкатегория».
  static int idForCategory(String key) =>
      _baseId + 200 + key.hashCode.abs() % 3000;

  /// Маркер повторяющегося ежедневного напоминания уже запланирован.
  static const String markerRemindersScheduled =
      'cfg:dailyReminderScheduled';

  // --- Маркеры отправленных событий (idемпотентность алертов) ---

  static String markerThreshold(String month, int percent) =>
      'thr:$month:$percent';

  static String markerOver(String month) => 'over:$month';

  static String markerCategoryThreshold(String month, String key, int percent) =>
      'catthr:$month:$key:$percent';

  static String markerCategoryOver(String month, String key) =>
      'catover:$month:$key';

  static String markerAnomaly(String day) => 'anomaly:$day';

  static String markerWeekly(String monday) => 'weekly:$monday';

  /// Проценты порогов общего бюджета, уже уведомлённые за месяц.
  static List<int> notifiedThresholds(Iterable<String> markers, String month) =>
      _extractIntSuffixes(markers, 'thr:$month:');

  /// Проценты порогов лимита ключа, уже уведомлённые за месяц.
  static List<int> categoryNotifiedThresholds(
    Iterable<String> markers,
    String month,
    String key,
  ) => _extractIntSuffixes(markers, 'catthr:$month:$key:');

  static List<int> _extractIntSuffixes(
    Iterable<String> markers,
    String prefix,
  ) {
    return markers
        .where((marker) => marker.startsWith(prefix))
        .map((marker) => int.tryParse(marker.substring(prefix.length)))
        .whereType<int>()
        .toList()
      ..sort();
  }

  // --- Тексты уведомлений ---

  static String thresholdTitle(int percent) =>
      'Использовано $percent% бюджета';

  static String thresholdBody(double spent, double budget, String currency) =>
      'Потрачено ${SonaFormat.amount(spent, currency: currency)} из '
      '${SonaFormat.amount(budget, currency: currency)}.';

  static String overBudgetBody(double spent, double budget, String currency) =>
      'Расходы ${SonaFormat.amount(spent, currency: currency)} превысили '
      'бюджет ${SonaFormat.amount(budget, currency: currency)}.';

  static const String overBudgetTitle = 'Бюджет превышен';

  static const String anomalyTitle = 'Аномалия трат';

  static String anomalyBody(
    double todaySpent,
    double dailyAverage,
    String currency,
  ) =>
      'Сегодня ${SonaFormat.amount(todaySpent, currency: currency)} — примерно '
      'вдвое больше обычного (~${SonaFormat.amount(dailyAverage, currency: currency)} в день).';

  static const String dailyReminderTitle = 'Запишите траты за сегодня';

  static const String dailyReminderBody =
      'Пара минут в Sona — и бюджет останется под контролем.';

  static const String weeklyReportTitle = 'Отчёт за неделю';

  static String weeklyReportBody(double income, double expense, String currency) =>
      'Доходы: ${SonaFormat.amount(income, currency: currency)} · '
      'Расходы: ${SonaFormat.amount(expense, currency: currency)}.';

  static String categoryThresholdTitle(String key, int percent) =>
      '«$key»: использовано $percent% лимита';

  static String categoryThresholdBody(
    double spent,
    double limit,
    String currency,
  ) =>
      'Потрачено ${SonaFormat.amount(spent, currency: currency)} из '
      '${SonaFormat.amount(limit, currency: currency)}.';

  static String categoryOverTitle(String key) => 'Лимит «$key» превышен';

  static String categoryOverBody(double spent, double limit, String currency) =>
      'Расходы ${SonaFormat.amount(spent, currency: currency)} выше лимита '
      '${SonaFormat.amount(limit, currency: currency)}.';
}
