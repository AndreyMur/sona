import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sona/app/providers.dart';
import 'package:sona/core/router/app_router.dart';
import 'package:sona/core/theme/app_theme.dart';
import 'package:sona/core/utils/analytics_math.dart';
import 'package:sona/core/utils/formatters.dart';
import 'package:sona/data/local/app_database.dart';
import 'package:sona/domain/models/operation.dart';

import '../support/fakes.dart';

void main() {
  late AppDatabase db;
  late GoRouter router;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
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

  Future<void> pumpScreen(WidgetTester tester) async {
    final store = FakeAppSettingsStore();
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
    router.go('/analytics');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  String weekCaption([DateTime? now]) => SonaFormat.periodCaption(
        AnalyticsMath.rangeFor(AnalyticsPeriod.week, now ?? DateTime.now()),
        AnalyticsPeriod.week,
      );

  String monthCaption([DateTime? now]) => SonaFormat.periodCaption(
        AnalyticsMath.rangeFor(AnalyticsPeriod.month, now ?? DateTime.now()),
        AnalyticsPeriod.month,
      );

  testWidgets('табы периодов переключают подпись и сводные данные', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Неделя'), findsOneWidget);
    expect(find.text('Месяц'), findsOneWidget);
    expect(find.text('Год'), findsOneWidget);
    expect(find.text('Период'), findsOneWidget);
    expect(find.text(weekCaption()), findsOneWidget);

    await tester.tap(find.text('Месяц'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(monthCaption()), findsOneWidget);

    await tester.tap(find.text('Год'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final yearCaption = SonaFormat.periodCaption(
      AnalyticsMath.rangeFor(AnalyticsPeriod.year, DateTime.now()),
      AnalyticsPeriod.year,
    );
    expect(find.text(yearCaption), findsOneWidget);

    await unmountTree(tester);
  });

  testWidgets('сводка показывает сумму трат и дельту к прошлому периоду', (tester) async {
    await db.insertParsedOperations([
      ParsedOperation(
        type: OperationType.expense,
        amount: 3000,
        category: 'Продукты',
        date: DateTime.now(),
      ),
      ParsedOperation(
        type: OperationType.expense,
        amount: 1000,
        category: 'Транспорт',
        date: DateTime.now(),
      ),
      // Прошлая неделя: только продукты на 1000.
      ParsedOperation(
        type: OperationType.expense,
        amount: 1000,
        category: 'Продукты',
        date: DateTime.now().subtract(const Duration(days: 7)),
      ),
    ], source: OperationSource.manual);

    await pumpScreen(tester);

    expect(find.text('4 000 ₽'), findsOneWidget);
    // (4000 − 1000) / 1000 = +300% к прошлой неделе.
    expect(find.textContaining('+300% к прошлой неделе'), findsOneWidget);

    await unmountTree(tester);
  });

  testWidgets('снижение трат показывается зелёным со знаком минус', (tester) async {
    await db.insertParsedOperations([
      ParsedOperation(
        type: OperationType.expense,
        amount: 1000,
        category: 'Продукты',
        date: DateTime.now(),
      ),
      ParsedOperation(
        type: OperationType.expense,
        amount: 4000,
        category: 'Продукты',
        date: DateTime.now().subtract(const Duration(days: 7)),
      ),
    ], source: OperationSource.manual);

    await pumpScreen(tester);

    expect(find.text('1 000 ₽'), findsOneWidget);
    expect(find.textContaining('−75% к прошлой неделе'), findsOneWidget);

    await unmountTree(tester);
  });

  testWidgets('топ категорий ранжирован по убыванию трат', (tester) async {
    await db.insertParsedOperations([
      ParsedOperation(
        type: OperationType.expense,
        amount: 3000,
        category: 'Продукты',
        date: DateTime.now(),
      ),
      ParsedOperation(
        type: OperationType.expense,
        amount: 1000,
        category: 'Транспорт',
        date: DateTime.now(),
      ),
    ], source: OperationSource.manual);

    await pumpScreen(tester);

    expect(find.text('Топ категорий'), findsOneWidget);

    final productsRow = tester.getCenter(find.textContaining('3 000 ₽ · 75%'));
    final transportRow = tester.getCenter(find.textContaining('1 000 ₽ · 25%'));
    expect(productsRow.dy, lessThan(transportRow.dy));

    expect(find.textContaining('3 000 ₽ · 75%'), findsOneWidget);
    expect(find.textContaining('1 000 ₽ · 25%'), findsOneWidget);

    await unmountTree(tester);
  });

  testWidgets('бар-чарт показывает последние шесть месяцев', (tester) async {
    final now = DateTime.now();
    await db.insertParsedOperations([
      ParsedOperation(
        type: OperationType.expense,
        amount: 2000,
        category: 'Продукты',
        date: DateTime(now.year, now.month - 2, 15),
      ),
    ], source: OperationSource.manual);

    await pumpScreen(tester);

    expect(find.text('По месяцам'), findsOneWidget);
    expect(
      find.text(SonaFormat.monthShort(now.month)),
      findsOneWidget,
    );

    await unmountTree(tester);
  });

  testWidgets('фильтр по категории пересчитывает сводку и сбрасывается', (tester) async {
    await db.insertParsedOperations([
      ParsedOperation(
        type: OperationType.expense,
        amount: 3000,
        category: 'Продукты',
        date: DateTime.now(),
      ),
      ParsedOperation(
        type: OperationType.expense,
        amount: 1000,
        category: 'Транспорт',
        date: DateTime.now(),
      ),
      ParsedOperation(
        type: OperationType.expense,
        amount: 1000,
        category: 'Продукты',
        date: DateTime.now().subtract(const Duration(days: 7)),
      ),
      ParsedOperation(
        type: OperationType.expense,
        amount: 3000,
        category: 'Транспорт',
        date: DateTime.now().subtract(const Duration(days: 7)),
      ),
    ], source: OperationSource.manual);

    await pumpScreen(tester);

    expect(find.text('4 000 ₽'), findsOneWidget);
    expect(find.textContaining('0% к прошлой неделе'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Продукты'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilterChip, 'Продукты'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('3 000 ₽'), findsOneWidget);
    // Только продукты: (3000 − 1000) / 1000 = +200%.
    expect(find.textContaining('+200% к прошлой неделе'), findsOneWidget);

    await tester.tap(find.byTooltip('Сбросить фильтр'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('4 000 ₽'), findsOneWidget);

    await unmountTree(tester);
  });

  testWidgets('на табе Период доступен выбор произвольного диапазона', (tester) async {
    await pumpScreen(tester);

    expect(find.textContaining('Диапазон:'), findsNothing);

    await tester.tap(find.text('Период'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final caption = SonaFormat.periodCaption(
      AnalyticsMath.rangeFor(AnalyticsPeriod.custom, DateTime.now()),
      AnalyticsPeriod.custom,
    );
    expect(find.text('Диапазон: $caption'), findsOneWidget);

    await unmountTree(tester);
  });
}
