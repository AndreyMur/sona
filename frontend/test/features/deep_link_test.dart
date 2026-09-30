import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/app/providers.dart';
import 'package:sona/core/router/app_router.dart';
import 'package:sona/core/theme/app_theme.dart';
import 'package:sona/data/local/app_database.dart';

import '../support/fakes.dart';

void main() {
  group('deepLinkToLocation', () {
    test('sona://record ведёт на экран записи', () {
      expect(
        deepLinkToLocation(Uri.parse('sona://record')),
        AppRoutes.record,
      );
    });

    test('sona://app/record ведёт на экран записи', () {
      expect(
        deepLinkToLocation(Uri.parse('sona://app/record')),
        AppRoutes.record,
      );
    });

    test('параметр autostart сохраняется', () {
      expect(
        deepLinkToLocation(Uri.parse('sona://record?autostart=1')),
        '${AppRoutes.record}?autostart=1',
      );
    });

    test('чужие ссылки не преобразуются', () {
      expect(deepLinkToLocation(Uri.parse('https://example.com/record')), isNull);
      expect(deepLinkToLocation(Uri.parse('sona://categories')), isNull);
    });
  });

  group('deep link в приложении', () {
    late AppDatabase db;
    late FakeAudioRecorder recorder;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      recorder = FakeAudioRecorder();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('deep link с autostart: экран записи уже слушает', (tester) async {
      final router = buildRouter(
        onboardingCompleted: () => true,
        refreshListenable: ValueNotifier<bool?>(true),
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            appSettingsStoreProvider.overrideWithValue(
              FakeAppSettingsStore(),
            ),
            audioRecorderProvider.overrideWithValue(recorder),
            recordingFileStoreProvider.overrideWithValue(
              FakeRecordingFileStore(),
            ),
            speechRecognitionProvider.overrideWithValue(
              FakeSpeechRecognition(),
            ),
            textParsingProvider.overrideWithValue(FakeTextParsing()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Эквивалент открытия приложения по sona://record?autostart=1.
      router.go('${AppRoutes.record}?autostart=1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Слушаю…'), findsOneWidget);
      expect(recorder.started, isTrue);
      expect(recorder.permissionRequests, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('deep link без autostart: пульсирующий микрофон в ожидании', (tester) async {
      final router = buildRouter(
        onboardingCompleted: () => true,
        refreshListenable: ValueNotifier<bool?>(true),
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            appSettingsStoreProvider.overrideWithValue(
              FakeAppSettingsStore(),
            ),
            audioRecorderProvider.overrideWithValue(recorder),
            recordingFileStoreProvider.overrideWithValue(
              FakeRecordingFileStore(),
            ),
            speechRecognitionProvider.overrideWithValue(
              FakeSpeechRecognition(),
            ),
            textParsingProvider.overrideWithValue(FakeTextParsing()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      router.go(AppRoutes.record);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Скажите, что потратили'), findsOneWidget);
      expect(find.text('Сказать'), findsOneWidget);
      expect(recorder.started, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });
}
