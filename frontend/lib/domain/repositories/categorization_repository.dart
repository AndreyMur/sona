import '../models/categorization_rule.dart';

/// Хранилище выученных правил категоризации.
abstract interface class CategorizationRepository {
  /// Все правила.
  Future<List<CategorizationRule>> all();

  /// Поток правил для реактивного UI.
  Stream<List<CategorizationRule>> watchAll();

  /// Создаёт или обновляет правило для [keyword].
  Future<CategorizationRule> learn({
    required String keyword,
    required String category,
    String? subcategory,
  });

  /// Удаляет правило по id.
  Future<void> delete(int id);

  /// Удаляет все выученные правила.
  Future<void> deleteAll();
}
