import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/app/budget_alert_coordinator.dart';
import 'package:sona/app/providers.dart';
import 'package:sona/core/utils/budget_alerts.dart';
import 'package:sona/data/local/app_database.dart';
import 'package:sona/domain/models/app_settings.dart';
import 'package:sona/domain/models/category.dart';
import 'package:sona/domain/models/operation.dart';

import '../support/fakes.dart';

void main() {
  late AppDatabase db;
  late FakeSonaNotifications notifications;
  late FakeAppSettingsStore store;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.seedCategories(kDefaultCategories);
    notifications = FakeSonaNotifications();
    store = FakeAppSettingsStore();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appSettingsStoreProvider.overrideWithValue(store),
        notificationsPortProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> evaluate(DateTime? now) async {
    await container.read(budgetAlertCoordinatorProvider.notifier).evaluate(now);
  }

  /// Траты с датами относительно фиксированной даты [base]:
  /// смещение 0 — «сегодня» для оценки.
  Future<void> addExpenses(
    List<(int dayOffset, double amount)> items, {
    required DateTime base,
    String category = 'Другое',
    String? subcategory,
  }) async {
    await db.insertParsedOperations(
      [
        for (final (offset, amount) in items)
          ParsedOperation(
            type: OperationType.expense,
            amount: amount,
            category: category,
            subcategory: subcategory,
            date: DateTime(base.year, base.month, base.day + offset, 12),
          ),
      ],
      source: OperationSource.manual,
    );
  }
  test('ежедневное напоминание планируется один раз в 20:00', () async {
    await evaluate(null);
    await evaluate(null);

    expect(notifications.scheduledDaily.length, 1);
    expect(notifications.scheduledDaily.single.hour, 20);
    expect(notifications.scheduledDaily.single.minute, 0);
  });

  test('порог 50% срабатывает и не дублируется', () async {
    store.settings = const AppSettings(monthlyBudget: 30000);
    final base = DateTime(2026, 9, 20);
    await addExpenses([(-5, 16000)], base: base);

    await evaluate(base);

    final titles = notifications.shown.map((n) => n.title).toSet();
    expect(titles, contains('Использовано 50% бюджета'));
    expect(titles, isNot(contains('Использовано 80% бюджета')));
    expect(titles, isNot(contains(BudgetAlerts.overBudgetTitle)));

    notifications.shown.clear();
    await evaluate(base);

    expect(notifications.shown, isEmpty);
  });

  test('пороги 80% и 100% плюс превышение бюджета', () async {
    store.settings = const AppSettings(monthlyBudget: 30000);
    final base = DateTime(2026, 9, 20);
    await addExpenses([(-5, 31000)], base: base);

    await evaluate(base);

    final titles = notifications.shown.map((n) => n.title).toSet();
    expect(titles, contains('Использовано 50% бюджета'));
    expect(titles, contains('Использовано 80% бюджета'));
    expect(titles, contains('Использовано 100% бюджета'));
    expect(titles, contains(BudgetAlerts.overBudgetTitle));
  });

  test('пороги учитывают перенос остатка', () async {
    store.settings = const AppSettings(
      monthlyBudget: 30000,
      carryOverEnabled: true,
      carryOverAmount: 20000,
    );
    final base = DateTime(2026, 9, 20);
    await addExpenses([(-5, 45000)], base: base);

    await evaluate(base);

    final titles = notifications.shown.map((n) => n.title).toSet();
    // Эффективный бюджет 50 000: потрачено ровно 90% — нет ни 100%, ни превышения.
    expect(titles, contains('Использовано 80% бюджета'));
    expect(titles, isNot(contains('Использовано 100% бюджета')));
    expect(titles, isNot(contains(BudgetAlerts.overBudgetTitle)));
  });

  test('пороги лимитов категорий и подкатегорий срабатывают', () async {
    store.settings = const AppSettings(
      categoryLimits: {'Продукты': 10000, 'Продукты::Супермаркет': 3000},
    );
    final base = DateTime(2026, 9, 20);
    await addExpenses(
      [(-5, 8000)],
      base: base,
      category: 'Продукты',
      subcategory: 'Супермаркет',
    );

    await evaluate(base);

    final titles = notifications.shown.map((n) => n.title).toSet();
    expect(titles, contains('«Продукты»: использовано 50% лимита'));
    expect(titles, contains('«Продукты»: использовано 80% лимита'));
    expect(
      titles,
      contains('«Продукты::Супермаркет»: использовано 80% лимита'),
    );
    expect(
      titles,
      contains('«Продукты::Супермаркет»: использовано 100% лимита'),
    );
    expect(
      titles,
      contains(BudgetAlerts.categoryOverTitle('Продукты::Супермаркет')),
    );

    final body = notifications.shown
        .firstWhere(
          (n) => n.title == '«Продукты::Супермаркет»: использовано 50% лимита',
        )
        .body;
    expect(body, 'Потрачено 8 000 ₽ из 3 000 ₽.');
  });

  test('аномалия трат срабатывает независимо от бюджета', () async {
    store.settings = const AppSettings(monthlyBudget: null);
    final base = DateTime(2026, 9, 15);
    await addExpenses([
      (0, 3000),
      (-3, 100),
      (-2, 100),
      (-1, 100),
    ], base: base);

    await evaluate(base);

    final titles = notifications.shown.map((n) => n.title).toSet();
    expect(titles, contains(BudgetAlerts.anomalyTitle));

    notifications.shown.clear();
    await evaluate(base);
    expect(
      notifications.shown.map((n) => n.title),
      isNot(contains(BudgetAlerts.anomalyTitle)),
    );
  });

  test('обычный день не вызывает аномалию', () async {
    store.settings = const AppSettings(monthlyBudget: null);
    final base = DateTime(2026, 9, 15);
    await addExpenses([
      (0, 10),
      (-3, 100),
      (-2, 100),
      (-1, 100),
    ], base: base);

    await evaluate(base);

    expect(
      notifications.shown.map((n) => n.title),
      isNot(contains(BudgetAlerts.anomalyTitle)),
    );
  });

  test('без бюджета и лимитов — только напоминание', () async {
    store.settings = const AppSettings(monthlyBudget: null);
    await addExpenses([(0, 3000)], base: DateTime(2026, 9, 20));

    await evaluate(DateTime(2026, 9, 20));

    expect(notifications.shown, isEmpty);
    expect(notifications.scheduledDaily.length, 1);
  });

  test('еженедельный отчёт приходит в первый открытый понедельник', () async {
    final monday = DateTime(2026, 9, 28);
    await db.insertParsedOperations([
      ParsedOperation(
        type: OperationType.income,
        amount: 12000,
        category: 'Доход',
        date: DateTime(2026, 9, 26, 12),
      ),
      ParsedOperation(
        type: OperationType.expense,
        amount: 4300,
        category: 'Продукты',
        date: DateTime(2026, 9, 27, 12),
      ),
    ], source: OperationSource.manual);

    await evaluate(monday.add(const Duration(hours: 20)));

    final titles = notifications.shown.map((n) => n.title).toSet();
    expect(titles, contains('Отчёт за неделю'));
    final body = notifications.shown
        .firstWhere((n) => n.title == 'Отчёт за неделю')
        .body;
    expect(body, 'Доходы: 12 000 ₽ · Расходы: 4 300 ₽.');

    notifications.shown.clear();
    await evaluate(monday.add(const Duration(hours: 20)));
    expect(
      notifications.shown.map((n) => n.title),
      isNot(contains('Отчёт за неделю')),
    );
  });

  test('маркеры уведомлений фиксируются в настройках', () async {
    store.settings = const AppSettings(monthlyBudget: 30000);
    final base = DateTime(2026, 9, 20);
    await addExpenses([(-5, 16000)], base: base);

    await evaluate(base);

    expect(
      store.settings.alertMarkers.any((m) => m.startsWith('thr:2026-09:')),
      isTrue,
    );
  });
}
