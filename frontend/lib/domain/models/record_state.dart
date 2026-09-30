import 'package:flutter/foundation.dart';

import 'operation.dart';

/// Состояния экрана записи (ТЗ, раздел 6.3).
enum RecordStage {
  /// Ожидание — пульсирующий микрофон.
  idle,

  /// Слушаю — идёт запись.
  listening,

  /// Распознал — получен текст транскрипта.
  recognized,

  /// Разобрал — готовы карточки операций.
  parsed,

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
    this.savedCount = 0,
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

  /// Сколько операций сохранено на шаге «Сохранено».
  final int savedCount;

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
    int? savedCount,
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
      savedCount: savedCount ?? this.savedCount,
    );
  }

  static const Object _unset = Object();
}
