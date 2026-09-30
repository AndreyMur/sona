import 'package:flutter_test/flutter_test.dart';
import 'package:sona/data/services/local_text_parser.dart';
import 'package:sona/domain/models/operation.dart';

void main() {
  const parser = LocalTextParser();

  test('«кофе 450» → расход в категории «Кафе и рестораны»', () async {
    final result = await parser.parse('кофе 450');

    expect(result.operations, hasLength(1));
    final op = result.operations.single;
    expect(op.type, OperationType.expense);
    expect(op.amount, 450);
    expect(op.category, 'Кафе и рестораны');
    expect(op.subcategory, 'Кафе');
    expect(result.fallbackUsed, isTrue);
  });

  test('«такси 400» → «Транспорт / Такси»', () async {
    final op = (await parser.parse('такси 400')).operations.single;
    expect(op.category, 'Транспорт');
    expect(op.subcategory, 'Такси');
    expect(op.amount, 400);
  });

  test('одна фраза с двумя тратами → две операции', () async {
    final result = await parser.parse('продукты 2300 и такси 600');
    expect(result.operations, hasLength(2));
    expect(
      result.operations.map((op) => op.amount).toSet(),
      {2300.0, 600.0},
    );
    expect(
      result.operations.map((op) => op.category).toSet(),
      {'Продукты', 'Транспорт'},
    );
  });

  test('доход и множитель «тысяч»', () async {
    final op = (await parser.parse('зарплата 80 тысяч')).operations.single;
    expect(op.type, OperationType.income);
    expect(op.amount, 80000);
    expect(op.category, 'Доход');
    expect(op.subcategory, 'Зарплата');
  });

  test('«вчера» распознаётся как дата', () async {
    final op = (await parser.parse('вчера потратил 1500 на бензин'))
        .operations
        .single;
    expect(op.category, 'Транспорт');
    expect(op.subcategory, 'Бензин');
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    expect(op.date.day, yesterday.day);
  });

  test('неизвестное слово → «Другое» с низкой уверенностью', () async {
    final op = (await parser.parse('абракадабра 100')).operations.single;
    expect(op.category, 'Другое');
    expect(op.confidence, lessThan(0.7));
  });

  test('фраза без суммы → пустой результат', () async {
    final result = await parser.parse('просто поговорили');
    expect(result.operations, isEmpty);
  });
}
