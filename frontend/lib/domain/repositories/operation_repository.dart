import '../models/category.dart';
import '../models/operation.dart';

/// Хранилище финансовых операций.
abstract interface class OperationRepository {
  /// Сохраняет распознанные операции и возвращает их с локальными id.
  Future<List<Operation>> saveAll(
    List<ParsedOperation> operations, {
    required OperationSource source,
    DateTime? createdAt,
  });

  /// Последние сохранённые операции (по дате, затем по времени создания).
  Future<List<Operation>> recent({int limit = 20});

  /// Поток последних операций для реактивного UI.
  Stream<List<Operation>> watchRecent({int limit = 20});

  /// Полностью заменяет операцию (например, после ручной правки).
  Future<void> update(Operation operation);

  /// Удаляет операцию по локальному id.
  Future<void> delete(int id);

  /// Сумма операций указанного [type] за период `[from, to)`.
  Future<double> totalByType(
    OperationType type, {
    DateTime? from,
    DateTime? to,
  });

  /// Сумма операций по категории [category] за период `[from, to)`.
  Future<double> totalByCategory(
    String category, {
    DateTime? from,
    DateTime? to,
  });

  /// Расходы за период `[from, to)`, сгруппированные по категории.
  Future<Map<String, double>> expensesByCategory({
    DateTime? from,
    DateTime? to,
  });

  /// Расходы за период `[from, to)`, сгруппированные по парам
  /// «категория :: подкатегория» (см. [subcategoryLimitKey]). Операции
  /// без подкатегории пропускаются.
  Future<Map<String, double>> expensesBySubcategory({
    DateTime? from,
    DateTime? to,
  });
}

/// Хранилище категорий и подкатегорий.
abstract interface class CategoryRepository {
  /// Список категорий с подкатегориями.
  Future<List<Category>> all();

  /// Поток категорий с подкатегориями.
  Stream<List<Category>> watchAll();

  /// Инициализирует категории по умолчанию, если БД пуста.
  Future<void> seedIfEmpty();

  /// Заменяет категории значениями из remote config (сохраняя пользовательские
  /// правки не требуется в MVP).
  Future<void> replaceAll(Map<String, List<String>> categories);

  /// Добавляет категорию и возвращает её.
  Future<Category> addCategory(String name, {bool isIncome = false});

  /// Переименовывает категорию.
  Future<void> renameCategory(int id, String name);

  /// Удаляет категорию вместе с подкатегориями.
  Future<void> deleteCategory(int id);

  /// Добавляет подкатегорию к категории.
  Future<void> addSubcategory(int categoryId, String name);

  /// Переименовывает подкатегорию.
  Future<void> renameSubcategory(int categoryId, String oldName, String newName);

  /// Удаляет подкатегорию.
  Future<void> deleteSubcategory(int categoryId, String name);
}
