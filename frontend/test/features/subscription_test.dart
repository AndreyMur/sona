import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/app/providers.dart';
import 'package:sona/core/theme/app_theme.dart';
import 'package:sona/domain/models/subscription.dart';
import 'package:sona/domain/services/purchase_service.dart';
import 'package:sona/features/subscription/presentation/subscription_screen.dart';

import '../support/fakes.dart';

void main() {
  late FakeSubscriptionStore store;
  late FakePurchaseService purchase;
  late FakeSubscriptionGateway gateway;

  void initFakes({SubscriptionState? initial}) {
    store = FakeSubscriptionStore(initial);
    purchase = FakePurchaseService();
    gateway = FakeSubscriptionGateway();
  }

  ProviderContainer build({SubscriptionState? initial}) {
    initFakes(initial: initial);
    return ProviderContainer.test(
      overrides: [
        subscriptionStoreProvider.overrideWithValue(store),
        purchaseServiceProvider.overrideWithValue(purchase),
        subscriptionGatewayProvider.overrideWithValue(gateway),
        appSettingsStoreProvider.overrideWithValue(FakeAppSettingsStore()),
      ],
    );
  }

  test('оформление подписки активирует Pro и синхронизирует тариф', () async {
    final container = build();
    expect((await container.read(subscriptionProvider.future)).isPro, isFalse);

    purchase.buyResult = const PurchaseResult(
      outcome: PurchaseOutcome.success,
      plan: SubscriptionPlan.annual,
      purchaseToken: 'tok-annual',
    );
    final result = await container
        .read(subscriptionProvider.notifier)
        .purchase(SubscriptionPlan.annual);

    expect(result.isSuccess, isTrue);
    final state = container.read(subscriptionProvider).value!;
    expect(state.isPro, isTrue);
    expect(state.plan, SubscriptionPlan.annual);
    expect(container.read(isProProvider), isTrue);
    expect(store.state.isPro, isTrue);
    expect(gateway.activations.single.plan, SubscriptionPlan.annual);
  });

  test('отмена покупки не активирует Pro', () async {
    final container = build();
    purchase.buyResult = PurchaseResult.canceled;

    final result = await container
        .read(subscriptionProvider.notifier)
        .purchase(SubscriptionPlan.monthly);

    expect(result.outcome, PurchaseOutcome.canceled);
    expect(container.read(isProProvider), isFalse);
    expect(gateway.activations, isEmpty);
  });

  test('восстановление покупок включает Pro', () async {
    final container = build();
    purchase.restoreResult = const PurchaseResult(
      outcome: PurchaseOutcome.restored,
      plan: SubscriptionPlan.monthly,
      purchaseToken: 'restored-token',
    );

    final result = await container.read(subscriptionProvider.notifier).restore();

    expect(result.outcome, PurchaseOutcome.restored);
    expect(container.read(isProProvider), isTrue);
    expect(purchase.restores, 1);
    expect(gateway.activations.single.purchaseToken, 'restored-token');
  });

  test('пробный период длится 7 дней и не повторяется', () async {
    final container = build();
    await container.read(subscriptionProvider.future);

    final started = await container
        .read(subscriptionProvider.notifier)
        .startTrial();
    expect(started, isTrue);

    final now = DateTime.now();
    final state = container.read(subscriptionProvider).value!;
    expect(state.isPro, isTrue);
    expect(state.trial, isTrue);
    expect(state.isTrialAt(now), isTrue);
    expect(state.trialDaysLeft(now), kProTrialDays);
    expect(state.trialUsed, isTrue);
    expect(gateway.activations.single.trial, isTrue);

    await container.read(subscriptionProvider.notifier).cancel();
    expect(container.read(isProProvider), isFalse);

    final second = await container
        .read(subscriptionProvider.notifier)
        .startTrial();
    expect(second, isFalse);
  });

  test('истёкшая подписка снимается при загрузке', () async {
    final expired = SubscriptionState(
      tier: SubscriptionTier.pro,
      plan: SubscriptionPlan.monthly,
      trialUsed: true,
      expiresAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    final container = build(initial: expired);

    final state = await container.read(subscriptionProvider.future);

    expect(state.isPro, isFalse);
    expect(state.tier, SubscriptionTier.free);
  });

  test('качество «Максимум» доступно только Pro', () async {
    final container = build();
    await container.read(subscriptionProvider.future);
    await container.read(appSettingsProvider.future);
    await container
        .read(appSettingsProvider.notifier)
        .setRecognitionQuality(RecognitionQuality.max);

    // Бесплатный тариф: эффективное качество — «Стандарт».
    expect(
      container.read(recognitionQualityProvider),
      RecognitionQuality.standard,
    );

    await container.read(subscriptionProvider.notifier).startTrial();
    expect(container.read(recognitionQualityProvider), RecognitionQuality.max);

    await container
        .read(appSettingsProvider.notifier)
        .setRecognitionQuality(RecognitionQuality.standard);
    expect(
      container.read(recognitionQualityProvider),
      RecognitionQuality.standard,
    );
  });

  test('сбой синхронизации с прокси не отменяет локальный Pro', () async {
    final container = build();
    await container.read(subscriptionProvider.future);
    gateway.fail = true;

    await container.read(subscriptionProvider.notifier).startTrial();

    expect(container.read(isProProvider), isTrue);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    initFakes();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionStoreProvider.overrideWithValue(store),
          purchaseServiceProvider.overrideWithValue(purchase),
          subscriptionGatewayProvider.overrideWithValue(gateway),
          appSettingsStoreProvider.overrideWithValue(FakeAppSettingsStore()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SubscriptionScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('экран подписки показывает планы и пробный период', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Sona Pro'), findsWidgets);
    expect(find.text('349 ₽/мес'), findsOneWidget);
    expect(find.text('2 490 ₽/год'), findsOneWidget);
    expect(find.text('Попробовать 7 дней бесплатно'), findsOneWidget);
  });

  testWidgets('запуск пробного периода открывает Pro на экране', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Попробовать 7 дней бесплатно'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Пробный период'), findsWidgets);
    expect(find.text('Отменить подписку'), findsOneWidget);
  });
}
