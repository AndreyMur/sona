import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/app/providers.dart';
import 'package:sona/core/theme/app_theme.dart';
import 'package:sona/data/local/app_database.dart';
import 'package:sona/data/remote/api_exception.dart';
import 'package:sona/features/record/presentation/record_screen.dart';

import '../support/fakes.dart';

void main() {
  late AppDatabase db;
  late FakeTextParsing nlu;
  late FakeConnectivityService connectivity;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    nlu = FakeTextParsing(result: twoExpensesResult());
    connectivity = FakeConnectivityService();
  });

  tearDown(() async {
    connectivity.dispose();
    await db.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          audioRecorderProvider.overrideWithValue(FakeAudioRecorder()),
          recordingFileStoreProvider.overrideWithValue(
            FakeRecordingFileStore(),
          ),
          speechRecognitionProvider.overrideWithValue(FakeSpeechRecognition()),
          textParsingProvider.overrideWithValue(nlu),
          connectivityProvider.overrideWithValue(connectivity),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RecordScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('ручной ввод: «Написать» → разбор → карточки операций',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Написать'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Напишите операцию'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'продукты 2300 и такси 600',
    );
    await tester.tap(find.text('Разобрать'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Разобрал'), findsOneWidget);
    expect(find.text('Подтвердить'), findsOneWidget);
    expect(find.text('Продукты · Супермаркет'), findsOneWidget);
  });

  testWidgets('офлайн-разбор показывает бейдж и кнопку «Уточнить через AI»',
      (tester) async {
    connectivity.online = false;
    nlu.error = const SonaApiException(
      kind: SonaErrorKind.network,
      message: 'Нет соединения.',
      code: 'network',
    );

    await pumpScreen(tester);
    await tester.tap(find.text('Написать'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField), 'кофе 450');
    await tester.tap(find.text('Разобрать'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Офлайн-разбор'), findsOneWidget);
    expect(find.text('Уточнить через AI'), findsNothing);

    connectivity.setOnline(true);
    await tester.pump();
    await tester.pump();

    expect(find.text('Уточнить через AI'), findsOneWidget);
  });

  testWidgets('шорткат «Баланс» показывает результат', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Написать'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField), 'Баланс');
    await tester.tap(find.text('Разобрать'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Баланс'), findsOneWidget);
    expect(find.text('Готово'), findsOneWidget);
  });
}
