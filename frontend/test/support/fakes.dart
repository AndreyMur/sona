import 'dart:async';

import 'package:sona/domain/models/categorization_rule.dart';
import 'package:sona/domain/models/operation.dart';
import 'package:sona/domain/models/recognition.dart';
import 'package:sona/domain/repositories/categorization_repository.dart';
import 'package:sona/domain/services/audio_recorder.dart';
import 'package:sona/domain/services/connectivity_service.dart';
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

/// Поддельный репозиторий выученных правил категоризации.
class FakeCategorizationRepository implements CategorizationRepository {
  FakeCategorizationRepository([List<CategorizationRule>? initial]) {
    for (final rule in initial ?? const <CategorizationRule>[]) {
      _rules[rule.id] = rule;
      _nextId = rule.id + 1 > _nextId ? rule.id + 1 : _nextId;
    }
  }

  final Map<int, CategorizationRule> _rules = {};
  int _nextId = 1;
  final StreamController<List<CategorizationRule>> _controller =
      StreamController<List<CategorizationRule>>.broadcast();

  @override
  Future<List<CategorizationRule>> all() async => _rules.values.toList();

  @override
  Stream<List<CategorizationRule>> watchAll() => _controller.stream;

  @override
  Future<CategorizationRule> learn({
    required String keyword,
    required String category,
    String? subcategory,
  }) async {
    final existing = _rules.values.where((r) => r.keyword == keyword).toList();
    if (existing.isNotEmpty) {
      final old = existing.first;
      final updated = CategorizationRule(
        id: old.id,
        keyword: keyword,
        category: category,
        subcategory: subcategory,
        createdAt: old.createdAt,
      );
      _rules[old.id] = updated;
      _controller.add(_rules.values.toList());
      return updated;
    }
    final rule = CategorizationRule(
      id: _nextId++,
      keyword: keyword,
      category: category,
      subcategory: subcategory,
      createdAt: DateTime(2026, 9, 30),
    );
    _rules[rule.id] = rule;
    _controller.add(_rules.values.toList());
    return rule;
  }

  @override
  Future<void> delete(int id) async {
    _rules.remove(id);
    _controller.add(_rules.values.toList());
  }
}

/// Поддельное отслеживание сети.
class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({this.online = true});

  bool online;
  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  @override
  Future<bool> get isOnline async => online;

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  /// Меняет статус сети и уведомляет подписчиков.
  void setOnline(bool value) {
    online = value;
    _controller.add(value);
  }

  void dispose() => _controller.close();
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
