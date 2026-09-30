import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/app/providers.dart';
import 'package:sona/core/theme/app_theme.dart';
import 'package:sona/features/onboarding/presentation/onboarding_screen.dart';

import '../support/fakes.dart';

void main() {
  late FakeAppSettingsStore store;
  late FakePermissionService permissions;

  setUp(() {
    store = FakeAppSettingsStore();
    permissions = FakePermissionService();
  });

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
