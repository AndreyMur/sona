import '../../domain/models/operation.dart';
import '../../domain/repositories/operation_repository.dart';
import '../local/app_database.dart';

/// Реализация [OperationRepository] на Drift.
class DriftOperationRepository implements OperationRepository {
  DriftOperationRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<Operation>> saveAll(
    List<ParsedOperation> operations, {
    required OperationSource source,
    DateTime? createdAt,
  }) {
    return _db.insertParsedOperations(
      operations,
      source: source,
      createdAt: createdAt,
    );
  }

  @override
  Future<List<Operation>> recent({int limit = 20}) =>
      _db.recentOperations(limit: limit);

  @override
  Stream<List<Operation>> watchRecent({int limit = 20}) =>
      _db.watchRecentOperations(limit: limit);

  @override
  Future<void> update(Operation operation) => _db.updateOperation(operation);

  @override
  Future<void> delete(int id) => _db.deleteOperation(id);

  @override
  Future<double> totalByType(
    OperationType type, {
    DateTime? from,
    DateTime? to,
  }) => _db.sumAmounts(type: type, from: from, to: to);

  @override
  Future<double> totalByCategory(
    String category, {
    DateTime? from,
    DateTime? to,
  }) => _db.sumAmounts(category: category, from: from, to: to);
}
