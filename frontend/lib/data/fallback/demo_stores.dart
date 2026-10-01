import 'dart:async';

import '../../domain/models/app_settings.dart';
import '../../domain/models/categorization_rule.dart';
import '../../domain/models/category.dart';
import '../../domain/models/operation.dart';
import '../../domain/repositories/categorization_repository.dart';
import '../../domain/repositories/operation_repository.dart';
import '../../domain/services/app_settings_store.dart';
import '../../domain/services/data_export_store.dart';
import '../../domain/services/notification_service.dart';

/// In-memory-реализации доменных хранилищ для запуска веб-версии:
/// нативная БД (SQLCipher) в браузере недоступна, данные живут
/// до перезагрузки страницы.

/// Категории по умолчанию в памяти (CRUD работает как на мобильном).
class DemoCategoryRepository implements CategoryRepository {
  DemoCategoryRepository([Map<String, List<String>>? source]) {
    _seed(source ?? kDefaultCategories);
  }

  final Map<int, Category> _categories = {};
  final Map<int, List<String>> _subcategories = {};
  int _nextCategoryId = 1;
  final StreamController<List<Category>> _controller =
      StreamController<List<Category>>.broadcast();

  void _seed(Map<String, List<String>> source) {
    var order = 0;
    for (final entry in source.entries) {
      final id = _nextCategoryId++;
      _categories[id] = Category(
        id: id,
        name: entry.key,
        isIncome: entry.key == kIncomeCategory,
        subcategories: [...entry.value],
        sortOrder: order++,
      );
    }
  }

  List<Category> _snapshot() {
    final list = _categories.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return [
      for (final category in list)
        Category(
          id: category.id,
          name: category.name,
          isIncome: category.isIncome,
          subcategories: [...category.subcategories],
          sortOrder: category.sortOrder,
        ),
    ];
  }

  void _notify() => _controller.add(_snapshot());

  @override
  Future<List<Category>> all() async => _snapshot();

  @override
  Stream<List<Category>> watchAll() async* {
    yield _snapshot();
    await for (final value in _controller.stream) {
      yield value;
    }
  }

  @override
  Future<void> seedIfEmpty() async {}

  @override
  Future<void> replaceAll(Map<String, List<String>> categories) async {
    _categories.clear();
    _subcategories.clear();
    _nextCategoryId = 1;
    _seed(categories);
    _notify();
  }

  @override
  Future<void> resetToDefaults() => replaceAll(kDefaultCategories);

  @override
  Future<Category> addCategory(String name, {bool isIncome = false}) async {
    var maxOrder = -1;
    for (final category in _categories.values) {
      if (category.sortOrder > maxOrder) maxOrder = category.sortOrder;
    }
    final id = _nextCategoryId++;
    final category = Category(
      id: id,
      name: name,
      isIncome: isIncome,
      subcategories: [],
      sortOrder: maxOrder + 1,
    );
    _categories[id] = category;
    _notify();
    return category;
  }

  @override
  Future<void> renameCategory(int id, String name) async {
    final category = _categories[id];
    if (category == null) return;
    _categories[id] = Category(
      id: category.id,
      name: name,
      isIncome: category.isIncome,
      subcategories: category.subcategories,
      sortOrder: category.sortOrder,
    );
    _notify();
  }

  @override
  Future<void> deleteCategory(int id) async {
    _categories.remove(id);
    _subcategories.remove(id);
    _notify();
  }

  @override
  Future<void> addSubcategory(int categoryId, String name) async {
    final subs = _subcategories.putIfAbsent(categoryId, () {
      final category = _categories[categoryId];
      return category == null ? <String>[] : [...category.subcategories];
    });
    subs.add(name);
    _syncSubs(categoryId, subs);
    _notify();
  }

  @override
  Future<void> renameSubcategory(
    int categoryId,
    String oldName,
    String newName,
  ) async {
    final subs = _subsOf(categoryId);
    final index = subs.indexOf(oldName);
    if (index == -1) return;
    subs[index] = newName;
    _syncSubs(categoryId, subs);
    _notify();
  }

