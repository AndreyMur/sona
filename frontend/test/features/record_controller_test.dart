import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/app/providers.dart';
import 'package:sona/data/local/app_database.dart';
import 'package:sona/data/remote/api_exception.dart';
import 'package:sona/domain/models/record_state.dart';
import 'package:sona/domain/models/recognition.dart';
import 'package:sona/features/record/presentation/record_controller.dart';

import '../support/fakes.dart';

void main() {
  late AppDatabase db;
  late FakeAudioRecorder recorder;
  late FakeSpeechRecognition stt;
  late FakeTextParsing nlu;
  late ProviderContainer container;

  ProviderContainer build() {
    return ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        audioRecorderProvider.overrideWithValue(recorder),
        recordingFileStoreProvider.overrideWithValue(FakeRecordingFileStore()),
        speechRecognitionProvider.overrideWithValue(stt),
        textParsingProvider.overrideWithValue(nlu),
      ],
    );
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    recorder = FakeAudioRecorder();
    stt = FakeSpeechRecognition(text: 'продукты 2300 и такси 600');
    nlu = FakeTextParsing(result: twoExpensesResult());
    container = build();
  });

  tearDown(() async {
    await db.close();
  });

  RecordState state() => container.read(recordControllerProvider);
  RecordController controller() =>
      container.read(recordControllerProvider.notifier);

  test('полный путь: слушаю → распознал → разобрал → сохранено', () async {
    await controller().startListening();
    expect(state().stage, RecordStage.listening);
    expect(recorder.started, isTrue);
    expect(recorder.permissionRequests, 1);

    await controller().stopAndProcess();
    expect(state().stage, RecordStage.parsed);
    expect(state().transcript, 'продукты 2300 и такси 600');
    expect(state().operations, hasLength(2));
    expect(state().processingDuration, isNotNull);

    await controller().confirm();
    expect(state().stage, RecordStage.saved);
    expect(state().savedCount, 2);

    final saved = await db.recentOperations();
    expect(saved, hasLength(2));
    expect(
      saved.map((op) => op.amount).toSet(),
      {2300.0, 600.0},
    );
  });

  test('без разрешения на микрофон — ошибка', () async {
    recorder.permissionGranted = false;

    await controller().startListening();

    expect(state().stage, RecordStage.error);
    expect(state().errorMessage, contains('микрофон'));
    expect(recorder.started, isFalse);
  });

  test('пустой транскрипт — ошибка', () async {
    stt.text = '   ';

    await controller().startListening();
    await controller().stopAndProcess();

    expect(state().stage, RecordStage.error);
    expect(stt.calls, 1);
    expect(nlu.calls, 0);
  });

  test('ошибка STT показывается пользователю', () async {
    stt.error = const SonaApiException(
      kind: SonaErrorKind.network,
      message: 'Нет соединения. Проверьте интернет.',
      code: 'network',
    );

    await controller().startListening();
    await controller().stopAndProcess();

    expect(state().stage, RecordStage.error);
    expect(state().errorMessage, 'Нет соединения. Проверьте интернет.');
  });

  test('пустой разбор — ошибка «не удалось найти операцию»', () async {
    nlu.result = const ParseResult(
      operations: [],
      overallConfidence: 0,
      model: 'test/nlu',
    );

    await controller().startListening();
    await controller().stopAndProcess();

    expect(state().stage, RecordStage.error);
    expect(state().errorMessage, contains('операцию'));
  });

  test('операцию можно изменить и удалить до сохранения', () async {
    await controller().startListening();
    await controller().stopAndProcess();

    final first = state().operations.first;
    controller().updateOperation(0, first.copyWith(category: 'Еда'));
    expect(state().operations.first.category, 'Еда');

    controller().removeOperation(1);
    expect(state().operations, hasLength(1));

    controller().removeOperation(0);
    expect(state().stage, RecordStage.error);
  });

  test('отмена прерывает запись и сбрасывает состояние', () async {
    await controller().startListening();
    await controller().discard();

    expect(recorder.cancelled, isTrue);
    expect(state().stage, RecordStage.idle);
  });
}
