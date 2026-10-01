import 'package:drift/drift.dart';

import '../../domain/models/app_settings.dart';
import '../../domain/models/categorization_rule.dart';
import '../../domain/models/category.dart';
import '../../domain/models/operation.dart';

part 'app_database.g.dart';

/// Локальные финансовые операции.
@DataClassName('OperationRow')
class Operations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  RealColumn get amount => real()();
  TextColumn get category => text()();
  TextColumn get subcategory => text().nullable()();
  DateTimeColumn get date => dateTime()();
  RealColumn get confidence => real().withDefault(const Constant(1))();
  TextColumn get source => text().withDefault(const Constant('voice'))();
  DateTimeColumn get createdAt => dateTime()();
}

/// Категории операций.
@DataClassName('CategoryRow')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  BoolColumn get isIncome => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Подкатегории, привязанные к категории.
@DataClassName('SubcategoryRow')
class Subcategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {categoryId, name},
  ];
}

/// Выученные правила категоризации (обучение по правкам пользователя).
@DataClassName('CategorizationRuleRow')
class CategorizationRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get keyword => text().unique()();
  TextColumn get category => text()();
  TextColumn get subcategory => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Локальная БД приложения Sona.
///
/// В продакшене открывается через [driftDatabase] с шифрованием SQLCipher
/// (см. `connection.dart`), в тестах — через `NativeDatabase.memory()`.
@DriftDatabase(
  tables: [Operations, Categories, Subcategories, CategorizationRules],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(categorizationRules);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<List<Operation>> recentOperations({int limit = 20}) {
    final query = select(operations)
      ..orderBy([
        (t) => OrderingTerm.desc(t.date),
        (t) => OrderingTerm.desc(t.createdAt),
      ])
      ..limit(limit);
    return query.get().then((rows) => rows.map(_toOperation).toList());
  }

  Future<List<Operation>> allOperations() {
    final query = select(operations)
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);
    return query.get().then((rows) => rows.map(_toOperation).toList());
  }

  Stream<List<Operation>> watchRecentOperations({int limit = 20}) {
    final query = select(operations)
      ..orderBy([
        (t) => OrderingTerm.desc(t.date),
        (t) => OrderingTerm.desc(t.createdAt),
      ])
      ..limit(limit);
    return query.watch().map((rows) => rows.map(_toOperation).toList());
  }

  Future<List<Operation>> insertParsedOperations(
    List<ParsedOperation> parsed, {
    required OperationSource source,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    return transaction(() async {
      final saved = <Operation>[];
      for (final op in parsed) {
        final row = await into(operations).insertReturning(
          OperationsCompanion.insert(
            type: op.type.wireValue,
            amount: op.amount,
            category: op.category,
            subcategory: Value(op.subcategory),
            date: op.date,
            confidence: Value(op.confidence),
            source: Value(source.wireValue),
            createdAt: now,
          ),
        );
        saved.add(_toOperation(row));
      }
      return saved;
    });
  }

  Future<void> updateOperation(Operation operation) {
    return update(operations).replace(
      OperationsCompanion(
        id: Value(operation.id),
        type: Value(operation.type.wireValue),
        amount: Value(operation.amount),
        category: Value(operation.category),
        subcategory: Value(operation.subcategory),
        date: Value(operation.date),
        confidence: Value(operation.confidence),
        source: Value(operation.source.wireValue),
        createdAt: Value(operation.createdAt),
      ),
    );
  }

  Future<void> deleteOperation(int id) {
    return (delete(operations)..where((t) => t.id.equals(id))).go();
  }

  /// Удаляет все операции пользователя (полный сброс данных).
  Future<void> deleteAllOperations() => delete(operations).go();

  /// Сумма операций с фильтрами по типу, категории и периоду `[from, to)`.
  Future<double> sumAmounts({
    OperationType? type,
    String? category,
    DateTime? from,
    DateTime? to,
  }) async {
    final total = operations.amount.sum();
    final query = selectOnly(operations)..addColumns([total]);
    if (type != null) {
      query.where(operations.type.equals(type.wireValue));
    }
    if (category != null) {
      query.where(operations.category.equals(category));
    }
    if (from != null) {
      query.where(operations.date.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where(operations.date.isSmallerThanValue(to));
    }
    final row = await query.getSingle();
    return row.read(total) ?? 0;
  }

  Future<int> countOperations() async {
    final count = operations.id.count();
    final query = selectOnly(operations)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Expression<bool> _expenseWindowFilter({
    DateTime? from,
    DateTime? to,
  }) {
    Expression<bool> filter =
        operations.type.equals(OperationType.expense.wireValue);
    if (from != null) {
      filter = filter & operations.date.isBiggerOrEqualValue(from);
    }
    if (to != null) {
      filter = filter & operations.date.isSmallerThanValue(to);
    }
    return filter;
  }

  /// Расходы за окно `[from, to)`, сгруппированные по категории.
  Future<Map<String, double>> expenseTotalsByCategory({
    DateTime? from,
    DateTime? to,
  }) async {
    final total = operations.amount.sum();
    final query = selectOnly(operations)
      ..addColumns([operations.category, total])
      ..where(_expenseWindowFilter(from: from, to: to))
      ..groupBy([operations.category]);
    final rows = await query.get();
    final result = <String, double>{};
    for (final row in rows) {
      final category = row.read(operations.category);
      final sum = row.read(total);
      if (category != null && sum != null) result[category] = sum;
    }
    return result;
  }

  /// Расходы за окно `[from, to)`, сгруппированные по парам
  /// «категория :: подкатегория». Строки без подкатегории пропускаются.
  Future<Map<String, double>> expenseTotalsByCategorySubcategory({
    DateTime? from,
    DateTime? to,
  }) async {
    final total = operations.amount.sum();
    final query = selectOnly(operations)
      ..addColumns([operations.category, operations.subcategory, total])
      ..where(
        _expenseWindowFilter(from: from, to: to) &
            operations.subcategory.isNotNull(),
      )
      ..groupBy([operations.category, operations.subcategory]);
    final rows = await query.get();
    final result = <String, double>{};
    for (final row in rows) {
      final category = row.read(operations.category);
      final subcategory = row.read(operations.subcategory);
      final sum = row.read(total);
      if (category != null &&
          subcategory != null &&
          subcategory.isNotEmpty &&
          sum != null) {
        result[subcategoryLimitKey(category, subcategory)] = sum;
      }
    }
    return result;
  }

  /// Расходы за окно `[from, to)`, сгруппированные по месяцам
  /// (ключ «YYYY-MM») и внутри месяца — по категории. Пригодно для
  /// бар-чарта динамики по месяцам с фильтром по категориям.
  Future<Map<String, Map<String, double>>> expenseTotalsByMonthCategory({
    DateTime? from,
    DateTime? to,
  }) async {
    final total = operations.amount.sum();
    final year = operations.date.year;
    final month = operations.date.month;
    final query = selectOnly(operations)
      ..addColumns([year, month, operations.category, total])
      ..where(_expenseWindowFilter(from: from, to: to))
      ..groupBy([year, month, operations.category]);
    final rows = await query.get();
    final result = <String, Map<String, double>>{};
    for (final row in rows) {
      final y = row.read(year);
      final m = row.read(month);
      final category = row.read(operations.category);
      final sum = row.read(total);
      if (y == null || m == null || category == null || sum == null) continue;
      final key = '$y-${m.toString().padLeft(2, '0')}';
      (result[key] ??= {})[category] = sum;
    }
    return result;
  }

  Future<List<Category>> categoriesWithSubcategories() async {
    final categoryRows = await (select(
      categories,
    )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
    final subRows = await (select(
      subcategories,
    )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();

    return categoryRows.map((category) {
      final subs = subRows
          .where((sub) => sub.categoryId == category.id)
          .map((sub) => sub.name)
          .toList();
      return Category(
        id: category.id,
        name: category.name,
        isIncome: category.isIncome,
        subcategories: subs,
        sortOrder: category.sortOrder,
      );
    }).toList();
  }

  Stream<List<Category>> watchCategoriesWithSubcategories() {
    return (select(categories)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch()
        .asyncMap((_) => categoriesWithSubcategories());
  }

  Future<void> seedCategories(Map<String, List<String>> source) async {
    await transaction(() async {
      final sortBase = <String, int>{};
      var index = 0;
      for (final entry in source.entries) {
        sortBase[entry.key] = index++;
      }
      for (final entry in source.entries) {
        final categoryId = await into(categories).insert(
          CategoriesCompanion.insert(
            name: entry.key,
            isIncome: Value(entry.key == kIncomeCategory),
            sortOrder: Value(sortBase[entry.key]!),
          ),
        );
        var subOrder = 0;
        for (final sub in entry.value) {
          await into(subcategories).insert(
            SubcategoriesCompanion.insert(
              categoryId: categoryId,
              name: sub,
              sortOrder: Value(subOrder++),
            ),
          );
        }
      }
    });
  }

  Future<void> replaceCategories(Map<String, List<String>> source) async {
    await transaction(() async {
      await delete(subcategories).go();
      await delete(categories).go();
      await seedCategories(source);
    });
  }

  /// Добавляет категорию в конец списка и возвращает её id.
  Future<int> addCategory(String name, {bool isIncome = false}) async {
    final rows = await select(categories).get();
    var maxOrder = -1;
    for (final row in rows) {
      if (row.sortOrder > maxOrder) maxOrder = row.sortOrder;
    }
    return into(categories).insert(
      CategoriesCompanion.insert(
        name: name,
        isIncome: Value(isIncome),
        sortOrder: Value(maxOrder + 1),
      ),
    );
  }

  /// Переименовывает категорию.
  Future<void> renameCategory(int id, String name) {
    return (update(categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(name: Value(name)),
    );
  }

  /// Удаляет категорию вместе с подкатегориями (каскадно).
  Future<void> deleteCategory(int id) {
    return (delete(categories)..where((t) => t.id.equals(id))).go();
  }

  /// Добавляет подкатегорию к категории.
  Future<void> addSubcategory(int categoryId, String name) async {
    final rows = await (select(subcategories)
          ..where((t) => t.categoryId.equals(categoryId)))
        .get();
    var maxOrder = -1;
    for (final row in rows) {
      if (row.sortOrder > maxOrder) maxOrder = row.sortOrder;
    }
    await into(subcategories).insert(
      SubcategoriesCompanion.insert(
        categoryId: categoryId,
        name: name,
        sortOrder: Value(maxOrder + 1),
      ),
    );
  }

  /// Переименовывает подкатегорию категории.
  Future<void> renameSubcategory(int categoryId, String oldName, String newName) {
    return (update(subcategories)
          ..where((t) => t.categoryId.equals(categoryId) & t.name.equals(oldName)))
        .write(SubcategoriesCompanion(name: Value(newName)));
  }

  /// Удаляет подкатегорию категории.
  Future<void> deleteSubcategory(int categoryId, String name) {
    return (delete(subcategories)
          ..where((t) => t.categoryId.equals(categoryId) & t.name.equals(name)))
        .go();
  }

  /// Все выученные правила категоризации.
  Future<List<CategorizationRule>> allRules() {
    final query = select(categorizationRules)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.get().then((rows) => rows.map(_toRule).toList());
  }

  /// Поток правил категоризации.
  Stream<List<CategorizationRule>> watchRules() {
    final query = select(categorizationRules)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(_toRule).toList());
  }

  /// Создаёт или обновляет правило для [keyword].
  Future<CategorizationRule> upsertRule({
    required String keyword,
    required String category,
    String? subcategory,
    DateTime? createdAt,
  }) async {
    final existing =
        await (select(categorizationRules)
              ..where((t) => t.keyword.equals(keyword)))
            .getSingleOrNull();
    final now = createdAt ?? DateTime.now();
    if (existing != null) {
      await (update(categorizationRules)..where((t) => t.id.equals(existing.id)))
          .write(
            CategorizationRulesCompanion(
              category: Value(category),
              subcategory: Value(subcategory),
            ),
          );
      return CategorizationRule(
        id: existing.id,
        keyword: keyword,
        category: category,
        subcategory: subcategory,
        createdAt: existing.createdAt,
      );
    }
    final id = await into(categorizationRules).insert(
      CategorizationRulesCompanion.insert(
        keyword: keyword,
        category: category,
        subcategory: Value(subcategory),
        createdAt: now,
      ),
    );
    return CategorizationRule(
      id: id,
      keyword: keyword,
      category: category,
      subcategory: subcategory,
      createdAt: now,
    );
  }

  /// Удаляет правило категоризации.
  Future<void> deleteRule(int id) {
    return (delete(categorizationRules)..where((t) => t.id.equals(id))).go();
  }

  /// Удаляет все выученные правила категоризации.
  Future<void> deleteAllRules() => delete(categorizationRules).go();

  /// Сбрасывает категории к набору по умолчанию.
  Future<void> resetCategoriesToDefaults() =>
      replaceCategories(kDefaultCategories);

  CategorizationRule _toRule(CategorizationRuleRow row) {
    return CategorizationRule(
      id: row.id,
      keyword: row.keyword,
      category: row.category,
      subcategory: row.subcategory,
      createdAt: row.createdAt,
    );
  }

  Operation _toOperation(OperationRow row) {
    return Operation(
      id: row.id,
      type: OperationType.fromWire(row.type),
      amount: row.amount,
      category: row.category,
      subcategory: row.subcategory,
      date: row.date,
      confidence: row.confidence,
      source: OperationSource.fromWire(row.source),
      createdAt: row.createdAt,
    );
  }
}