  @override
  Future<void> deleteSubcategory(int categoryId, String name) async {
    final subs = _subsOf(categoryId)..remove(name);
    _syncSubs(categoryId, subs);
    _notify();
  }

  List<String> _subsOf(int categoryId) {
    final category = _categories[categoryId];
    if (category == null) return [];
    return _subcategories[categoryId] ?? [...category.subcategories];
  }

  void _syncSubs(int categoryId, List<String> subs) {
    _subcategories[categoryId] = subs;
    final category = _categories[categoryId];
    if (category != null) {
      _categories[categoryId] = Category(
        id: category.id,
        name: category.name,
        isIncome: category.isIncome,
        subcategories: [...subs],
        sortOrder: category.sortOrder,
      );
    }
  }
}

/// Операции в памяти (голосовой/ручной ввод, аналитика работают в демо).
class DemoOperationRepository implements OperationRepository {
  DemoOperationRepository();

  final Map<int, Operation> _operations = {};
  int _nextId = 1;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  List<Operation> _snapshot() {
    final list = _operations.values.toList()
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
      });
    return [
      for (final operation in list) _copy(operation),
    ];
  }

  Operation _copy(Operation operation) => Operation(
        id: operation.id,
        type: operation.type,
        amount: operation.amount,
        category: operation.category,
        subcategory: operation.subcategory,
        date: operation.date,
        confidence: operation.confidence,
        source: operation.source,
        createdAt: operation.createdAt,
      );

  void _notify() => _changes.add(null);

  bool _inWindow(DateTime date, DateTime? from, DateTime? to) {
    if (from != null && date.isBefore(from)) return false;
    if (to != null && !date.isBefore(to)) return false;
    return true;
  }

  @override
  Future<List<Operation>> saveAll(
    List<ParsedOperation> operations, {
    required OperationSource source,
    DateTime? createdAt,
  }) async {
    final now = createdAt ?? DateTime.now();
    final saved = <Operation>[];
    for (final parsed in operations) {
      final operation = Operation(
        id: _nextId++,
        type: parsed.type,
        amount: parsed.amount,
        category: parsed.category,
        subcategory: parsed.subcategory,
        date: parsed.date,
        confidence: parsed.confidence,
        source: source,
        createdAt: now,
      );
      _operations[operation.id] = operation;
      saved.add(_copy(operation));
    }
    _notify();
    return saved;
  }

  @override
  Future<List<Operation>> recent({int limit = 20}) async =>
      _snapshot().take(limit).toList();

  @override
  Future<List<Operation>> all() async => _snapshot();

  @override
  Stream<List<Operation>> watchRecent({int limit = 20}) async* {
    yield await recent(limit: limit);
    await for (final _ in _changes.stream) {
      yield await recent(limit: limit);
    }
  }

  @override
  Future<void> update(Operation operation) async {
    _operations[operation.id] = _copy(operation);
    _notify();
  }

  @override
  Future<void> delete(int id) async {
    _operations.remove(id);
    _notify();
  }

  @override
  Future<void> deleteAll() async {
    _operations.clear();
    _notify();
  }

  @override
  Future<double> totalByType(
    OperationType type, {
    DateTime? from,
    DateTime? to,
  }) async {
    return _operations.values
        .where((operation) => operation.type == type)
        .where((operation) => _inWindow(operation.date, from, to))
        .fold<double>(0, (sum, operation) => sum + operation.amount);
  }

  @override
  Future<double> totalByCategory(
    String category, {
    DateTime? from,
    DateTime? to,
  }) async {
    return _operations.values
        .where((operation) => operation.category == category)
        .where((operation) => _inWindow(operation.date, from, to))
        .fold<double>(0, (sum, operation) => sum + operation.amount);
  }

  @override
  Future<Map<String, double>> expensesByCategory({
    DateTime? from,
    DateTime? to,
  }) async {
    final result = <String, double>{};
    for (final operation in _operations.values) {
      if (operation.type != OperationType.expense) continue;
      if (!_inWindow(operation.date, from, to)) continue;
      result[operation.category] =
          (result[operation.category] ?? 0) + operation.amount;
    }
    return result;
  }

  @override
  Future<Map<String, double>> expensesBySubcategory({
    DateTime? from,
    DateTime? to,
  }) async {
    final result = <String, double>{};
    for (final operation in _operations.values) {
      if (operation.type != OperationType.expense) continue;
      if (!_inWindow(operation.date, from, to)) continue;
      final subcategory = operation.subcategory;
      if (subcategory == null || subcategory.isEmpty) continue;
      final key = subcategoryLimitKey(operation.category, subcategory);
      result[key] = (result[key] ?? 0) + operation.amount;
    }
    return result;
  }

  @override
  Future<Map<String, Map<String, double>>> expensesByMonthCategory({
    DateTime? from,
    DateTime? to,
  }) async {
    final result = <String, Map<String, double>>{};
    for (final operation in _operations.values) {
      if (operation.type != OperationType.expense) continue;
      if (!_inWindow(operation.date, from, to)) continue;
      final key =
          '${operation.date.year}-${operation.date.month.toString().padLeft(2, '0')}';
      final group = result.putIfAbsent(key, () => {});
      group[operation.category] =
          (group[operation.category] ?? 0) + operation.amount;
    }
    return result;
  }
}

