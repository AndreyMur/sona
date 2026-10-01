import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/app/providers.dart';
import 'package:sona/core/theme/app_theme.dart';
import 'package:sona/core/utils/pin_hasher.dart';
import 'package:sona/domain/models/app_settings.dart';
import 'package:sona/features/security/presentation/app_lock_controller.dart';
import 'package:sona/features/security/presentation/app_lock_gate.dart';

import '../support/fakes.dart';

void main() {
  group('AppLockController', () {
    late FakeAppSettingsStore store;
    late FakeBiometricService biometric;

    ProviderContainer build(AppSettings settings) {
      store = FakeAppSettingsStore(settings);
      biometric = FakeBiometricService();
      return ProviderContainer.test(
        overrides: [
          appSettingsStoreProvider.overrideWithValue(store),
          biometricServiceProvider.overrideWithValue(biometric),
        ],
      );
    }

    test('по умолчанию защита выключена и приложение не заперто', () async {
      final container = build(const AppSettings());
      addTearDown(container.dispose);
      await container.read(appSettingsProvider.future);

      final state = container.read(appLockProvider);
      expect(state.enabled, isFalse);
      expect(state.locked, isFalse);
    });

    test('включение с PIN запирает приложение и сохраняет хеш', () async {
      final container = build(const AppSettings());
      addTearDown(container.dispose);
      await container.read(appSettingsProvider.future);

      final ok = await container
          .read(appLockProvider.notifier)
          .enableWithPin('1234');

      expect(ok, isTrue);
      expect(container.read(appLockProvider).enabled, isTrue);
      expect(container.read(appLockProvider).locked, isTrue);
      expect(store.settings.appLockEnabled, isTrue);
      expect(store.settings.pinHash, PinHasher.hash('1234'));
    });

    test('неверный PIN не разблокирует, верный — разблокирует', () async {
      final container = build(
        AppSettings(
          appLockEnabled: true,
          pinHash: PinHasher.hash('1234'),
        ),
      );
      addTearDown(container.dispose);
      await container.read(appSettingsProvider.future);
      expect(container.read(appLockProvider).locked, isTrue);

      final wrong = await container
          .read(appLockProvider.notifier)
          .unlockWithPin('0000');
      expect(wrong, isFalse);
      expect(container.read(appLockProvider).locked, isTrue);
      expect(container.read(appLockProvider).error, 'Неверный PIN');

      final right = await container
          .read(appLockProvider.notifier)
          .unlockWithPin('1234');
      expect(right, isTrue);
      expect(container.read(appLockProvider).locked, isFalse);
    });

    test('биометрия разблокирует только при подтверждении', () async {
      final container = build(
        AppSettings(
          appLockEnabled: true,
          biometricEnabled: true,
          pinHash: PinHasher.hash('1234'),
        ),
      );
      addTearDown(container.dispose);
      await container.read(appSettingsProvider.future);

      biometric.grant = false;
      expect(
        await container.read(appLockProvider.notifier).unlockWithBiometrics(),
        isFalse,
      );
      expect(container.read(appLockProvider).locked, isTrue);

      biometric.grant = true;
      expect(
        await container.read(appLockProvider.notifier).unlockWithBiometrics(),
        isTrue,
      );
      expect(container.read(appLockProvider).locked, isFalse);
    });

    test('недоступную биометрию нельзя включить', () async {
      final container = build(
        AppSettings(appLockEnabled: true, pinHash: PinHasher.hash('1234')),
      );
      addTearDown(container.dispose);
      await container.read(appSettingsProvider.future);

      biometric.available = false;
      final enabled =
          await container.read(appLockProvider.notifier).setBiometric(true);

      expect(enabled, isFalse);
      expect(container.read(appLockProvider).biometricEnabled, isFalse);
      expect(container.read(appLockProvider).error, contains('недоступна'));
    });

    test('смена несвязанных настроек не запирает приложение повторно', () async {
      final container = build(
        AppSettings(
          appLockEnabled: true,
          pinHash: PinHasher.hash('1234'),
        ),
      );
      addTearDown(container.dispose);
      await container.read(appSettingsProvider.future);

      await container.read(appLockProvider.notifier).unlockWithPin('1234');
      expect(container.read(appLockProvider).locked, isFalse);

      await container.read(appSettingsProvider.notifier).setCurrency('€');
      expect(container.read(appLockProvider).locked, isFalse);
    });

    test('выключение защиты очищает PIN и биометрию', () async {
      final container = build(
        AppSettings(
          appLockEnabled: true,
          biometricEnabled: true,
          pinHash: PinHasher.hash('1234'),
        ),
      );
      addTearDown(container.dispose);
      await container.read(appSettingsProvider.future);

      await container.read(appLockProvider.notifier).disable();

      expect(store.settings.appLockEnabled, isFalse);
      expect(store.settings.pinHash, isNull);
      expect(store.settings.biometricEnabled, isFalse);
      expect(container.read(appLockProvider).locked, isFalse);
    });
  });

  group('AppLockGate', () {
    Future<void> pumpGate(
      WidgetTester tester,
      AppSettings settings, {
      FakeBiometricService? biometric,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsStoreProvider.overrideWithValue(
              FakeAppSettingsStore(settings),
            ),
            biometricServiceProvider.overrideWithValue(
              biometric ?? FakeBiometricService(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const AppLockGate(
              child: Scaffold(body: Text('КОНТЕНТ')),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('при включённой защите показывает экран блокировки', (
      tester,
    ) async {
      await pumpGate(
        tester,
        AppSettings(
          appLockEnabled: true,
          pinHash: PinHasher.hash('1234'),
        ),
      );

      expect(find.text('Введите PIN'), findsOneWidget);
      expect(find.text('КОНТЕНТ'), findsOneWidget);
    });

    testWidgets('верный PIN снимает блокировку', (tester) async {
      await pumpGate(
        tester,
        AppSettings(
          appLockEnabled: true,
          pinHash: PinHasher.hash('1234'),
        ),
      );

      for (final digit in ['1', '2', '3', '4']) {
        await tester.tap(find.text(digit));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Введите PIN'), findsNothing);
    });

    testWidgets('автоблокировка «сразу» запирает при возврате из фона', (
      tester,
    ) async {
      await pumpGate(
        tester,
        AppSettings(
          appLockEnabled: true,
          pinHash: PinHasher.hash('1234'),
          autoLockSeconds: 0,
        ),
      );

      for (final digit in ['1', '2', '3', '4']) {
        await tester.tap(find.text(digit));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Введите PIN'), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Введите PIN'), findsOneWidget);
    });

    testWidgets('короткий уход в фон при задержке не запирает', (tester) async {
      await pumpGate(
        tester,
        AppSettings(
          appLockEnabled: true,
          pinHash: PinHasher.hash('1234'),
          autoLockSeconds: 300,
        ),
      );

      for (final digit in ['1', '2', '3', '4']) {
        await tester.tap(find.text(digit));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 100));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Введите PIN'), findsNothing);
    });
  });
}
