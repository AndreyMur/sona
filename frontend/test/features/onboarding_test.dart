import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/app/providers.dart';
import 'package:sona/core/router/app_router.dart';
import 'package:sona/core/theme/app_theme.dart';
import 'package:sona/data/local/app_database.dart';
import 'package:sona/features/onboarding/presentation/onboarding_screen.dart';

import '../support/fakes.dart';

void main() {
  late FakeAppSettingsStore store;
  late FakePermissionService permissions;
  late AppDatabase db;

  setUp(() {
    store = FakeAppSettingsStore();
    permissions = FakePermissionService();
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsStoreProvider.overrideWithValue(store),
          permissionServiceProvider.overrideWithValue(permissions),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'новый пользователь проходит онбординг и попадает на главную',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          appSettingsStoreProvider.overrideWithValue(store),
          permissionServiceProvider.overrideWithValue(permissions),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(routerProvider);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Онбординг показан первым экраном.
      expect(find.text('Скажи — я запишу'), findsOneWidget);

      await tester.tap(find.text('Пропустить'));
      await tester.pump();
      await tester.tap(find.text('Начать пользоваться'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // После прохождения онбординга редирект ведёт на главную.
      expect(find.text('Совет дня'), findsOneWidget);
      expect(find.text('Сказать'), findsOneWidget);
      expect(store.settings.onboardingCompleted, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('показывает четыре слайда последовательно', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Скажи — я запишу'), findsOneWidget);
    expect(find.text('ИИ распределит по категориям'), findsNothing);

    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(find.text('ИИ распределит по категориям'), findsOneWidget);

    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(find.text('Следите за лимитами без таблиц'), findsOneWidget);

    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(find.text('Настройте Sona под себя'), findsOneWidget);
    expect(find.text('Продукты'), findsOneWidget);
    expect(find.text('Микрофон'), findsOneWidget);
    expect(find.text('Уведомления'), findsOneWidget);
  });

  testWidgets('«Пропустить» ведёт на слайд настройки', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Пропустить'));
    await tester.pumpAndSettle();

    expect(find.text('Настройте Sona под себя'), findsOneWidget);
  });

  testWidgets(
    'завершение онбординга сохраняет валюту, категории и разрешения',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Пропустить'));
      await tester.pumpAndSettle();

      expect(find.textContaining('USD'), findsOneWidget);
      await tester.tap(find.textContaining('USD'));

      await tester.scrollUntilVisible(find.text('Уведомления'), 300);
      await tester.pump();
      await tester.tap(find.text('Разрешить').first);
      await tester.pump();
      await tester.tap(find.text('Разрешить').last);
      await tester.pump();
      expect(permissions.microphoneRequests, 1);
      expect(permissions.notificationRequests, 1);

      await tester.tap(find.text('Начать пользоваться'));
      await tester.pumpAndSettle();

      expect(store.settings.onboardingCompleted, isTrue);
      expect(store.settings.currencyCode, 'USD');
      expect(store.settings.selectedCategories, contains('Продукты'));
    },
  );

  testWidgets(
    'снятая галочка категории исключает её из выбранных',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Пропустить'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Одежда'));
      await tester.pump();

      await tester.tap(find.text('Начать пользоваться'));
      await tester.pumpAndSettle();

      expect(store.settings.selectedCategories, isNot(contains('Одежда')));
      expect(store.settings.selectedCategories, contains('Продукты'));
    },
  );
}
