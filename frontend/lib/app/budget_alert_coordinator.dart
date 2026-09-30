import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import '../core/utils/budget_alerts.dart';
import '../core/utils/budget_math.dart';
import '../domain/models/app_settings.dart';
import '../domain/models/operation.dart';
import '../domain/services/notification_service.dart';

/// Координатор бюджетных уведомлений: пороги, превышение, аномалии,
/// еженедельный отчёт и планирование ежедневного напоминания.
///
/// `evaluate()` вызывается наблюдателями при старте и при изменениях
/// настроек/операций — сами уведомления идемпотентны благодаря маркерам.
final budgetAlertCoordinatorProvider =
    NotifierProvider<BudgetAlertCoordinator, void>(
      BudgetAlertCoordinator.new,
    );

/// Оценивает события бюджета и отправляет уведомления.
class BudgetAlertCoordinator extends Notifier<void> {
  bool _running = false;

  @override
  void build() {}

  Future<void> evaluate([DateTime? now]) async {
    if (_running) return;
    _running = true;
    try {
      final stamp = now ?? DateTime.now();
      final settings =
          ref.read(appSettingsProvider).value ?? const AppSettings();
      final port = ref.read(notificationsPortProvider);
      final currency = ref.read(currencyProvider).symbol;

      final newMarkers = <String>{};

      await _ensureReminders(port, settings, newMarkers);
      await _weeklyReport(port, settings, newMarkers, stamp, currency);
      if (settings.monthlyBudget != null && settings.monthlyBudget! > 0) {
        await _budgetAlerts(port, settings, newMarkers, stamp, currency);
        await _categoryAlerts(port, settings, newMarkers, stamp, currency);
        await _anomalyAlert(port, settings, newMarkers, stamp, currency);
      }

      if (newMarkers.isNotEmpty) {
        await ref.read(appSettingsProvider.notifier).addAlertMarkers(newMarkers);
      }
    } catch (error) {
      // Уведомления не должны ломать приложение (нет платформенных каналов
      // в тестах и на десктопе без поддержки).
      debugPrint('BudgetAlertCoordinator.evaluate: $error');
    } finally {
      _running = false;
    }
  }

  /// Планирует ежедневное напоминание один раз.
  Future<void> _ensureReminders(
    SonaNotifications port,
    AppSettings settings,
    Set<String> markers,
  ) async {
    if (settings.alertMarkers.contains(BudgetAlerts.markerRemindersScheduled)) {
      return;
    }
    await port.scheduleDailyReminder(hour: 20, minute: 0);
    markers.add(BudgetAlerts.markerRemindersScheduled);
  }

  /// Еженедельный отчёт: динамическая сводка в первый открытый понедельник.
  Future<void> _weeklyReport(
    SonaNotifications port,
    AppSettings settings,
    Set<String> markers,
    DateTime stamp,
    String currency,
  ) async {
    final dayKey = _dayKey(stamp);
    final marker = BudgetAlerts.markerWeekly(dayKey);
    if (stamp.weekday != DateTime.monday ||
        settings.alertMarkers.contains(marker)) {
      return;
    }
    final repository = ref.read(operationRepositoryProvider);
    final from = DateTime(stamp.year, stamp.month, stamp.day - 6);
    final to = DateTime(stamp.year, stamp.month, stamp.day + 1);
    final income = await repository.totalByType(
      OperationType.income,
      from: from,
      to: to,
    );
    final expense = await repository.totalByType(
      OperationType.expense,
      from: from,
      to: to,
    );
    if (income > 0 || expense > 0) {
      await port.show(
        id: BudgetAlerts.idWeeklyReport,
        title: BudgetAlerts.weeklyReportTitle,
        body: BudgetAlerts.weeklyReportBody(income, expense, currency),
      );
    }
    markers.add(marker);
  }

