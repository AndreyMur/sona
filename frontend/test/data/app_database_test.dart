import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sona/data/local/app_database.dart';
import 'package:sona/domain/models/category.dart';
import 'package:sona/domain/models/operation.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('операции', () {
    test('одна фраза с двумя тратами создаёт две операции', () async {
      final date = DateTime(2026, 9, 29);
      final saved = await db.insertParsedOperations(
        [
          ParsedOperation(
            type: OperationType.expense,
            amount: 2300,
            category: 'Продукты',
            subcategory: 'Супермаркет',
            date: date,
          ),
          ParsedOperation(
            type: OperationType.expense,
            amount: 600,
            category: 'Транспорт',
            subcategory: 'Такси',
            date: date,
          ),
        ],
        source: OperationSource.voice,
      );

      expect(saved, hasLength(2));
      expect(saved.every((op) => op.id > 0), isTrue);

      final recent = await db.recentOperations();
      expect(recent, hasLength(2));
      expect(
        recent.map((op) => op.amount).toSet(),
        {2300.0, 600.0},
      );
      expect(recent.every((op) => op.source == OperationSource.voice), isTrue);
    });

    test('операцию можно изменить и удалить', () async {
      final saved = await db.insertParsedOperations(
        [
          ParsedOperation(
            type: OperationType.expense,
            amount: 100,
            category: 'Другое',
            date: DateTime(2026, 9, 29),
          ),
        ],
        source: OperationSource.manual,
      );
      final operation = saved.single;

      await db.updateOperation(
        operation.copyWith(amount: 250, category: 'Продукты'),
      );
      final updated = (await db.recentOperations()).single;
      expect(updated.amount, 250);
      expect(updated.category, 'Продукты');

      await db.deleteOperation(updated.id);
      expect(await db.recentOperations(), isEmpty);
    });
  });

  group('категории', () {
    test('сеются 16 категорий с подкатегориями', () async {
      await db.seedCategories(kDefaultCategories);

      final categories = await db.categoriesWithSubcategories();
      expect(categories, hasLength(16));

      final transport = categories.firstWhere((c) => c.name == 'Транспорт');
      expect(transport.subcategories, contains('Такси'));
      expect(transport.subcategories, contains('Бензин'));

      final income = categories.firstWhere((c) => c.name == kIncomeCategory);
      expect(income.isIncome, isTrue);
      expect(income.subcategories, contains('Зарплата'));

      final other = categories.firstWhere((c) => c.name == kFallbackCategory);
      expect(other.subcategories, isEmpty);
    });

    test('replaceCategories заменяет справочник', () async {
      await db.seedCategories(kDefaultCategories);
      await db.replaceCategories({
        'Еда': ['Кафе'],
      });

      final categories = await db.categoriesWithSubcategories();
      expect(categories, hasLength(1));
      expect(categories.single.name, 'Еда');
      expect(categories.single.subcategories, ['Кафе']);
    });
  });

  test('БД шифруется SQLCipher: без ключа данные недоступны', () async {
    final directory = await Directory.systemTemp.createTemp('sona_db_test');
    final file = File(p.join(directory.path, 'encrypted.sqlite'));

    final keyed = AppDatabase(
      NativeDatabase(
        file,
        setup: (database) => database.execute("PRAGMA key = 'correct-horse';"),
      ),
    );
    await keyed.insertParsedOperations(
      [
        ParsedOperation(
          type: OperationType.expense,
          amount: 42,
          category: 'Другое',
          date: DateTime(2026, 9, 29),
        ),
      ],
      source: OperationSource.voice,
    );
    await keyed.close();

    final withoutKey = AppDatabase(NativeDatabase(file));
    await expectLater(
      withoutKey.customSelect('SELECT 1').get(),
      throwsA(isA<SqliteException>()),
    );
    await withoutKey.close();

    await directory.delete(recursive: true);
  });
}
