import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/remote/api_exception.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/operation.dart';
import '../../../domain/models/record_state.dart';
import '../../../domain/models/shortcut.dart';
import '../../../domain/services/categorization_rule_matcher.dart';
import '../../../domain/services/shortcut_matcher.dart';

/// Управляет сценарием «голос/текст → сохранённая операция».
///
/// Состояния: Ожидание → Слушаю → Распознал → Разобрал → Сохранено.
/// Без сети разбор выполняет локальный парсер, результат помечается
/// признаком [RecordState.offline].
class RecordController extends Notifier<RecordState> {
  Timer? _timer;
  StreamSubscription<bool>? _connectivitySub;
  final Stopwatch _recordingStopwatch = Stopwatch();
  final Stopwatch _processingStopwatch = Stopwatch();
  String? _audioPath;

  @override
  RecordState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _connectivitySub?.cancel();
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

      await _processText(text, OperationSource.voice);
    } on SonaApiException catch (error) {
      _processingStopwatch.stop();
      state = state.copyWith(
        stage: RecordStage.error,
        isBusy: false,
        errorMessage: error.kind == SonaErrorKind.network
            ? 'Нет соединения. Введите операцию текстом.'
            : error.message,
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

  /// Переводит экран в режим ручного текстового ввода.
  void startTextInput() {
    state = const RecordState(stage: RecordStage.textInput);
  }

  /// Отменяет ручной ввод и возвращает экран в «Ожидание».
  void cancelTextInput() => reset();

  /// Разбирает введённый текст так же, как голосовую фразу.
  Future<void> submitText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _processingStopwatch
      ..reset()
      ..start();
    await _processText(trimmed, OperationSource.text);
  }

  /// Повторный AI-разбор офлайн-операции после восстановления сети.
  Future<void> refineWithAi() async {
    final text = state.transcript;
    if (text == null || !state.offline || state.isBusy) return;

    state = state.copyWith(isBusy: true, refineError: null);
    try {
      final result = await ref.read(textParsingProvider).parse(text);
      if (result.isEmpty) {
        state = state.copyWith(
          isBusy: false,
          refineError: 'AI не нашёл операцию во фразе.',
        );
        return;
      }
      state = state.copyWith(
        stage: RecordStage.parsed,
        operations: result.operations,
        model: result.model,
        fallbackUsed: result.fallbackUsed,
        offline: false,
        canRefineOnline: false,
        refineError: null,
        isBusy: false,
      );
      _connectivitySub?.cancel();
      _connectivitySub = null;
    } on SonaApiException catch (error) {
      state = state.copyWith(isBusy: false, refineError: error.message);
    } catch (_) {
      state = state.copyWith(
        isBusy: false,
        refineError: 'Не удалось уточнить через AI.',
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
          .saveAll(state.operations, source: state.source);
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
  ///
  /// Если пользователь поправил категорию или подкатегорию — запоминает
  /// правило «ключевое слово фразы → новая категория»: приложение обучается
  /// на правках и в следующий раз категоризирует само.
  void updateOperation(int index, ParsedOperation operation) {
    if (index < 0 || index >= state.operations.length) return;
    final previous = state.operations[index];
    final updated = [...state.operations]..[index] = operation;
    state = state.copyWith(operations: updated);
    unawaited(_learnFromCorrection(previous, operation));
  }

  /// Обучение категоризации — best effort: сбой не влияет на основной
  /// сценарий записи, ошибки поглощаются.
  Future<void> _learnFromCorrection(
    ParsedOperation before,
    ParsedOperation after,
  ) async {
    if (before.category == after.category &&
        before.subcategory == after.subcategory) {
      return;
    }
    final transcript = state.transcript;
    if (transcript == null || transcript.trim().isEmpty) return;
    final keyword = CategorizationRuleMatcher.candidateKeyword(transcript);
    if (keyword == null) return;
    try {
      await ref.read(categorizationRepositoryProvider).learn(
        keyword: keyword,
        category: after.category,
        subcategory: after.subcategory,
      );
    } catch (_) {
      // Обучение не критично: игнорируем сбои записи правила.
    }
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
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _audioPath = null;
    state = const RecordState();
  }

  Future<void> _processText(String text, OperationSource source) async {
    state = state.copyWith(
      stage: RecordStage.recognized,
      transcript: text,
      isBusy: true,
      source: source,
      operations: const [],
      offline: false,
      canRefineOnline: false,
      refineError: null,
      shortcut: null,
    );

    final shortcut = ShortcutMatcher.match(text);
    if (shortcut != null) {
      await _runShortcut(shortcut);
      return;
    }

    try {
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
      if (error.kind == SonaErrorKind.network) {
        await _parseOffline(text);
      } else {
        _processingStopwatch.stop();
        state = state.copyWith(
          stage: RecordStage.error,
          isBusy: false,
          errorMessage: error.message,
        );
      }
    } catch (_) {
      _processingStopwatch.stop();
      state = state.copyWith(
        stage: RecordStage.error,
        isBusy: false,
        errorMessage: 'Что-то пошло не так. Попробуйте ещё раз.',
      );
    }
  }

  Future<void> _parseOffline(String text) async {
    final result = await ref.read(localTextParserProvider).parse(text);
    _processingStopwatch.stop();

    if (result.isEmpty) {
      state = state.copyWith(
        stage: RecordStage.error,
        isBusy: false,
        errorMessage: 'Не удалось найти операцию во фразе.',
      );
      return;
    }

    state = state.copyWith(
      stage: RecordStage.parsed,
      operations: result.operations,
      model: result.model,
      fallbackUsed: true,
      offline: true,
      isBusy: false,
      processingDuration: _processingStopwatch.elapsed,
    );
    await _watchConnectivity();
  }

  Future<void> _runShortcut(VoiceShortcutMatch match) async {
    _processingStopwatch.stop();
    final repository = ref.read(operationRepositoryProvider);

    switch (match.kind) {
      case VoiceShortcutKind.cancel:
        await _cleanupAudio();
        state = state.copyWith(
          stage: RecordStage.shortcut,
          isBusy: false,
          shortcut: const ShortcutResult(
            kind: VoiceShortcutKind.cancel,
            title: 'Операция отменена',
            value: 'Ничего не сохранено',
            subtitle: 'Запись можно начать заново',
          ),
        );
      case VoiceShortcutKind.balance:
        final income = await repository.totalByType(OperationType.income);
        final expense = await repository.totalByType(OperationType.expense);
        state = state.copyWith(
          stage: RecordStage.shortcut,
          isBusy: false,
          shortcut: ShortcutResult(
            kind: VoiceShortcutKind.balance,
            title: 'Баланс',
            value: SonaFormat.amount(income - expense),
            subtitle:
                'Доходы ${SonaFormat.amount(income)} · '
                'Расходы ${SonaFormat.amount(expense)}',
          ),
        );
      case VoiceShortcutKind.category:
        final category = match.category ?? kFallbackCategory;
        final (from, to) = _currentMonthRange();
        final spent = await repository.totalByCategory(
          category,
          from: from,
          to: to,
        );
        state = state.copyWith(
          stage: RecordStage.shortcut,
          isBusy: false,
          shortcut: ShortcutResult(
            kind: VoiceShortcutKind.category,
            title: category,
            value: SonaFormat.amount(spent),
            subtitle: 'Потрачено в этом месяце',
            category: category,
          ),
        );
    }
  }

  Future<void> _watchConnectivity() async {
    final connectivity = ref.read(connectivityProvider);
    _connectivitySub?.cancel();
    _connectivitySub = connectivity.onStatusChange.listen((online) {
      if (online && state.offline && !state.canRefineOnline) {
        state = state.copyWith(canRefineOnline: true);
      }
    });
    try {
      if (await connectivity.isOnline && state.offline) {
        state = state.copyWith(canRefineOnline: true);
      }
    } catch (_) {
      // Игнорируем сбои опроса сети.
    }
  }

  (DateTime, DateTime) _currentMonthRange() {
    final now = DateTime.now();
    return (DateTime(now.year, now.month), DateTime(now.year, now.month + 1));
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
