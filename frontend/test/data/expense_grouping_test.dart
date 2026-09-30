import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/data/local/app_database.dart';
import 'package:sona/data/repositories/operation_repository_impl.dart';
import 'package:sona/domain/models/app_settings.dart';
import 'package:sona/domain/models/operation.dart';

void main() {
  late AppDatabase db;
  late DriftOperationRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftOperationRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('расходы по категориям за окно дат', () async {
    await db.insertParsedOperations([
      ParsedOperation(
        type: OperationType.expense,
        amount: 2300,
        category: 'Продукты',
        date: DateTime(2026, 9, 10),
      ),
      ParsedOperation(
        type: OperationType.expense,
        amount: 700,
        category: 'Продукты',
        date: DateTime(2026, 9, 20),
      ),
      ParsedOperation(
        type: OperationType.expense,
        amount: 500,
        category: 'Транспорт',
        date: DateTime(2026, 9, 25),
      ),
      ParsedOperation(
        type: OperationType.expense,
        amount: 9999,
        category: 'Другое',
        date: DateTime(2026, 8, 15),
      ),
      ParsedOperation(
        type: OperationType.expense,
        amount: 1234,
        category: 'Будущее',
        date: DateTime(2026, 10, 5),
      ),
      ParsedOperation(
        type: OperationType.income,
        amount: 10000,
        category: 'Доход',
        date: DateTime(2026, 9, 5),
      ),
    ], source: OperationSource.manual);

    final groups = await repository.expensesByCategory(
      from: DateTime(2026, 9, 1),
      to: DateTime(2026, 10, 1),
    );

    expect(groups, {'Продукты': 3000, 'Транспорт': 500});
  });

  test('расходы по парам категория :: подкатегория', () async {
    await db.insertParsedOperations([
      ParsedOperation(
        type: OperationType.expense,
        amount: 800,
        category: 'Продукты',
        subcategory: 'Супермаркет',
        date: DateTime(2026, 9, 10),
      ),
      ParsedOperation(
        type: OperationType.expense,
        amount: 200,
        category: 'Продукты',
        subcategory: 'Супермаркет',
        date: DateTime(2026, 9, 15),
      ),
      ParsedOperation(
        type: OperationType.expense,
        amount: 400,
        category: 'Продукты',
        subcategory: 'Доставка',
        date: DateTime(2026, 9, 20),
      ),
      // Без подкатегории — пропускается в группировке по парам.
      ParsedOperation(
        type: OperationType.expense,
        amount: 300,
        category: 'Транспорт',
        date: DateTime(2026, 9, 20),
      ),
      // Другой месяц — вне окна.
      ParsedOperation(
        type: OperationType.expense,
        amount: 777,
        category: 'Продукты',
        subcategory: 'Супермаркет',
        date: DateTime(2026, 8, 3),
      ),
    ], source: OperationSource.manual);

    final groups = await repository.expensesBySubcategory(
      from: DateTime(2026, 9, 1),
      to: DateTime(2026, 10, 1),
    );

    expect(
      groups,
      {
        'Продукты::Супермаркет': 1000,
        'Продукты::Доставка': 400,
      },
    );
  });

  test('расходы по месяцам с разбивкой по категориям', () async {
    await db.insertParsedOperations([
      ParsedOperation(
        type: OperationType.expense,
        amount: 800,
        category: 'Продукты',
        date: DateTime(2026, 9, 5),
      ),
      ParsedOperation(
        type: OperationType.expense,
        amount: 400,
        category: 'Транспорт',
        date: DateTime(2026, 9, 20),
      ),
      ParsedOperation(
        type: OperationType.expense,
        amount: 700,
        category: 'Продукты',
        date: DateTime(2026, 9, 25),
      ),
      ParsedOperation(
        type: OperationType.expense,
        amount: 1500,
        category: 'Одежда',
        date: DateTime(2026, 8, 10),
      ),
      ParsedOperation(
        type: OperationType.income,
        amount: 10000,
        category: 'Доход',
        date: DateTime(2026, 9, 5),
      ),
    ], source: OperationSource.manual);

    final groups = await repository.expensesByMonthCategory(
      from: DateTime(2026, 8, 1),
      to: DateTime(2026, 10, 1),
    );

    expect(groups.keys, ['2026-08', '2026-09']);
    expect(groups['2026-09'], {'Продукты': 1500, 'Транспорт': 400});
    expect(groups['2026-08'], {'Одежда': 1500});
  });

  test('ключи лимитов согласованы с настройками', () async {
    await db.insertParsedOperations([
      ParsedOperation(
        type: OperationType.expense,
        amount: 1000,
        category: 'Продукты',
        subcategory: 'Супермаркет',
        date: DateTime(2026, 9, 10),
      ),
    ], source: OperationSource.manual);

    final groups = await repository.expensesBySubcategory(
      from: DateTime(2026, 9, 1),
      to: DateTime(2026, 10, 1),
    );
    final key = subcategoryLimitKey('Продукты', 'Супермаркет');

    expect(groups.containsKey(key), isTrue);
    expect(
      AppSettings(categoryLimits: {key: 5000}).limitFor(
        'Продукты',
        'Супермаркет',
      ),
      5000,
    );
  });
}
