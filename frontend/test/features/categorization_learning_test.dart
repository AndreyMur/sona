import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/app/providers.dart';
import 'package:sona/data/local/app_database.dart';
import 'package:sona/domain/models/operation.dart';
import 'package:sona/domain/models/recognition.dart';
import 'package:sona/features/record/presentation/record_controller.dart';

import '../support/fakes.dart';

ParseResult coffeeResult() {
  return ParseResult(
    operations: [
      ParsedOperation(
        type: OperationType.expense,
        amount: 450,
        category: 'Другое',
        date: DateTime(2026, 9, 30),
        confidence: 0.6,
      ),
    ],
    overallConfidence: 0.6,
    model: 'google/gemini-3.8-flash',
  );
}

void main() {
  late AppDatabase db;
  late FakeTextParsing nlu;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    nlu = FakeTextParsing(byText: {'кофе 450': coffeeResult()});
  });

  tearDown(() => db.close());

  ProviderContainer container() => ProviderContainer.test(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      textParsingProvider.overrideWithValue(nlu),
    ],
  );

  test('правка категории до сохранения обучает правило', () async {
    final c = container();
    final controller = c.read(recordControllerProvider.notifier);

    await controller.submitText('кофе 450');
    final parsed = c.read(recordControllerProvider);
    expect(parsed.operations.single.category, 'Другое');

    controller.updateOperation(
      0,
      parsed.operations.single.copyWith(
        category: 'Кафе и рестораны',
        subcategory: 'Кафе',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final rules = await db.allRules();
    expect(rules, hasLength(1));
    expect(rules.single.keyword, 'кофе');
    expect(rules.single.category, 'Кафе и рестораны');
    expect(rules.single.subcategory, 'Кафе');
  });

  test('правка без смены категории не обучает правило', () async {
    final c = container();
    final controller = c.read(recordControllerProvider.notifier);

    await controller.submitText('кофе 450');
    final parsed = c.read(recordControllerProvider);

    controller.updateOperation(0, parsed.operations.single);
    await Future<void>.delayed(Duration.zero);

    expect(await db.allRules(), isEmpty);
  });

  test('офлайн-парсер применяет выученное правило вместо словаря', () async {
    final c = container();
    final controller = c.read(recordControllerProvider.notifier);

    await controller.submitText('кофе 450');
    final parsed = c.read(recordControllerProvider);
    controller.updateOperation(
      0,
      parsed.operations.single.copyWith(category: 'Продукты'),
    );
    await Future<void>.delayed(Duration.zero);

    final offline = await c.read(localTextParserProvider).parse('кофе 450');
    expect(offline.operations.single.category, 'Продукты');
    expect(offline.operations.single.confidence, 0.85);
  });
}
