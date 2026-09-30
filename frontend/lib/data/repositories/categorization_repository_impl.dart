import '../../domain/models/categorization_rule.dart';
import '../../domain/repositories/categorization_repository.dart';
import '../local/app_database.dart';

/// Реализация [CategorizationRepository] на Drift.
class DriftCategorizationRepository implements CategorizationRepository {
  DriftCategorizationRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<CategorizationRule>> all() => _db.allRules();

  @override
  Stream<List<CategorizationRule>> watchAll() => _db.watchRules();

  @override
  Future<CategorizationRule> learn({
    required String keyword,
    required String category,
    String? subcategory,
  }) => _db.upsertRule(
    keyword: keyword,
    category: category,
    subcategory: subcategory,
  );

  @override
  Future<void> delete(int id) => _db.deleteRule(id);
}