  /// Пороги 50/80/100% и превышение общего бюджета.
  Future<void> _budgetAlerts(
    SonaNotifications port,
    AppSettings settings,
    Set<String> markers,
    DateTime stamp,
    String currency,
  ) async {
    final cycle = ref.read(budgetCycleProvider).value;
    final total = BudgetMath.effectiveBudget(
      settings.monthlyBudget!,
      carryOverEnabled: cycle?.carryOverEnabled ?? settings.carryOverEnabled,
      carryOverAmount: cycle?.carryOver ?? settings.carryOverAmount,
    );
    if (total <= 0) return;

    final repository = ref.read(operationRepositoryProvider);
    final (from, to) = currentMonthRange(stamp);
    final spent = await repository.totalByType(
      OperationType.expense,
      from: from,
      to: to,
    );
    final month = BudgetMath.monthKey(stamp);

    final notified = BudgetAlerts.notifiedThresholds(settings.alertMarkers, month);
    for (final percent
        in BudgetMath.unseenThresholds(
          BudgetMath.reachedThresholds(spent, total, settings.alertThresholds),
          notified,
        )) {
      await port.show(
        id: BudgetAlerts.idThreshold(percent),
        title: BudgetAlerts.thresholdTitle(percent),
        body: BudgetAlerts.thresholdBody(spent, total, currency),
      );
      markers.add(BudgetAlerts.markerThreshold(month, percent));
    }

    if (spent > total &&
        !settings.alertMarkers.contains(BudgetAlerts.markerOver(month))) {
      await port.show(
        id: BudgetAlerts.idOverBudget,
        title: BudgetAlerts.overBudgetTitle,
        body: BudgetAlerts.overBudgetBody(spent, total, currency),
      );
      markers.add(BudgetAlerts.markerOver(month));
    }
  }

  /// Пороги и превышение лимитов по категориям/подкатегориям.
  Future<void> _categoryAlerts(
    SonaNotifications port,
    AppSettings settings,
    Set<String> markers,
    DateTime stamp,
    String currency,
  ) async {
    final limits = settings.categoryLimits;
    if (limits.isEmpty) return;
    final repository = ref.read(operationRepositoryProvider);
    final (from, to) = currentMonthRange(stamp);
    final byCategory = await repository.expensesByCategory(from: from, to: to);
    final bySubcategory = await repository.expensesBySubcategory(
      from: from,
      to: to,
    );
    final month = BudgetMath.monthKey(stamp);

    for (final entry in limits.entries) {
      final key = entry.key;
      final limit = entry.value;
      if (limit <= 0) continue;
      final isPair = key.contains(kCategoryLimitSeparator);
      final spent = isPair ? (bySubcategory[key] ?? 0) : (byCategory[key] ?? 0);
      if (spent <= 0) continue;

      final reached = BudgetMath.reachedThresholds(spent, limit, settings.alertThresholds);
      final notified = BudgetAlerts.categoryNotifiedThresholds(
        settings.alertMarkers,
        month,
        key,
      );
      for (final percent in BudgetMath.unseenThresholds(reached, notified)) {
        await port.show(
          id: BudgetAlerts.idForCategory(key),
          title: BudgetAlerts.categoryThresholdTitle(key, percent),
          body: BudgetAlerts.categoryThresholdBody(spent, limit, currency),
        );
        markers.add(
          BudgetAlerts.markerCategoryThreshold(month, key, percent),
        );
      }

      if (spent > limit &&
          !settings.alertMarkers.contains(
            BudgetAlerts.markerCategoryOver(month, key),
          )) {
        await port.show(
          id: BudgetAlerts.idForCategory(key),
          title: BudgetAlerts.categoryOverTitle(key),
          body: BudgetAlerts.categoryOverBody(spent, limit, currency),
        );
        markers.add(BudgetAlerts.markerCategoryOver(month, key));
      }
    }
  }

  /// Аномалия трат: сегодняшний день вдвое дороже среднего за месяц.
  Future<void> _anomalyAlert(
    SonaNotifications port,
    AppSettings settings,
    Set<String> markers,
    DateTime stamp,
    String currency,
  ) async {
    if (stamp.day <= 1) return; // нет базы для сравнения в первый день
    final dayKey = _dayKey(stamp);
    if (settings.alertMarkers.contains(BudgetAlerts.markerAnomaly(dayKey))) {
      return;
    }
    final repository = ref.read(operationRepositoryProvider);
    final (from, to) = currentMonthRange(stamp);
    final monthSpent = await repository.totalByType(
      OperationType.expense,
      from: from,
      to: to,
    );
    if (monthSpent <= 0) return;
    final dailyAverage = monthSpent / max(stamp.day - 1, 1);
    if (dailyAverage <= 0) return;

    final todayStart = DateTime(stamp.year, stamp.month, stamp.day);
    final todaySpent = await repository.totalByType(
      OperationType.expense,
      from: todayStart,
      to: DateTime(todayStart.year, todayStart.month, todayStart.day + 1),
    );
    if (todaySpent < dailyAverage * 2) return;

    await port.show(
      id: BudgetAlerts.idAnomaly,
      title: BudgetAlerts.anomalyTitle,
      body: BudgetAlerts.anomalyBody(todaySpent, dailyAverage, currency),
    );
    markers.add(BudgetAlerts.markerAnomaly(dayKey));
  }

  String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
