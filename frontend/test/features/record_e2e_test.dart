import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/app/providers.dart';
import 'package:sona/data/local/app_database.dart';
import 'package:sona/domain/models/record_state.dart';
import 'package:sona/features/record/presentation/record_controller.dart';

import '../support/fakes.dart';

void main() {
  test(
    'сквозной путь: одна фраза с двумя тратами → две операции за ≤ 3 сек',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final stt = FakeSpeechRecognition(text: 'продукты 2300 и такси 600')
        ..delay = const Duration(milliseconds: 800);
      final nlu = FakeTextParsing(result: twoExpensesResult())
        ..delay = const Duration(milliseconds: 900);

      final container = ProviderContainer.test(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          audioRecorderProvider.overrideWithValue(FakeAudioRecorder()),
          recordingFileStoreProvider.overrideWithValue(
            FakeRecordingFileStore(),
          ),
          speechRecognitionProvider.overrideWithValue(stt),
          textParsingProvider.overrideWithValue(nlu),
        ],
      );
      final controller = container.read(recordControllerProvider.notifier);

      final wall = Stopwatch()..start();
      await controller.startListening();
      await controller.stopAndProcess();
      await controller.confirm();
      wall.stop();

      final state = container.read(recordControllerProvider);
      expect(state.stage, RecordStage.saved);
      expect(state.savedCount, 2);
      expect(state.transcript, 'продукты 2300 и такси 600');

      expect(state.processingDuration, isNotNull);
      expect(
        state.processingDuration!,
        greaterThanOrEqualTo(const Duration(milliseconds: 1500)),
      );
      expect(
        state.processingDuration!,
        lessThanOrEqualTo(const Duration(seconds: 3)),
      );
      expect(wall.elapsed, lessThan(const Duration(seconds: 3)));

      final saved = await db.recentOperations();
      expect(saved, hasLength(2));
      expect(saved.map((op) => op.amount).toSet(), {2300.0, 600.0});
    },
  );
}
