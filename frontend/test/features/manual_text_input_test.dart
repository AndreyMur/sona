import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/app/providers.dart';
import 'package:sona/data/local/app_database.dart';
import 'package:sona/data/remote/api_exception.dart';
import 'package:sona/domain/models/operation.dart';
import 'package:sona/domain/models/recognition.dart';
import 'package:sona/domain/models/record_state.dart';
import 'package:sona/domain/models/shortcut.dart';
import 'package:sona/features/record/presentation/record_controller.dart';

import '../support/fakes.dart';

void main() {
  late AppDatabase db;
  late FakeTextParsing nlu;
  late FakeSpeechRecognition stt;
  late FakeConnectivityService connectivity;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    nlu = FakeTextParsing(result: twoExpensesResult());
    stt = FakeSpeechRecognition();
    connectivity = FakeConnectivityService();
    container = ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        audioRecorderProvider.overrideWithValue(FakeAudioRecorder()),
        recordingFileStoreProvider.overrideWithValue(FakeRecordingFileStore()),
        speechRecognitionProvider.overrideWithValue(stt),
        textParsingProvider.overrideWithValue(nlu),
        connectivityProvider.overrideWithValue(connectivity),
      ],
    );
  });

  tearDown(() async {
    connectivity.dispose();
    await db.close();
  });

  RecordState state() => container.read(recordControllerProvider);
  RecordController controller() =>
      container.read(recordControllerProvider.notifier);

  test('ручной текст разбирается через AI и сохраняется с источником text',
      () async {
    controller().startTextInput();
    expect(state().stage, RecordStage.textInput);

    await controller().submitText('продукты 2300 и такси 600');

    expect(state().stage, RecordStage.parsed);
    expect(state().transcript, 'продукты 2300 и такси 600');
    expect(state().source, OperationSource.text);
    expect(state().operations, hasLength(2));
    expect(nlu.calls, 1);

    await controller().confirm();

    expect(state().stage, RecordStage.saved);
    final saved = await db.recentOperations();
    expect(saved, hasLength(2));
    expect(saved.every((op) => op.source == OperationSource.text), isTrue);
  });

  test('пустой текст игнорируется', () async {
    controller().startTextInput();
    await controller().submitText('   ');

    expect(state().stage, RecordStage.textInput);
    expect(nlu.calls, 0);
  });

  test('без сети включается локальный разбор и бейдж «Офлайн-разбор»',
      () async {
    connectivity.online = false;
    nlu.error = const SonaApiException(
      kind: SonaErrorKind.network,
      message: 'Нет соединения.',
      code: 'network',
    );

    await controller().submitText('кофе 450');

    expect(state().stage, RecordStage.parsed);
    expect(state().offline, isTrue);
    expect(state().operations.single.category, 'Кафе и рестораны');
    expect(state().canRefineOnline, isFalse);

    connectivity.setOnline(true);
    await pumpEventQueue();

    expect(state().canRefineOnline, isTrue);
  });

  test('«Уточнить через AI» заменяет офлайн-разбор', () async {
    connectivity.online = false;
    nlu.error = const SonaApiException(
      kind: SonaErrorKind.network,
      message: 'Нет соединения.',
      code: 'network',
    );
    await controller().submitText('кофе 450');
    expect(state().offline, isTrue);

    nlu.error = null;
    nlu.result = ParseResult(
      operations: [
        ParsedOperation(
          type: OperationType.expense,
          amount: 450,
          category: 'Кафе и рестораны',
          subcategory: 'Ресторан',
          date: DateTime(2026, 9, 29),
          confidence: 0.97,
        ),
      ],
      overallConfidence: 0.97,
      model: 'google/gemini-3.8-flash',
    );

    await controller().refineWithAi();

    expect(state().offline, isFalse);
    expect(state().operations.single.subcategory, 'Ресторан');
    expect(state().operations.single.confidence, 0.97);
    expect(state().canRefineOnline, isFalse);
  });

  test('шорткат «Баланс» показывает доходы минус расходы', () async {
    await _seed(
      db,
      income: 100000,
      expense: 25000,
    );

    await controller().submitText('Баланс');

    expect(state().stage, RecordStage.shortcut);
    expect(state().shortcut!.value, '75 000 ₽');
    expect(nlu.calls, 0);
  });

  test('шорткат «Сколько на продукты» показывает траты по категории',
      () async {
    await _seed(db, expense: 1000, expenseCategory: 'Продукты');
    await _seed(db, expense: 500, expenseCategory: 'Транспорт');

    await controller().submitText('Сколько на продукты');

    expect(state().stage, RecordStage.shortcut);
    expect(state().shortcut!.category, 'Продукты');
    expect(state().shortcut!.value, '1 000 ₽');
  });

  test('шорткат «Отмена» не сохраняет операцию', () async {
    await controller().submitText('Отмена');

    expect(state().stage, RecordStage.shortcut);
    expect(state().shortcut!.kind, VoiceShortcutKind.cancel);
    expect(await db.countOperations(), 0);
  });

  test('шорткат распознаётся и в голосовой фразе', () async {
    stt.text = 'Баланс';

    await controller().startListening();
    await controller().stopAndProcess();

    expect(state().stage, RecordStage.shortcut);
    expect(state().shortcut!.kind, VoiceShortcutKind.balance);
  });
}

Future<void> _seed(
  AppDatabase db, {
  double income = 0,
  double expense = 0,
  String expenseCategory = 'Продукты',
}) async {
  final date = DateTime.now();
  final operations = <ParsedOperation>[
    if (income > 0)
      ParsedOperation(
        type: OperationType.income,
        amount: income,
        category: 'Доход',
        subcategory: 'Зарплата',
        date: date,
      ),
    if (expense > 0)
      ParsedOperation(
        type: OperationType.expense,
        amount: expense,
        category: expenseCategory,
        date: date,
      ),
  ];
  await db.insertParsedOperations(operations, source: OperationSource.voice);
}
