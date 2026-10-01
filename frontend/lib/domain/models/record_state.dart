import 'package:flutter/foundation.dart';

import 'operation.dart';
import 'shortcut.dart';

/// Состояния экрана записи (ТЗ, раздел 6.3).
enum RecordStage {
  /// Ожидание — пульсирующий микрофон.
  idle,

  /// Ручной текстовый ввод.
  textInput,

  /// Слушаю — идёт запись.
  listening,

  /// Распознал — получен текст транскрипта.
  recognized,

  /// Разобрал — готовы карточки операций.
  parsed,

  /// Шорткат — показан результат «Баланс» / «Сколько на …» / «Отмена».
  shortcut,

  /// Сохранено — операции записаны в БД.
  saved,

  /// Ошибка на любом из этапов.
  error,
}

/// Неизменяемое состояние экрана записи.
@immutable
class RecordState {
  const RecordState({
    this.stage = RecordStage.idle,
    this.transcript,
    this.operations = const [],
    this.errorMessage,
    this.elapsed = Duration.zero,
    this.isBusy = false,
    this.processingDuration,
    this.model,
    this.fallbackUsed = false,
    this.offline = false,
    this.canRefineOnline = false,
    this.refineError,
    this.shortcut,
    this.source = OperationSource.voice,
    this.savedCount = 0,
    this.localOnly = false,
    this.quotaExceeded = false,
  });

  final RecordStage stage;
  final String? transcript;
  final List<ParsedOperation> operations;
  final String? errorMessage;

  /// Длительность текущей записи (для таймера).
  final Duration elapsed;

  /// Признак выполнения сетевого/дискового шага.
  final bool isBusy;

  /// Время обработки «остановка записи → сохранение».
  final Duration? processingDuration;

  /// Модель, которой разобран текст.
  final String? model;

  /// Был ли использован fallback-разбор.
  final bool fallbackUsed;

  /// Признак локального (офлайн) разбора.
  final bool offline;

  /// Появилась ли сеть — доступна кнопка «Уточнить через AI».
  final bool canRefineOnline;

  /// Ошибка повторного AI-разбора офлайн-операции.
  final String? refineError;

  /// Результат выполненного шортката.
  final ShortcutResult? shortcut;

  /// Источник операций: голос или ручной текст.
  final OperationSource source;

  /// Сколько операций сохранено на шаге «Сохранено».
  final int savedCount;

  /// Разбор выполнен локально в режиме «Только ручной ввод» (без облака).
  final bool localOnly;

  /// Исчерпан лимит бесплатных операций (ответ прокси 402).
  final bool quotaExceeded;

  bool get hasOperations => operations.isNotEmpty;

  RecordState copyWith({
    RecordStage? stage,
    Object? transcript = _unset,
    List<ParsedOperation>? operations,
    Object? errorMessage = _unset,
    Duration? elapsed,
    bool? isBusy,
    Object? processingDuration = _unset,
    Object? model = _unset,
    bool? fallbackUsed,
    bool? offline,
    bool? canRefineOnline,
    Object? refineError = _unset,
    Object? shortcut = _unset,
    OperationSource? source,
    int? savedCount,
    bool? localOnly,
    bool? quotaExceeded,
  }) {
    return RecordState(
      stage: stage ?? this.stage,
      transcript: transcript == _unset
          ? this.transcript
          : transcript as String?,
      operations: operations ?? this.operations,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
      elapsed: elapsed ?? this.elapsed,
      isBusy: isBusy ?? this.isBusy,
      processingDuration: processingDuration == _unset
          ? this.processingDuration
          : processingDuration as Duration?,
      model: model == _unset ? this.model : model as String?,
      fallbackUsed: fallbackUsed ?? this.fallbackUsed,
      offline: offline ?? this.offline,
      canRefineOnline: canRefineOnline ?? this.canRefineOnline,
      refineError: refineError == _unset
          ? this.refineError
          : refineError as String?,
      shortcut: shortcut == _unset
          ? this.shortcut
          : shortcut as ShortcutResult?,
      source: source ?? this.source,
      savedCount: savedCount ?? this.savedCount,
      localOnly: localOnly ?? this.localOnly,
      quotaExceeded: quotaExceeded ?? this.quotaExceeded,
    );
  }

  static const Object _unset = Object();
}
