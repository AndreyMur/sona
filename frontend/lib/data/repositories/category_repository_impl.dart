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

  @override
  Future<Category> addCategory(String name, {bool isIncome = false}) async {
    final id = await _db.addCategory(name, isIncome: isIncome);
    return Category(
      id: id,
      name: name,
      isIncome: isIncome,
      subcategories: const [],
    );
  }

  @override
  Future<void> renameCategory(int id, String name) =>
      _db.renameCategory(id, name);

  @override
  Future<void> deleteCategory(int id) => _db.deleteCategory(id);

  @override
  Future<void> addSubcategory(int categoryId, String name) =>
      _db.addSubcategory(categoryId, name);

  @override
  Future<void> renameSubcategory(int categoryId, String oldName, String newName) =>
      _db.renameSubcategory(categoryId, oldName, newName);

  @override
  Future<void> deleteSubcategory(int categoryId, String name) =>
      _db.deleteSubcategory(categoryId, name);
}
