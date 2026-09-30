import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/app/providers.dart';
import 'package:sona/core/theme/app_theme.dart';
import 'package:sona/data/local/app_database.dart';
import 'package:sona/features/record/presentation/record_screen.dart';

import '../support/fakes.dart';

void main() {
  late AppDatabase db;
  late FakeAudioRecorder recorder;
  late FakeSpeechRecognition stt;
  late FakeTextParsing nlu;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    recorder = FakeAudioRecorder();
    stt = FakeSpeechRecognition(text: 'продукты 2300 и такси 600');
    nlu = FakeTextParsing(result: twoExpensesResult());
  });

  tearDown(() => db.close());

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          audioRecorderProvider.overrideWithValue(recorder),
          recordingFileStoreProvider.overrideWithValue(
            FakeRecordingFileStore(),
          ),
          speechRecognitionProvider.overrideWithValue(stt),
          textParsingProvider.overrideWithValue(nlu),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RecordScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('проходит состояния Ожидание → Слушаю → Разобрал → Сохранено', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Скажите, что потратили'), findsOneWidget);
    expect(find.text('Сказать'), findsOneWidget);

    await tester.tap(find.text('Сказать'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Слушаю…'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.stop_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Разобрал'), findsOneWidget);
    expect(find.text('Продукты · Супермаркет'), findsOneWidget);
    expect(find.text('Транспорт · Такси'), findsOneWidget);

    await tester.tap(find.text('Подтвердить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Сохранено'), findsOneWidget);
    expect(find.text('2 операции записано'), findsOneWidget);
  });

  testWidgets('без разрешения на микрофон показывает ошибку', (tester) async {
    recorder.permissionGranted = false;
    await pumpScreen(tester);

    await tester.tap(find.text('Сказать'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Не получилось'), findsOneWidget);
    expect(find.textContaining('микрофон'), findsOneWidget);
  });

  testWidgets('отмена возвращает экран в Ожидание', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Сказать'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Слушаю…'), findsOneWidget);

    await tester.tap(find.text('Отменить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Скажите, что потратили'), findsOneWidget);
    expect(recorder.cancelled, isTrue);
  });
}
