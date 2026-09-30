import 'package:drift/drift.dart';

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

/// Локальная БД приложения Sona.
///
/// В продакшене открывается через [driftDatabase] с шифрованием SQLCipher
/// (см. `connection.dart`), в тестах — через `NativeDatabase.memory()`.
@DriftDatabase(tables: [Operations, Categories, Subcategories])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
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

  Future<int> countOperations() async {
    final count = operations.id.count();
    final query = selectOnly(operations)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
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
