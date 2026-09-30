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

  /// Размонтирует дерево внутри тела теста, чтобы drift успел закрыть
  /// подписки на потоки до проверки pending timers.
  Future<void> unmountTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          appSettingsStoreProvider.overrideWithValue(
            FakeAppSettingsStore(settings),
          ),
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
  }

  testWidgets('показывает приветствие, баланс и кнопку «Сказать»', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Sona'), findsOneWidget);
    expect(find.textContaining('Баланс'), findsOneWidget);
    expect(find.text('0 ₽'), findsOneWidget);
    expect(find.text('доходы и расходы за этот месяц'), findsOneWidget);
    expect(find.text('Сказать'), findsOneWidget);

    await unmountTree(tester);
  });

  testWidgets('баланс считается по операциям: доходы минус расходы', (tester) async {
    await db.insertParsedOperations(
      [
        ParsedOperation(
          type: OperationType.income,
          amount: 10000,
          category: 'Доход',
          date: DateTime(2026, 9, 30),
        ),
        ParsedOperation(
          type: OperationType.expense,
          amount: 2300,
          category: 'Продукты',
          date: DateTime(2026, 9, 30),
        ),
      ],
      source: OperationSource.manual,
    );

    await pumpScreen(tester);

    expect(find.text('+10 000 ₽'), findsOneWidget);
    expect(find.textContaining('−2 300 ₽'), findsWidgets);

    await unmountTree(tester);
  });

  testWidgets('последние операции отображаются списком', (tester) async {
    await db.insertParsedOperations(
      [
        ParsedOperation(
          type: OperationType.expense,
          amount: 450,
          category: 'Кафе и рестораны',
          subcategory: 'Кафе',
          date: DateTime(2026, 9, 30),
        ),
      ],
      source: OperationSource.voice,
    );

    await pumpScreen(tester);

    expect(find.text('Кафе и рестораны · Кафе'), findsOneWidget);
    expect(find.textContaining('−450 ₽'), findsWidgets);

    await unmountTree(tester);
  });

  testWidgets('мини-прогресс бюджета появляется при заданном бюджете', (tester) async {
    await pumpScreen(tester, settings: const AppSettings(monthlyBudget: 30000));

    expect(find.text('Бюджет месяца'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('0 ₽ из 30 000 ₽'), findsOneWidget);

    await unmountTree(tester);
  });

  testWidgets('без бюджета секция бюджета скрыта', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Бюджет месяца'), findsNothing);
    expect(find.text('Совет дня'), findsOneWidget);

    await unmountTree(tester);
  });

  testWidgets('совет дня показывается', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Совет дня'), findsOneWidget);

    await unmountTree(tester);
  });

  testWidgets('быстрые действия открывают запись текстом и категории', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Написать'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Напишите операцию'), findsOneWidget);

    router.go('/');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Категории'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Продукты'), findsOneWidget);

    await unmountTree(tester);
  });
}
