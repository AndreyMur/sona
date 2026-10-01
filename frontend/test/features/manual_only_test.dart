import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/app/providers.dart';
import 'package:sona/data/local/app_database.dart';
import 'package:sona/domain/models/app_settings.dart';
import 'package:sona/domain/models/record_state.dart';
import 'package:sona/features/record/presentation/record_controller.dart';

import '../support/fakes.dart';

void main() {
  late AppDatabase db;
  late FakeAudioRecorder recorder;
  late FakeTextParsing cloud;
  late FakeTextParsing local;
  late ProviderContainer container;

  ProviderContainer build() {
    return ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        audioRecorderProvider.overrideWithValue(recorder),
        recordingFileStoreProvider.overrideWithValue(FakeRecordingFileStore()),
        textParsingProvider.overrideWithValue(cloud),
        localTextParserProvider.overrideWithValue(local),
        appSettingsStoreProvider.overrideWithValue(
          FakeAppSettingsStore(const AppSettings(manualOnlyMode: true)),
        ),
      ],
    );
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    recorder = FakeAudioRecorder();
    cloud = FakeTextParsing(result: twoExpensesResult());
    local = FakeTextParsing(result: twoExpensesResult());
    container = build();
    await container.read(appSettingsProvider.future);
  });

  tearDown(() async {
    await db.close();
  });

  RecordState state() => container.read(recordControllerProvider);
  RecordController controller() =>
      container.read(recordControllerProvider.notifier);

  test('голосовой ввод запрещён и объясняет причину', () async {
    await controller().startListening();

    expect(state().stage, RecordStage.error);
    expect(state().errorMessage, contains('Только ручной ввод'));
    expect(recorder.started, isFalse);
    expect(recorder.permissionRequests, 0);
  });

  test('текст разбирается локально, облако не вызывается', () async {
    await controller().submitText('продукты 2300 и такси 600');

    expect(state().stage, RecordStage.parsed);
    expect(state().localOnly, isTrue);
    expect(state().operations, hasLength(2));
    expect(local.calls, 1);
    expect(cloud.calls, 0);
    expect(state().canRefineOnline, isFalse);
  });

  test('локально разобранные операции сохраняются', () async {
    await controller().submitText('продукты 2300 и такси 600');
    await controller().confirm();

    expect(state().stage, RecordStage.saved);
    expect(await db.recentOperations(), hasLength(2));
  });
}
