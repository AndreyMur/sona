import 'package:flutter_test/flutter_test.dart';
import 'package:sona/data/services/local_text_parser.dart';
import 'package:sona/domain/models/categorization_rule.dart';
import 'package:sona/domain/models/operation.dart';
import 'package:sona/domain/services/learning_text_parser.dart';

import '../support/fakes.dart';

CategorizationRule rule(String keyword, String category, [String? sub]) {
  return CategorizationRule(
    id: 1,
    keyword: keyword,
    category: category,
    subcategory: sub,
    createdAt: DateTime(2026, 9, 30),
  );
}

void main() {
  test('выученное правило определяет категорию, которую словарь не знает', () async {
    final parser = LearnedRulesParser(
      const LocalTextParser(),
      FakeCategorizationRepository([rule('бигмак', 'Кафе и рестораны', 'Фастфуд')]),
    );

    final result = await parser.parse('бигмак 500');

    expect(result.operations, hasLength(1));
    expect(result.operations.single.category, 'Кафе и рестораны');
    expect(result.operations.single.subcategory, 'Фастфуд');
    expect(result.operations.single.confidence, 0.85);
  });

  test('правило «Доход» меняет тип операции на доход', () async {
    final parser = LearnedRulesParser(
      const LocalTextParser(),
      FakeCategorizationRepository([rule('преми', 'Доход', 'Зарплата')]),
    );

    final result = await parser.parse('премия 15000');

    expect(result.operations.single.type, OperationType.income);
  });

  test('для фразы с несколькими операциями правило не применяется', () async {
    final parser = LearnedRulesParser(
      const LocalTextParser(),
      FakeCategorizationRepository([rule('бигмак', 'Кафе и рестораны', 'Фастфуд')]),
    );

    final result = await parser.parse('кофе 450 и бигмак 500');

    expect(result.operations, hasLength(2));
    expect(result.operations.first.category, 'Кафе и рестораны');
    expect(result.operations.last.category, 'Другое');
  });

  test('без совпадающих правил результат базового парсера не меняется', () async {
    final parser = LearnedRulesParser(
      const LocalTextParser(),
      FakeCategorizationRepository([rule('кресло', 'Мебель')]),
    );

    final result = await parser.parse('такси 400');

    expect(result.operations.single.category, 'Транспорт');
    expect(result.operations.single.subcategory, 'Такси');
  });

  test('совпадающее правило не меняет совпадающую категорию', () async {
    final parser = LearnedRulesParser(
      const LocalTextParser(),
      FakeCategorizationRepository([rule('такси', 'Транспорт', 'Такси')]),
    );

    final result = await parser.parse('такси 400');

    expect(result.operations.single.confidence, 0.7);
  });
}
