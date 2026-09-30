import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/app/providers.dart';
import 'package:sona/core/theme/app_theme.dart';
import 'package:sona/data/local/app_database.dart';
import 'package:sona/domain/models/category.dart';
import 'package:sona/features/categories/presentation/categories_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> pumpScreen(WidgetTester tester) async {
    await db.seedCategories(kDefaultCategories);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CategoriesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Размонтирует дерево внутри тела теста, чтобы drift успел закрыть
  /// подписки на потоки до проверки pending timers.
  Future<void> unmountTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('показывает категории по умолчанию', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Продукты'), findsOneWidget);
    expect(find.text('Транспорт'), findsOneWidget);

    final categories = await db.categoriesWithSubcategories();
    expect(categories, hasLength(16));
    expect(categories.any((c) => c.name == 'Доход'), isTrue);
    expect(categories.any((c) => c.name == 'Другое'), isTrue);

    await unmountTree(tester);
  });

  testWidgets('раскрывает подкатегории по тапу', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Супермаркет'), findsNothing);
    await tester.tap(find.text('Продукты'));
    await tester.pumpAndSettle();

    expect(find.text('Супермаркет'), findsOneWidget);
    expect(find.text('Рынок'), findsOneWidget);
    expect(find.text('Доставка'), findsOneWidget);
    expect(find.text('Добавить подкатегорию'), findsOneWidget);

    await unmountTree(tester);
  });

  testWidgets('добавляет новую категорию через диалог', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Хобби');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(find.text('Хобби'), findsNothing);
    await tester.dragUntilVisible(
      find.text('Хобби'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Хобби'), findsOneWidget);

    final categories = await db.categoriesWithSubcategories();
    expect(categories.any((c) => c.name == 'Хобби'), isTrue);

    await unmountTree(tester);
  });

  testWidgets('переименовывает категорию через меню', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Переименовать'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Еда и напитки');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(find.text('Еда и напитки'), findsOneWidget);
    final categories = await db.categoriesWithSubcategories();
    expect(categories.any((c) => c.name == 'Продукты'), isFalse);

    await unmountTree(tester);
  });

  testWidgets('удаляет подкатегорию', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Продукты'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить').last);
    await tester.pumpAndSettle();

    final products =
        (await db.categoriesWithSubcategories()).firstWhere(
      (c) => c.name == 'Продукты',
    );
    expect(products.subcategories, isNot(contains('Супермаркет')));
    expect(products.subcategories, contains('Рынок'));

    await unmountTree(tester);
  });
}
