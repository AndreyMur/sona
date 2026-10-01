import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sona/core/utils/backup.dart';
import 'package:sona/domain/models/app_settings.dart';
import 'package:sona/domain/models/categorization_rule.dart';
import 'package:sona/domain/models/category.dart';
import 'package:sona/domain/models/operation.dart';

void main() {
  test('backupFileName содержит дату', () {
    expect(
      backupFileName(DateTime(2026, 10, 1)),
      'sona-backup-2026-10-01.json',
    );
  });

  test('buildBackupJson сериализует все разделы данных', () {
    final json = buildBackupJson(
      operations: [
        Operation(
          id: 1,
          type: OperationType.expense,
          amount: 450,
          category: 'Кафе и рестораны',
          subcategory: 'Кафе',
          date: DateTime(2026, 10, 1),
          confidence: 0.9,
          source: OperationSource.voice,
          createdAt: DateTime(2026, 10, 1, 12),
        ),
      ],
      categories: const [
        Category(
          id: 1,
          name: 'Продукты',
          isIncome: false,
          subcategories: ['Супермаркет'],
        ),
      ],
      rules: [
        CategorizationRule(
          id: 1,
          keyword: 'кофе',
          category: 'Кафе и рестораны',
          createdAt: DateTime(2026, 10, 1),
        ),
      ],
      settings: const AppSettings(
        currencyCode: '₽',
        monthlyBudget: 50000,
        userName: 'Андрей',
      ),
      exportedAt: DateTime(2026, 10, 1, 15, 30),
    );

    final decoded = jsonDecode(json) as Map<String, dynamic>;
    expect(decoded['format'], 'sona.backup');
    expect(decoded['formatVersion'], kBackupFormatVersion);
    expect(decoded['exportedAt'], '2026-10-01T15:30:00.000');
    expect((decoded['operations'] as List), hasLength(1));
    expect((decoded['operations'] as List).first['category'],
        'Кафе и рестораны');
    expect((decoded['categories'] as List).first['name'], 'Продукты');
    expect((decoded['categorizationRules'] as List).first['keyword'], 'кофе');
    expect((decoded['settings'] as Map)['monthlyBudget'], 50000);
    expect((decoded['settings'] as Map)['userName'], 'Андрей');
  });
}
