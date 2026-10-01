import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/app/providers.dart';
import 'package:sona/data/local/app_database.dart';
import 'package:sona/domain/models/app_settings.dart';
import 'package:sona/domain/models/category.dart';
import 'package:sona/domain/models/operation.dart';
import 'package:sona/features/profile/presentation/data_management_controller.dart';

import '../support/fakes.dart';

void main() {
  late AppDatabase db;
  late FakeAppSettingsStore settings;
  late FakeDataExportStore exporter;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.seedCategories(kDefaultCategories);
    settings = FakeAppSettingsStore(
      const AppSettings(monthlyBudget: 30000, userName: 'Андрей'),
    );
    exporter = FakeDataExportStore();
    container = ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appSettingsStoreProvider.overrideWithValue(settings),
        dataExportStoreProvider.overrideWithValue(exporter),
      ],
    );
    await container.read(appSettingsProvider.future);
  });

  tearDown(() async {
    await db.close();
  });

  test('экспорт собирает данные и записывает файл', () async {
    await db.insertParsedOperations(
      [
        ParsedOperation(
          type: OperationType.expense,
          amount: 450,
          category: 'Кафе и рестораны',
          subcategory: 'Кафе',
          date: DateTime.now(),
        ),
      ],
      source: OperationSource.manual,
    );
    await db.upsertRule(
      keyword: 'кофе',
      category: 'Кафе и рестораны',
    );

    final ok = await container
        .read(dataManagementProvider.notifier)
        .exportData();

    expect(ok, isTrue);
    expect(exporter.writes, hasLength(1));
    expect(exporter.writes.first.fileName, startsWith('sona-backup-'));

    final decoded =
        jsonDecode(exporter.writes.first.content) as Map<String, dynamic>;
    expect(decoded['format'], 'sona.backup');
    expect((decoded['operations'] as List), hasLength(1));
    expect((decoded['categories'] as List), hasLength(kDefaultCategories.length));
    expect((decoded['categorizationRules'] as List), hasLength(1));
    expect((decoded['settings'] as Map)['monthlyBudget'], 30000);

    expect(container.read(dataManagementProvider).lastExportPath, isNotNull);
  });

  test('удаление очищает операции, правила и сбрасывает настройки', () async {
    await db.insertParsedOperations(
      [
        ParsedOperation(
          type: OperationType.expense,
          amount: 450,
          category: 'Кафе и рестораны',
          date: DateTime.now(),
        ),
      ],
      source: OperationSource.manual,
    );
    await db.upsertRule(keyword: 'кофе', category: 'Кафе и рестораны');
    await db.addCategory('Хобби');

    final ok = await container
        .read(dataManagementProvider.notifier)
        .deleteAllData();

    expect(ok, isTrue);
    expect(await db.recentOperations(), isEmpty);
    expect(await db.allRules(), isEmpty);
    expect(
      await db.categoriesWithSubcategories(),
      hasLength(kDefaultCategories.length),
    );
    expect(settings.settings.monthlyBudget, isNull);
    expect(settings.settings.onboardingCompleted, isTrue);
  });
}
