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
}
