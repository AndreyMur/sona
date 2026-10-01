import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sona/app/providers.dart';
import 'package:sona/core/router/app_router.dart';
import 'package:sona/core/theme/app_theme.dart';
import 'package:sona/data/local/app_database.dart';
import 'package:sona/data/remote/api_exception.dart';
import 'package:sona/domain/models/app_settings.dart';
import 'package:sona/domain/models/category.dart';
import 'package:sona/domain/models/operation.dart';
import 'package:sona/domain/models/record_state.dart';
import 'package:sona/domain/models/subscription.dart';
import 'package:sona/features/record/presentation/record_controller.dart';

import '../support/fakes.dart';

void main() {
  late AppDatabase db;
  late FakeAudioRecorder recorder;
  late FakeSpeechRecognition stt;
  late FakeTextParsing nlu;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.seedCategories(kDefaultCategories);
    recorder = FakeAudioRecorder();
    stt = FakeSpeechRecognition(text: 'продукты 2300 и такси 600');
    nlu = FakeTextParsing(result: twoExpensesResult());
  });

  tearDown(() async {
    await db.close();
  });

  ProviderContainer build({
    SubscriptionState subscription = const SubscriptionState(),
    AppSettings settings = const AppSettings(),
  }) {
    return ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        audioRecorderProvider.overrideWithValue(recorder),
        recordingFileStoreProvider.overrideWithValue(FakeRecordingFileStore()),
        speechRecognitionProvider.overrideWithValue(stt),
        textParsingProvider.overrideWithValue(nlu),
        appSettingsStoreProvider.overrideWithValue(FakeAppSettingsStore(settings)),
        subscriptionStoreProvider.overrideWithValue(
          FakeSubscriptionStore(subscription),
        ),
      ],
    );
  }

  RecordState state(ProviderContainer c) => c.read(recordControllerProvider);
  RecordController controller(ProviderContainer c) =>
      c.read(recordControllerProvider.notifier);

  test('прокси сообщает об исчерпании лимита 30 операций — предлагаем Pro', () async {
    nlu.error = const SonaApiException(
      kind: SonaErrorKind.quotaExceeded,
      message: 'Лимит бесплатных операций исчерпан. Оформите Sona Pro.',
      code: 'free_limit_reached',
      statusCode: 402,
    );
    final container = build();
    await container.read(subscriptionProvider.future);
    await container.read(appSettingsProvider.future);

    await controller(container).startListening();
    await controller(container).stopAndProcess();

    expect(state(container).stage, RecordStage.error);
    expect(state(container).quotaExceeded, isTrue);
    expect(state(container).errorMessage, contains('Sona Pro'));
  });

  test('бесплатный тариф распознаёт со стандартным качеством', () async {
    final container = build();
    await container.read(subscriptionProvider.future);
    await container.read(appSettingsProvider.future);

    await controller(container).startListening();
    await controller(container).stopAndProcess();

    expect(stt.lastQuality, 'standard');
  });

  test('Pro с качеством «Максимум» передаёт max в распознавание', () async {
    final container = build(
      subscription: proSubscription(),
      settings: const AppSettings(recognitionQuality: RecognitionQuality.max),
    );
    await container.read(subscriptionProvider.future);
    await container.read(appSettingsProvider.future);

    await controller(container).startListening();
    await controller(container).stopAndProcess();

    expect(stt.lastQuality, 'max');
  });

  group('главная', () {
    late GoRouter router;

    setUp(() {
      router = buildRouter(
        onboardingCompleted: () => true,
        refreshListenable: ValueNotifier<bool?>(true),
      );
      addTearDown(router.dispose);
    });

    Future<void> pumpHome(
      WidgetTester tester, {
      required SubscriptionState subscription,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            appSettingsStoreProvider.overrideWithValue(FakeAppSettingsStore()),
            subscriptionStoreProvider.overrideWithValue(
              FakeSubscriptionStore(subscription),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('показывает остаток бесплатных операций', (tester) async {
      await db.insertParsedOperations([
        ParsedOperation(
          type: OperationType.expense,
          amount: 100,
          category: 'Продукты',
          date: DateTime.now(),
        ),
        ParsedOperation(
          type: OperationType.expense,
          amount: 200,
          category: 'Продукты',
          date: DateTime.now(),
        ),
      ], source: OperationSource.manual);

      await pumpHome(tester, subscription: const SubscriptionState());

      expect(find.text('Бесплатный тариф'), findsOneWidget);
      expect(find.text('Осталось 28 из 30 операций'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('на Pro карточка лимита скрыта', (tester) async {
      await pumpHome(tester, subscription: proSubscription());

      expect(find.text('Бесплатный тариф'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });
}
