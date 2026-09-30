import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/remote/api_exception.dart';
import '../../../domain/models/operation.dart';
import '../../../domain/models/record_state.dart';

/// Управляет сценарием «голос → сохранённая операция».
///
/// Состояния: Ожидание → Слушаю → Распознал → Разобрал → Сохранено.
class RecordController extends Notifier<RecordState> {
  Timer? _timer;
  final Stopwatch _recordingStopwatch = Stopwatch();
  final Stopwatch _processingStopwatch = Stopwatch();
  String? _audioPath;

  @override
  RecordState build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    return const RecordState();
  }

  /// Начинает запись: запрашивает микрофон и переводит экран в «Слушаю».
  Future<void> startListening() async {
    final recorder = ref.read(audioRecorderProvider);
    final fileStore = ref.read(recordingFileStoreProvider);

    final granted = await recorder.hasPermission();
    if (!granted) {
      state = state.copyWith(
        stage: RecordStage.error,
        errorMessage: 'Нет доступа к микрофону. Разрешите его в настройках.',
      );
      return;
    }

    final path = await fileStore.createRecordingPath();
    _audioPath = path;
    await recorder.start(path);

    _recordingStopwatch
      ..reset()
      ..start();
    _startTimer();
    state = const RecordState(stage: RecordStage.listening);
  }

  /// Останавливает запись, распознаёт речь и разбирает текст.
  Future<void> stopAndProcess() async {
    if (state.stage != RecordStage.listening) return;

    _stopTimer();
    _recordingStopwatch.stop();
    _processingStopwatch
      ..reset()
      ..start();

    final recorder = ref.read(audioRecorderProvider);
    final path = (await recorder.stop()) ?? _audioPath;

    state = state.copyWith(stage: RecordStage.recognized, isBusy: true);

    try {
      if (path == null) {
        throw const SonaApiException(
          kind: SonaErrorKind.unknown,
          message: 'Не удалось получить аудиофайл.',
          code: 'no_audio',
        );
      }

      final transcription = await ref
          .read(speechRecognitionProvider)
          .transcribe(path);
      final text = transcription.text.trim();
      if (text.isEmpty) {
        throw const SonaApiException(
          kind: SonaErrorKind.badRequest,
          message: 'Речь не распознана. Попробуйте ещё раз.',
          code: 'empty_transcript',
        );
      }
      state = state.copyWith(
        stage: RecordStage.recognized,
        transcript: text,
        isBusy: true,
      );

      final result = await ref.read(textParsingProvider).parse(text);
      _processingStopwatch.stop();

      if (result.isEmpty) {
        throw const SonaApiException(
          kind: SonaErrorKind.badRequest,
          message: 'Не удалось найти операцию во фразе.',
          code: 'no_operations',
        );
      }

      state = state.copyWith(
        stage: RecordStage.parsed,
        operations: result.operations,
        model: result.model,
        fallbackUsed: result.fallbackUsed,
        isBusy: false,
        processingDuration: _processingStopwatch.elapsed,
      );
    } on SonaApiException catch (error) {
      _processingStopwatch.stop();
      state = state.copyWith(
        stage: RecordStage.error,
        isBusy: false,
        errorMessage: error.message,
      );
    } catch (_) {
      _processingStopwatch.stop();
      state = state.copyWith(
        stage: RecordStage.error,
        isBusy: false,
        errorMessage: 'Что-то пошло не так. Попробуйте ещё раз.',
      );
    }
  }

  /// Сохраняет подтверждённые операции в локальную БД.
  Future<void> confirm() async {
    if (state.operations.isEmpty) return;
    state = state.copyWith(isBusy: true);

    try {
      final saved = await ref
          .read(operationRepositoryProvider)
          .saveAll(state.operations, source: OperationSource.voice);
      await _cleanupAudio();
      state = state.copyWith(
        stage: RecordStage.saved,
        isBusy: false,
        savedCount: saved.length,
      );
    } catch (_) {
      state = state.copyWith(
        stage: RecordStage.error,
        isBusy: false,
        errorMessage: 'Не удалось сохранить операцию.',
      );
    }
  }

  /// Меняет распознанную операцию до сохранения (кнопка «Изменить»).
  void updateOperation(int index, ParsedOperation operation) {
    if (index < 0 || index >= state.operations.length) return;
    final updated = [...state.operations]..[index] = operation;
    state = state.copyWith(operations: updated);
  }

  /// Удаляет одну операцию из списка до сохранения.
  void removeOperation(int index) {
    if (index < 0 || index >= state.operations.length) return;
    final updated = [...state.operations]..removeAt(index);
    if (updated.isEmpty) {
      state = state.copyWith(
        stage: RecordStage.error,
        errorMessage: 'Все операции удалены. Попробуйте снова.',
      );
      return;
    }
    state = state.copyWith(operations: updated);
  }

  /// Отменяет сценарий и возвращает экран в «Ожидание».
  Future<void> discard() async {
    _stopTimer();
    _recordingStopwatch.stop();
    final recorder = ref.read(audioRecorderProvider);
    await recorder.cancel();
    await _cleanupAudio();
    reset();
  }

  /// Возвращает экран в исходное состояние.
  void reset() {
    _stopTimer();
    _recordingStopwatch
      ..stop()
      ..reset();
    _processingStopwatch.reset();
    _audioPath = null;
    state = const RecordState();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      state = state.copyWith(elapsed: _recordingStopwatch.elapsed);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _cleanupAudio() async {
    final path = _audioPath;
    if (path == null) return;
    _audioPath = null;
    await ref.read(recordingFileStoreProvider).deleteIfExists(path);
  }
}

/// Провайдер контроллера экрана записи.
final recordControllerProvider = NotifierProvider<RecordController, RecordState>(
  RecordController.new,
);