/// Выученные правила категоризации в памяти.
class DemoCategorizationRepository implements CategorizationRepository {
  final Map<int, CategorizationRule> _rules = {};
  int _nextId = 1;
  final StreamController<List<CategorizationRule>> _controller =
      StreamController<List<CategorizationRule>>.broadcast();

  @override
  Future<List<CategorizationRule>> all() async => _rules.values.toList();

  @override
  Stream<List<CategorizationRule>> watchAll() async* {
    yield _rules.values.toList();
    await for (final value in _controller.stream) {
      yield value;
    }
  }

  @override
  Future<CategorizationRule> learn({
    required String keyword,
    required String category,
    String? subcategory,
  }) async {
    final existing = _rules.values.where((rule) => rule.keyword == keyword);
    if (existing.isNotEmpty) {
      final old = existing.first;
      final rule = CategorizationRule(
        id: old.id,
        keyword: keyword,
        category: category,
        subcategory: subcategory,
        createdAt: old.createdAt,
      );
      _rules[old.id] = rule;
      _controller.add(_rules.values.toList());
      return rule;
    }
    final rule = CategorizationRule(
      id: _nextId++,
      keyword: keyword,
      category: category,
      subcategory: subcategory,
      createdAt: DateTime.now(),
    );
    _rules[rule.id] = rule;
    _controller.add(_rules.values.toList());
    return rule;
  }

  @override
  Future<void> delete(int id) async {
    _rules.remove(id);
    _controller.add(_rules.values.toList());
  }

  @override
  Future<void> deleteAll() async {
    _rules.clear();
    _controller.add(_rules.values.toList());
  }
}

/// Настройки в памяти (валюта, бюджет, лимиты до перезагрузки).
class DemoAppSettingsStore implements AppSettingsStore {
  DemoAppSettingsStore([AppSettings? initial])
      : settings = initial ?? const AppSettings();

  AppSettings settings;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings value) async => settings = value;
}

/// Экспорт данных в веб-демо: файл не пишется, содержимое остаётся в памяти.
class DemoDataExportStore implements DataExportStore {
  String? lastFileName;
  String? lastContent;

  @override
  Future<String> write(String fileName, String content) async {
    lastFileName = fileName;
    lastContent = content;
    return 'demo://$fileName';
  }
}

/// Уведомления в памяти-заглушке: плагин в демо не используется.
class DemoSonaNotifications implements SonaNotifications {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {}

  @override
  Future<void> cancelDailyReminder() async {}
}
