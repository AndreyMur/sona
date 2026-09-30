import 'package:flutter/foundation.dart';

/// Правило категоризации, выученное из ручной правки пользователя.
///
/// Если во фразе встречается [keyword], операции присваивается [category]
/// (и опционально [subcategory]) — это и есть «обучение категоризации».
@immutable
class CategorizationRule {
  const CategorizationRule({
    required this.id,
    required this.keyword,
    required this.category,
    this.subcategory,
    required this.createdAt,
  });

  final int id;

  /// Нормализованное ключевое слово (нижний регистр, без «ё»).
  final String keyword;

  final String category;
  final String? subcategory;
  final DateTime createdAt;
}
