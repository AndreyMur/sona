import 'package:sona/domain/models/operation.dart';
import 'package:sona/domain/models/recognition.dart';
import 'package:sona/domain/services/audio_recorder.dart';
import 'package:sona/domain/services/recognition_service.dart';
import 'package:sona/domain/services/recording_file_store.dart';

/// Поддельная запись аудио: не обращается к микрофону.
class FakeAudioRecorder implements AudioRecorderPort {
  FakeAudioRecorder({
    this.permissionGranted = true,
    this.outputPath = 'C:/tmp/sona_test.m4a',
  });

  bool permissionGranted;
  String outputPath;
  String? startedPath;
  bool started = false;
  bool stopped = false;
  bool cancelled = false;
  int permissionRequests = 0;

  @override
  Future<bool> hasPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> start(String path) async {
    started = true;
    startedPath = path;
  }

  @override
  Future<String?> stop() async {
    stopped = true;
    return outputPath;
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
  }

  @override
  Future<void> dispose() async {}
}

/// Поддельное файловое хранилище записей.
class FakeRecordingFileStore implements RecordingFileStore {
  FakeRecordingFileStore({this.path = 'C:/tmp/sona_test.m4a'});

  final String path;
  final List<String> deleted = [];

  @override
  Future<String> createRecordingPath() async => path;

  @override
  Future<void> deleteIfExists(String path) async {
    deleted.add(path);
  }
}

/// Поддельное распознавание речи.
class FakeSpeechRecognition implements SpeechRecognitionService {
  FakeSpeechRecognition({this.text = 'такси 400', this.error});

  String text;
  Object? error;
  Duration delay = Duration.zero;
  int calls = 0;

  @override
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    String quality = 'standard',
    String language = 'ru',
  }) async {
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (error != null) throw error!;
    return TranscriptionResult(text: text, model: 'test/stt');
  }
}

/// Поддельный разбор текста в операции.
class FakeTextParsing implements TextParsingService {
  FakeTextParsing({this.result, this.byText, this.error});

  ParseResult? result;
  Map<String, ParseResult>? byText;
  Object? error;
  Duration delay = Duration.zero;
  int calls = 0;

  @override
  Future<ParseResult> parse(String text) async {
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (error != null) throw error!;
    final value = byText?[text] ?? result;
    if (value == null) {
      throw StateError('FakeTextParsing: нет результата для "$text"');
    }
    return value;
  }
}

/// Готовый результат разбора с двумя тратами.
ParseResult twoExpensesResult() {
  final date = DateTime(2026, 9, 29);
  return ParseResult(
    operations: [
      ParsedOperation(
        type: OperationType.expense,
        amount: 2300,
        category: 'Продукты',
        subcategory: 'Супермаркет',
        date: date,
        confidence: 0.95,
      ),
      ParsedOperation(
        type: OperationType.expense,
        amount: 600,
        category: 'Транспорт',
        subcategory: 'Такси',
        date: date,
        confidence: 0.92,
      ),
    ],
    overallConfidence: 0.94,
    model: 'google/gemini-3.8-flash',
    promptVersion: '1.0.0',
  );
}
