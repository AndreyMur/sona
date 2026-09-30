import 'package:flutter/foundation.dart';

/// Тип финансовой операции.
enum OperationType {
  expense('expense'),
  income('income');

  const OperationType(this.wireValue);

  /// Значение, используемое в API и локальной БД.
  final String wireValue;

  static OperationType fromWire(String value) {
    return OperationType.values.firstWhere(
      (type) => type.wireValue == value,
      orElse: () => OperationType.expense,
    );
  }
}

/// Источник появления операции.
enum OperationSource {
  voice('voice'),
  text('text'),
  manual('manual');

  const OperationSource(this.wireValue);

  final String wireValue;

  static OperationSource fromWire(String value) {
    return OperationSource.values.firstWhere(
      (source) => source.wireValue == value,
      orElse: () => OperationSource.manual,
    );
  }
}

/// Распознанная, но ещё не сохранённая операция.
///
/// Создаётся из ответа NLU-разбора и показывается на экране записи до
/// подтверждения пользователем.
@immutable
class ParsedOperation {
  const ParsedOperation({
    required this.type,
    required this.amount,
    required this.category,
    this.subcategory,
    required this.date,
    this.confidence = 1.0,
  });

  final OperationType type;
  final double amount;
  final String category;
  final String? subcategory;
  final DateTime date;
  final double confidence;

  ParsedOperation copyWith({
    OperationType? type,
    double? amount,
    String? category,
    Object? subcategory = _unset,
    DateTime? date,
    double? confidence,
  }) {
    return ParsedOperation(
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      subcategory: subcategory == _unset
          ? this.subcategory
          : subcategory as String?,
      date: date ?? this.date,
      confidence: confidence ?? this.confidence,
    );
  }

  static const Object _unset = Object();
}

/// Сохранённая операция с локальным идентификатором.
@immutable
class Operation {
  const Operation({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.subcategory,
    required this.date,
    required this.confidence,
    required this.source,
    required this.createdAt,
  });

  final int id;
  final OperationType type;
  final double amount;
  final String category;
  final String? subcategory;
  final DateTime date;
  final double confidence;
  final OperationSource source;
  final DateTime createdAt;

  Operation copyWith({
    OperationType? type,
    double? amount,
    String? category,
    Object? subcategory = _unset,
    DateTime? date,
    double? confidence,
  }) {
    return Operation(
      id: id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      subcategory: subcategory == _unset
          ? this.subcategory
          : subcategory as String?,
      date: date ?? this.date,
      confidence: confidence ?? this.confidence,
      source: source,
      createdAt: createdAt,
    );
  }

  static const Object _unset = Object();
}
