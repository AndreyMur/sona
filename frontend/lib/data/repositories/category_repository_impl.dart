import '../../domain/models/category.dart';
import '../../domain/repositories/operation_repository.dart';
import '../local/app_database.dart';

/// Реализация [CategoryRepository] на Drift.
class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<Category>> all() => _db.categoriesWithSubcategories();

  @override
  Stream<List<Category>> watchAll() => _db.watchCategoriesWithSubcategories();

  @override
  Future<void> seedIfEmpty() async {
    if ((await _db.categoriesWithSubcategories()).isEmpty) {
      await _db.seedCategories(kDefaultCategories);
    }
  }

  @override
  Future<void> replaceAll(Map<String, List<String>> categories) =>
      _db.replaceCategories(categories);
}
