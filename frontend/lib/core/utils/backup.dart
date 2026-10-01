import 'dart:convert';

import '../../domain/models/app_settings.dart';
import '../../domain/models/categorization_rule.dart';
import '../../domain/models/category.dart';
import '../../domain/models/operation.dart';

/// Версия формата резервной копии.
const int kBackupFormatVersion = 1;

/// Имя файла резервной копии для указанной даты.
String backupFileName([DateTime? now]) {
  final date = now ?? DateTime.now();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return 'sona-backup-${date.year}-$month-$day.json';
}

/// Сериализует все данные пользователя в JSON-строку.
///
/// Чистая функция без побочных эффектов: результат детерминирован для
/// одинаковых входных данных и пригоден для проверки в тестах.
String buildBackupJson({
  required List<Operation> operations,
  required List<Category> categories,
  required List<CategorizationRule> rules,
  required AppSettings settings,
  required DateTime exportedAt,
}) {
  final payload = <String, dynamic>{
    'app': 'Sona',
    'format': 'sona.backup',
    'formatVersion': kBackupFormatVersion,
    'exportedAt': exportedAt.toIso8601String(),
    'operations': [for (final operation in operations) _operationToJson(operation)],
    'categories': [for (final category in categories) _categoryToJson(category)],
    'categorizationRules': [
      for (final rule in rules) _ruleToJson(rule),
    ],
    'settings': settings.toJson(),
  };
  return const JsonEncoder.withIndent('  ').convert(payload);
}

Map<String, dynamic> _operationToJson(Operation operation) => {
  'id': operation.id,
  'type': operation.type.wireValue,
  'amount': operation.amount,
  'category': operation.category,
  'subcategory': operation.subcategory,
  'date': operation.date.toIso8601String(),
  'confidence': operation.confidence,
  'source': operation.source.wireValue,
  'createdAt': operation.createdAt.toIso8601String(),
};

Map<String, dynamic> _categoryToJson(Category category) => {
  'name': category.name,
  'isIncome': category.isIncome,
  'sortOrder': category.sortOrder,
  'subcategories': category.subcategories,
};

Map<String, dynamic> _ruleToJson(CategorizationRule rule) => {
  'keyword': rule.keyword,
  'category': rule.category,
  'subcategory': rule.subcategory,
  'createdAt': rule.createdAt.toIso8601String(),
};
