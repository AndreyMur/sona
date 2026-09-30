import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app/app.dart';
import 'app/budget_alert_coordinator.dart';
import 'app/providers.dart';
import 'data/fallback/demo_stores.dart';
import 'data/local/app_database.dart';
import 'data/local/connection.dart';
import 'data/repositories/category_repository_impl.dart';
import 'data/services/database_key_provider.dart';

/// Наблюдатели бюджетных уведомлений: оценка при старте и на изменениях.
void observeBudgetAlerts(ProviderContainer container) {
  void kick() =>
      container.read(budgetAlertCoordinatorProvider.notifier).evaluate();
  kick();
  container.listen(appSettingsProvider, (_, _) => kick());
  container.listen(monthlyExpenseProvider, (_, _) => kick());
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Веб-демо: нативная БД (SQLCipher) в браузере недоступна — запускаемся
  // с in-memory-хранилищами, данные живут до перезагрузки страницы.
  if (kIsWeb) {
    final container = ProviderContainer(
      overrides: [
        operationRepositoryProvider.overrideWithValue(
          DemoOperationRepository(),
        ),
        categoryRepositoryProvider.overrideWithValue(
          DemoCategoryRepository(),
        ),
        categorizationRepositoryProvider.overrideWithValue(
          DemoCategorizationRepository(),
        ),
        appSettingsStoreProvider.overrideWithValue(DemoAppSettingsStore()),
        notificationsPortProvider.overrideWithValue(DemoSonaNotifications()),
      ],
    );
    observeBudgetAlerts(container);
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const SonaApp(),
      ),
    );
    return;
  }

  const storage = FlutterSecureStorage();
  final encryptionKey = await DatabaseKeyProvider(storage).getOrCreate();
  final database = AppDatabase(
    openEncryptedDatabase(encryptionKey: encryptionKey),
  );
  await DriftCategoryRepository(database).seedIfEmpty();

  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(database)],
  );
  observeBudgetAlerts(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SonaApp(),
    ),
  );
}
