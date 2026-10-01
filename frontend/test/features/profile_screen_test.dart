import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sona/app/providers.dart';
import 'package:sona/core/router/app_router.dart';
import 'package:sona/core/theme/app_theme.dart';
import 'package:sona/data/local/app_database.dart';
import 'package:sona/domain/models/app_settings.dart';
import 'package:sona/domain/models/category.dart';
import 'package:sona/l10n/l10n.dart';

import '../support/fakes.dart';

void main() {
  late AppDatabase db;
  late GoRouter router;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.seedCategories(kDefaultCategories);
    router = buildRouter(
      onboardingCompleted: () => true,
      refreshListenable: ValueNotifier<bool?>(true),
    );
    addTearDown(router.dispose);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> unmountTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<FakeAppSettingsStore> pumpProfile(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = FakeAppSettingsStore(settings);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          appSettingsStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    router.go(AppRoutes.profile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return store;
  }

  testWidgets('показывает профиль, скоринг и меню разделов', (tester) async {
    await pumpProfile(
      tester,
      settings: const AppSettings(
        userName: 'Андрей',
        userEmail: 'andrey@example.com',
      ),
    );

    expect(find.text('Профиль'), findsOneWidget);
    expect(find.text('Андрей'), findsOneWidget);
    expect(find.text('andrey@example.com'), findsOneWidget);
    expect(find.text('Финансовое здоровье'), findsOneWidget);
    expect(find.text('Данные'), findsOneWidget);
    expect(find.text('Счета'), findsOneWidget);
    expect(find.text('Категории'), findsOneWidget);
    expect(find.text('Уведомления'), findsOneWidget);
    expect(find.text('Безопасность'), findsOneWidget);
    expect(find.text('Подписка'), findsOneWidget);
    expect(find.text('Выйти'), findsOneWidget);

    await unmountTree(tester);
  });

  testWidgets('редактирование профиля сохраняет имя и email', (tester) async {
    final store = await pumpProfile(tester);

    expect(find.text('Без имени'), findsOneWidget);
    await tester.tap(find.text('Без имени'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(find.byType(TextField).first, 'Мария');
    await tester.enterText(find.byType(TextField).last, 'maria@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(store.settings.userName, 'Мария');
    expect(store.settings.userEmail, 'maria@example.com');
    expect(find.text('Мария'), findsOneWidget);

    await unmountTree(tester);
  });

  testWidgets('раздел «Данные» открывает экран экспорта', (tester) async {
    await pumpProfile(tester);

    await tester.tap(find.text('Данные'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Экспорт данных'), findsOneWidget);
    expect(find.text('Удаление данных'), findsOneWidget);

    await unmountTree(tester);
  });

  testWidgets('раздел «Безопасность» открывает настройки защиты', (
    tester,
  ) async {
    await pumpProfile(tester);

    await tester.tap(find.text('Безопасность'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Защита входа'), findsOneWidget);

    await unmountTree(tester);
  });

  testWidgets('в безопасности включается режим «Только ручной ввод»', (
    tester,
  ) async {
    final store = await pumpProfile(tester);

    await tester.tap(find.text('Безопасность'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Только ручной ввод'), findsOneWidget);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Только ручной ввод'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(store.settings.manualOnlyMode, isTrue);

    await unmountTree(tester);
  });
}
