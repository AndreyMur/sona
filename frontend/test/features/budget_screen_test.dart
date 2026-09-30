import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sona/app/providers.dart';
import 'package:sona/core/router/app_router.dart';
import 'package:sona/core/theme/app_theme.dart';
import 'package:sona/data/local/app_database.dart';
import 'package:sona/domain/models/app_settings.dart';
import 'package:sona/domain/models/category.dart';
import 'package:sona/domain/models/operation.dart';

import '../support/fakes.dart';

void main() {
  late AppDatabase db;
  late GoRouter router;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.seedCategories(kDefaultCategories);
    router = buildRouter(
      onboardingCompleted: () => true,
      refreshListenable: ValueNotifier<bool?>(true),
    );
    addTearDown(router.dispose);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> unmountTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<FakeAppSettingsStore> pumpScreen(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
    bool goToBudget = true,
  }) async {
    final store = FakeAppSettingsStore(settings);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          appSettingsStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));
    if (goToBudget) {
      router.go('/budget');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
    return store;
  }

  testWidgets('карточка бюджета показывает сумму и остаток', (tester) async {
    await db.insertParsedOperations(
      [
        ParsedOperation(
          type: OperationType.expense,
          amount: 25000,
          category: 'Продукты',
          date: DateTime.now(),
        ),
      ],
      source: OperationSource.manual,
    );

    await pumpScreen(tester, settings: const AppSettings(monthlyBudget: 30000));

    expect(find.text('Бюджет месяца'), findsOneWidget);
    expect(find.text('30 000 ₽'), findsOneWidget);
    expect(find.text('Потрачено 25 000 ₽'), findsOneWidget);
    expect(find.text('83%'), findsOneWidget);
    expect(find.textContaining('Осталось 5 000 ₽'), findsOneWidget);
    expect(find.textContaining('Прогноз к концу месяца'), findsOneWidget);

    await unmountTree(tester);
  });

  testWidgets('перенесённый остаток увеличивает бюджет', (tester) async {
    final now = DateTime.now();
    await db.insertParsedOperations(
      [
        ParsedOperation(
          type: OperationType.expense,
          amount: 2000,
          category: 'Продукты',
          date: DateTime(now.year, now.month - 1, 15),
        ),
      ],
      source: OperationSource.manual,
    );

    await pumpScreen(
      tester,
      settings: const AppSettings(monthlyBudget: 30000, carryOverEnabled: true),
    );

    expect(find.textContaining('Перенесено с прошлого месяца: 28 000 ₽'), findsOneWidget);
    expect(find.text('58 000 ₽'), findsOneWidget);

    await unmountTree(tester);
  });

  testWidgets('пончик-диаграмма и легенда по категориям', (tester) async {
    await db.insertParsedOperations(
      [
        ParsedOperation(
          type: OperationType.expense,
          amount: 3000,
          category: 'Продукты',
          subcategory: 'Супермаркет',
          date: DateTime.now(),
        ),
        ParsedOperation(
          type: OperationType.expense,
          amount: 1000,
          category: 'Транспорт',
          date: DateTime.now(),
        ),
      ],
      source: OperationSource.manual,
    );

    await pumpScreen(tester);

    expect(find.text('Расходы по категориям'), findsOneWidget);
    expect(find.text('Продукты'), findsWidgets);
    expect(find.text('Транспорт'), findsWidgets);
    expect(find.textContaining('75%'), findsOneWidget);
    expect(find.textContaining('25%'), findsOneWidget);

    await unmountTree(tester);
  });

  testWidgets('без расходов у диаграммы пустое состояние', (tester) async {
    await pumpScreen(tester);

    expect(find.text('В этом месяце пока нет расходов'), findsOneWidget);
    expect(find.textContaining('· лимит не задан'), findsWidgets);

    await unmountTree(tester);
  });

  testWidgets('тап по категории открывает диалог лимита и сохраняет его', (tester) async {
    final store = await pumpScreen(tester);

    await tester.tap(find.text('Продукты').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Лимит «Продукты»'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '10000');
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(store.settings.categoryLimits['Продукты'], 10000);
    expect(find.textContaining('из 10 000 ₽'), findsOneWidget);

    await unmountTree(tester);
  });

  testWidgets('диалог бюджета сохраняет сумму, пороги и перенос', (tester) async {
    final store = await pumpScreen(
      tester,
      settings: const AppSettings(monthlyBudget: 30000),
    );

    await tester.tap(find.byTooltip('Изменить бюджет'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Предупреждать при:'), findsOneWidget);
    expect(find.text('Переносить остаток'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '20000');
    await tester.tap(find.text('80%'));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(store.settings.monthlyBudget, 20000);
    expect(store.settings.alertThresholds, [50, 100]);
    expect(store.settings.carryOverEnabled, isTrue);

    await unmountTree(tester);
  });

  testWidgets('снятый лимит исчезает из карточки', (tester) async {
    final store = await pumpScreen(
      tester,
      settings: const AppSettings(
        monthlyBudget: 30000,
        categoryLimits: {'Продукты': 10000},
      ),
    );

    expect(find.textContaining('из 10 000 ₽'), findsOneWidget);

    await tester.tap(find.text('Продукты').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Снять лимит'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(store.settings.categoryLimits['Продукты'], isNull);
    expect(find.textContaining('· лимит не задан'), findsWidgets);

    await unmountTree(tester);
  });

  testWidgets('быстрое действие «Бюджет» открывает экран бюджета', (tester) async {
    await pumpScreen(tester, goToBudget: false);

    await tester.ensureVisible(find.text('Бюджет'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Бюджет'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Лимиты по категориям'), findsOneWidget);

    await unmountTree(tester);
  });
}
