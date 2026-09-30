import 'package:flutter/foundation.dart';

import 'operation.dart';

/// Результат распознавания речи (STT).
@immutable
class TranscriptionResult {
  const TranscriptionResult({
    required this.text,
    required this.model,
    this.fallbackUsed = false,
    this.durationSeconds = 0,
    this.latencyMs = 0,
    this.costUsd = 0,
    this.requestId = '',
  });

  final String text;
  final String model;
  final bool fallbackUsed;
  final double durationSeconds;
  final int latencyMs;
  final double costUsd;
  final String requestId;
}

/// Результат разбора текста в структуру операций (NLU).
@immutable
class ParseResult {
  const ParseResult({
    required this.operations,
    required this.overallConfidence,
    required this.model,
    this.fallbackUsed = false,
    this.promptVersion = '',
    this.latencyMs = 0,
    this.costUsd = 0,
    this.requestId = '',
  });

  final List<ParsedOperation> operations;
  final double overallConfidence;
  final String model;
  final bool fallbackUsed;
  final String promptVersion;
  final int latencyMs;
  final double costUsd;
  final String requestId;

  bool get isEmpty => operations.isEmpty;
}
