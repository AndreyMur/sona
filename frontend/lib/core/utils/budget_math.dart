import 'dart:math';

/// Тональность статуса бюджета для цветового оформления UI.
enum BudgetTone { ok, warn, danger }

/// Чистая математика бюджета: пороги, прогноз и перенос остатка.
///
/// Только чистые функции — детерминированно для тестов.
abstract final class BudgetMath {
  const BudgetMath._();

  /// Число дней в месяце.
  static int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  /// Неотрицательные уникальные пороги из допустимого диапазона, по возрастанию.
  static List<int> normalizeThresholds(Iterable<int> raw) {
    final cleaned =
        raw.where((t) => t > 0 && t <= 100).toSet().toList()..sort();
    return cleaned;
  }

  /// Доля бюджета, потраченная к настоящему моменту, в `[0..1]`.
  ///
  /// Превышение даёт `1` (визуальный предел полосы).
  static double budgetProgress(double spent, double budget) =>
      budget > 0 ? ((spent / budget).clamp(0.0, 1.0) as num).toDouble() : 0;

  /// Неклампленный процент выполнения бюджета (может превысить 100).
  static double budgetRatioPercent(double spent, double budget) =>
      budget > 0 ? spent / budget * 100 : 0;

  /// Пороги (в процентах), которых достигли текущие траты.
  static List<int> reachedThresholds(
    double spent,
    double budget,
    Iterable<int> thresholds,
  ) {
    if (budget <= 0 || spent <= 0) return const [];
    final percent = budgetRatioPercent(spent, budget);
    return normalizeThresholds(
      thresholds.where((threshold) => percent >= threshold),
    );
  }

  /// Пороги из [reached], по которым ещё не отправляли уведомление.
  static List<int> unseenThresholds(
    Iterable<int> reached,
    Iterable<int> notified,
  ) => reached.where((t) => !notified.contains(t)).toList();

  /// Тональность статуса: `danger` при превышении бюджета или достижении
  /// порога 100%, `warn` при достижении старшего меньшего порога, иначе `ok`.
  static BudgetTone budgetTone(
    double spent,
    double budget,
    Iterable<int> thresholds,
  ) {
    if (budget > 0 && spent >= budget) return BudgetTone.danger;
    final lower = thresholds.where((t) => t < 100).toList()..sort();
    for (final threshold in lower.reversed) {
      if (budget > 0 && spent / budget * 100 >= threshold) {
        return BudgetTone.warn;
      }
    }
    return BudgetTone.ok;
  }

  /// Прогноз расходов до конца месяца по средней скорости трат
  /// («потрачено сейчас × весь месяц ÷ прошло дней»).
  static double forecastSpending(double spent, DateTime now) {
    final total = daysInMonth(now.year, now.month);
    final elapsed = now.day.clamp(1, total);
    if (spent <= 0) return 0;
    return spent / elapsed * total;
  }

  /// Остаток бюджета (при перерасходе — отрицательный).
  static double budgetRemaining(double budget, double spent) =>
      budget - spent;

  /// Дневной запас на оставшиеся дни месяца (включая сегодняшний).
  /// При перерасходе — отрицательное значение.
  static double dailyAllowance(double remaining, DateTime now) {
    final total = daysInMonth(now.year, now.month);
    final daysLeft = max(1, total - now.day + 1);
    return remaining / daysLeft;
  }

  /// Переносимый остаток прошлого месяца: неиспользованная часть бюджета,
  /// не меньше нуля.
  ///
  /// Возвращает `null`, если перенос выключен или бюджет не задан.
  static double? carryOverRemainder({
    required double? monthlyBudget,
    required double spent,
    required bool enabled,
  }) {
    if (!enabled || monthlyBudget == null) return null;
    final rest = monthlyBudget - spent;
    return rest > 0 ? rest : 0;
  }

  /// Эффективный бюджет месяца с учётом переноса остатка.
  static double effectiveBudget(
    double monthlyBudget, {
    required bool carryOverEnabled,
    double? carryOverAmount,
  }) =>
      monthlyBudget + (carryOverEnabled ? (carryOverAmount ?? 0) : 0);

  /// Ключ месяца «ГГГГ-ММ» (для отметок обработанных месяцев).
  static String monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';
}
