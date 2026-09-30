import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/config/app_config.dart';
import '../core/utils/analytics_math.dart';
import '../core/utils/budget_math.dart';
import '../data/local/app_database.dart';
import '../data/remote/interceptors.dart';
import '../data/remote/odirouter_client.dart';
import '../data/repositories/categorization_repository_impl.dart';
import '../data/repositories/category_repository_impl.dart';
import '../data/repositories/operation_repository_impl.dart';
import '../data/services/audio_recorder_service.dart';
import '../data/services/connectivity_service_impl.dart';
import '../data/services/device_identity_store.dart';
import '../data/services/local_notification_service.dart';
import '../data/services/local_text_parser.dart';
import '../data/services/permission_service_impl.dart';
import '../data/services/recording_file_store.dart';
import '../data/services/secure_app_settings_store.dart';
import '../domain/repositories/categorization_repository.dart';
import '../domain/repositories/operation_repository.dart';
import '../domain/models/app_settings.dart';
import '../domain/models/categorization_rule.dart';
import '../domain/models/category.dart';
import '../domain/models/currency.dart';
import '../domain/models/operation.dart';
import '../domain/services/app_settings_store.dart';
import '../domain/services/audio_recorder.dart';
import '../domain/services/connectivity_service.dart';
import '../domain/services/learning_text_parser.dart';
import '../domain/services/permission_service.dart';
import '../domain/services/recognition_service.dart';
import '../domain/services/notification_service.dart';
import '../domain/services/recording_file_store.dart';

/// Защищённое хранилище секретов приложения.
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

/// Базовый URL прокси.
final apiBaseUrlProvider = Provider<String>((ref) => AppConfig.apiBaseUrl);

BaseOptions _baseOptions(String baseUrl) => BaseOptions(
  baseUrl: baseUrl,
  connectTimeout: AppConfig.connectTimeout,
  receiveTimeout: AppConfig.receiveTimeout,
);

/// Dio без авторизации (регистрация устройства).
final registrationDioProvider = Provider<Dio>(
  (ref) => Dio(_baseOptions(ref.watch(apiBaseUrlProvider))),
);

/// Идентичность устройства (токен в secure storage).
final deviceIdentityProvider = Provider<DeviceIdentityStore>(
  (ref) => DeviceIdentityStore(
    ref.watch(registrationDioProvider),
    ref.watch(secureStorageProvider),
  ),
);

/// Основной Dio с interceptors: авторизация, retry, логирование.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(_baseOptions(ref.watch(apiBaseUrlProvider)));
  dio.interceptors.addAll([
    DeviceAuthInterceptor(
      ref.watch(deviceIdentityProvider),
      ref.watch(registrationDioProvider),
    ),
    RetryInterceptor(dio),
    if (kDebugMode)
      LogInterceptor(requestBody: false, responseBody: false),
  ]);
  return dio;
});

/// Клиент прокси OdiRouter.
final odiRouterClientProvider = Provider<OdiRouterClient>(
  (ref) => OdiRouterClient(ref.watch(dioProvider)),
);

/// Распознавание речи.
final speechRecognitionProvider = Provider<SpeechRecognitionService>(
  (ref) => ref.watch(odiRouterClientProvider),
);

/// Разбор текста в операции.
final textParsingProvider = Provider<TextParsingService>(
  (ref) => ref.watch(odiRouterClientProvider),
);

/// Локальный офлайн-разбор текста (регулярки + словарь категорий),
/// дополненный применением выученных правил категоризации.
final localTextParserProvider = Provider<TextParsingService>((ref) {
  return LearnedRulesParser(
    const LocalTextParser(),
    ref.watch(categorizationRepositoryProvider),
  );
});

/// Отслеживание доступности сети.
final connectivityProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityPlusService(),
);

/// Запись аудио.
final audioRecorderProvider = Provider<AudioRecorderPort>((ref) {
  final recorder = RecordAudioRecorderService();
  ref.onDispose(recorder.dispose);
  return recorder;
});

/// Файловое хранилище аудиозаписей.
final recordingFileStoreProvider = Provider<RecordingFileStore>(
  (ref) => TemporaryRecordingFileStore(),
);

/// Локальная БД. Переопределяется в `main()` и в тестах.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider must be overridden'),
);

/// Репозиторий операций.
final operationRepositoryProvider = Provider<OperationRepository>(
  (ref) => DriftOperationRepository(ref.watch(appDatabaseProvider)),
);

/// Репозиторий категорий.
final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => DriftCategoryRepository(ref.watch(appDatabaseProvider)),
);

/// Категории с подкатегориями для UI (реактивно: правки сразу видны).
final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchAll(),
);

/// Последние операции для главной (и для проверки сохранения).
final recentOperationsProvider = StreamProvider<List<Operation>>(
  (ref) => ref.watch(operationRepositoryProvider).watchRecent(limit: 20),
);

/// Репозиторий выученных правил категоризации.
final categorizationRepositoryProvider = Provider<CategorizationRepository>(
  (ref) => DriftCategorizationRepository(ref.watch(appDatabaseProvider)),
);

/// Выученные правила категоризации для UI.
final categorizationRulesProvider = StreamProvider<List<CategorizationRule>>(
  (ref) => ref.watch(categorizationRepositoryProvider).watchAll(),
);

/// Хранилище пользовательских настроек.
final appSettingsStoreProvider = Provider<AppSettingsStore>(
  (ref) => SecureAppSettingsStore(ref.watch(secureStorageProvider)),
);

/// Настройки приложения (онбординг, валюта, категории, бюджет).
final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

/// Управляет загрузкой и сохранением [AppSettings].
class AppSettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.watch(appSettingsStoreProvider).load();

  /// Завершает онбординг: сохраняет валюту и выбранные категории.
  Future<void> completeOnboarding({
    required String currencyCode,
    required Set<String> selectedCategories,
  }) async {
    final current = state.value ?? const AppSettings();
    await _update(
      current.copyWith(
        onboardingCompleted: true,
        currencyCode: currencyCode,
        selectedCategories: selectedCategories,
      ),
    );
  }

  /// Меняет валюту.
  Future<void> setCurrency(String code) async {
    final current = state.value ?? const AppSettings();
    await _update(current.copyWith(currencyCode: code));
  }

  /// Задаёт или сбрасывает месячный бюджет.
  Future<void> setMonthlyBudget(double? budget) async {
    final current = state.value ?? const AppSettings();
    await _update(current.copyWith(monthlyBudget: budget));
  }

  /// Задаёт или снимает лимит по ключу: имя категории либо пара
  /// «категория :: подкатегория» (см. [subcategoryLimitKey]).
  Future<void> setCategoryLimit(String key, double? limit) async {
    final current = state.value ?? const AppSettings();
    final limits = {...current.categoryLimits};
    if (limit == null) {
      limits.remove(key);
    } else {
      limits[key] = limit;
    }
    await _update(current.copyWith(categoryLimits: limits));
  }

  /// Задаёт пороги предупреждений (нормализует значения).
  Future<void> setAlertThresholds(List<int> thresholds) async {
    final current = state.value ?? const AppSettings();
    await _update(
      current.copyWith(
        alertThresholds: BudgetMath.normalizeThresholds(thresholds),
      ),
    );
  }

  /// Включает или выключает перенос остатка бюджета.
  Future<void> setCarryOverEnabled(bool enabled) async {
    final current = state.value ?? const AppSettings();
    await _update(current.copyWith(carryOverEnabled: enabled));
  }

  /// Отмечает месяц обработанным и фиксирует перенесённый остаток.
  Future<void> markMonthProcessed({
    required String monthKey,
    required double carryOverAmount,
  }) async {
    final current = state.value ?? const AppSettings();
    await _update(
      current.copyWith(
        lastProcessedMonth: monthKey,
        carryOverAmount: carryOverAmount,
      ),
    );
  }

  /// Добавляет маркеры отправленных событий уведомлений (идемпотентность).
  Future<void> addAlertMarkers(Set<String> markers) async {
    if (markers.isEmpty) return;
    final current = state.value ?? const AppSettings();
    await _update(current.copyWith(
      alertMarkers: {...current.alertMarkers, ...markers},
    ));
  }

  Future<void> _update(AppSettings settings) async {
    state = AsyncData(settings);
    await ref.read(appSettingsStoreProvider).save(settings);
  }
}

/// Валюта пользователя для форматирования сумм.
final currencyProvider = Provider<AppCurrency>((ref) {
  final settings = ref.watch(appSettingsProvider).value;
  return currencyByCode(settings?.currencyCode ?? kDefaultCurrencyCode);
});

/// Месячный бюджет пользователя (или `null`).
final monthlyBudgetProvider = Provider<double?>((ref) {
  return ref.watch(appSettingsProvider).value?.monthlyBudget;
});

/// Лимиты расходов по категориям и подкатегориям.
final categoryLimitsProvider = Provider<Map<String, double>>((ref) {
  return ref.watch(appSettingsProvider).value?.categoryLimits ?? const {};
});

/// Пороги предупреждений о расходе бюджета (проценты, по возрастанию).
final alertThresholdsProvider = Provider<List<int>>((ref) {
  return ref.watch(appSettingsProvider).value?.alertThresholds ??
      const [50, 80, 100];
});

/// Текущий диапазон календарного месяца `[начало, следующий месяц)`.
(DateTime, DateTime) currentMonthRange([DateTime? now]) {
  final value = now ?? DateTime.now();
  return (
    DateTime(value.year, value.month),
    DateTime(value.year, value.month + 1),
  );
}

/// Диапазон предыдущего календарного месяца `[начало, конец)`.
(DateTime, DateTime) previousMonthRange([DateTime? now]) {
  final value = now ?? DateTime.now();
  return (
    DateTime(value.year, value.month - 1),
    DateTime(value.year, value.month),
  );
}

/// Сумма расходов за текущий месяц.
final monthlyExpenseProvider = FutureProvider<double>((ref) {
  ref.watch(recentOperationsProvider);
  final (from, to) = currentMonthRange();
  return ref
      .watch(operationRepositoryProvider)
      .totalByType(OperationType.expense, from: from, to: to);
});

/// Сумма доходов за текущий месяц.
final monthlyIncomeProvider = FutureProvider<double>((ref) {
  ref.watch(recentOperationsProvider);
  final (from, to) = currentMonthRange();
  return ref
      .watch(operationRepositoryProvider)
      .totalByType(OperationType.income, from: from, to: to);
});

/// Расходы за текущий месяц по категориям (только расходы).
final monthlyExpensesByCategoryProvider =
    FutureProvider<Map<String, double>>((ref) {
  ref.watch(recentOperationsProvider);
  final (from, to) = currentMonthRange();
  return ref
      .watch(operationRepositoryProvider)
      .expensesByCategory(from: from, to: to);
});

/// Расходы за текущий месяц по парам «категория :: подкатегория».
final monthlyExpensesBySubcategoryProvider =
    FutureProvider<Map<String, double>>((ref) {
  ref.watch(recentOperationsProvider);
  final (from, to) = currentMonthRange();
  return ref
      .watch(operationRepositoryProvider)
      .expensesBySubcategory(from: from, to: to);
});

/// Баланс: все доходы минус все расходы.
final balanceProvider = FutureProvider<double>((ref) async {
  ref.watch(recentOperationsProvider);
  final repository = ref.watch(operationRepositoryProvider);
  final income = await repository.totalByType(OperationType.income);
  final expense = await repository.totalByType(OperationType.expense);
  return income - expense;
});

/// Выбор пользователя на экране аналитики: период, произвольный диапазон
/// и фильтр по категориям (пустое множество — все категории).
class AnalyticsSelection {
  const AnalyticsSelection({
    this.period = AnalyticsPeriod.week,
    this.customRange,
    this.categories = const {},
  });

  /// Таб периода: Неделя / Месяц / Год / Период.
  final AnalyticsPeriod period;

  /// Произвольный диапазон для таба «Период».
  final PeriodRange? customRange;

  /// Выбранные категории-фильтр (пустое множество — без фильтра).
  final Set<String> categories;

  /// Применяется ли фильтр по категориям.
  bool get filtersCategories => categories.isNotEmpty;

  /// Диапазон выбранного периода, содержащий [now].
  PeriodRange rangeFor(DateTime now) => AnalyticsMath.rangeFor(
    period,
    now,
    customRange: customRange,
  );

  /// Диапазон предыдущего периода той же длины.
  PeriodRange previousRangeFor(DateTime now) =>
      AnalyticsMath.previousRangeFor(
        period,
        now,
        customRange: customRange,
      );
}

/// Управляет табами периода и фильтрами аналитики.
class AnalyticsSelectionController extends Notifier<AnalyticsSelection> {
  @override
  AnalyticsSelection build() => const AnalyticsSelection();

  /// Переключает таб периода.
  void setPeriod(AnalyticsPeriod period) {
    state = AnalyticsSelection(
      period: period,
      customRange: state.customRange,
      categories: state.categories,
    );
  }

  /// Задаёт произвольный диапазон дат для таба «Период».
  void setCustomRange(PeriodRange range) {
    state = AnalyticsSelection(
      period: state.period,
      customRange: range,
      categories: state.categories,
    );
  }

  /// Включает или выключает категорию в фильтре.
  void toggleCategory(String category) {
    final next = {...state.categories};
    next.contains(category) ? next.remove(category) : next.add(category);
    state = AnalyticsSelection(
      period: state.period,
      customRange: state.customRange,
      categories: next,
    );
  }

  /// Сбрасывает фильтр по категориям.
  void clearCategories() {
    state = AnalyticsSelection(
      period: state.period,
      customRange: state.customRange,
    );
  }
}

/// Выбор периода и фильтров аналитики.
final analyticsSelectionProvider =
    NotifierProvider<AnalyticsSelectionController, AnalyticsSelection>(
      AnalyticsSelectionController.new,
    );

/// Сводка трат за выбранный период аналитики.
class AnalyticsOverview {
  const AnalyticsOverview({
    required this.range,
    required this.total,
    required this.previousTotal,
    required this.categories,
    required this.topCategories,
    required this.months,
  });

  /// Диапазон текущего периода.
  final PeriodRange range;

  /// Сумма трат за выбранный период (с учётом фильтра категорий).
  final double total;

  /// Сумма трат за предыдущий период (с учётом фильтра категорий).
  final double previousTotal;

  /// Расходы по всем категориям периода (без учёта фильтра) —
  /// источник опций фильтра по категориям.
  final Map<String, double> categories;

  /// Топ категорий выбранного периода по убыванию трат
  /// (с учётом фильтра категорий, максимум пять позиций).
  final List<CategoryShare> topCategories;

  /// Траты по последним шести календарным месяцам (включая текущий)
  /// с учётом фильтра категорий — для бар-чарта.
  final List<MonthlyBucket> months;

  /// Процент изменения к предыдущему периоду (`null` — нечего сравнивать).
  int? get percentChange =>
      AnalyticsMath.percentageChange(current: total, previous: previousTotal);
}

/// Количество месяцев в бар-чарте динамики трат.
const int kAnalyticsMonthsVisible = 6;

/// Верхняя граница блока топ категорий.
const int kAnalyticsTopCategories = 5;

/// Сводка трат за выбранный период и процент к предыдущему.
///
/// Пересчитывается реактивно: на любые правки операций и смену
/// табов периода или фильтров категорий.
final analyticsOverviewProvider = FutureProvider<AnalyticsOverview>((ref) async {
  final selection = ref.watch(analyticsSelectionProvider);
  ref.watch(recentOperationsProvider);
  final repository = ref.watch(operationRepositoryProvider);
  final now = DateTime.now();
  final range = selection.rangeFor(now);
  final previous = selection.previousRangeFor(now);

  double sum(Map<String, double> map) {
    return map.entries
        .where((entry) =>
            !selection.filtersCategories ||
            selection.categories.contains(entry.key))
        .fold<double>(0, (sum, entry) => sum + entry.value);
  }

  final currentByCategory = await repository.expensesByCategory(
    from: range.from,
    to: range.to,
  );
  final previousByCategory = await repository.expensesByCategory(
    from: previous.from,
    to: previous.to,
  );
  final monthGroups = await repository.expensesByMonthCategory(
    from: DateTime(now.year, now.month - kAnalyticsMonthsVisible + 1),
    to: DateTime(now.year, now.month + 1),
  );

  final months = <MonthlyBucket>[];
  for (var i = kAnalyticsMonthsVisible - 1; i >= 0; i--) {
    final monthStart = DateTime(now.year, now.month - i);
    final key = '${monthStart.year}-'
        '${monthStart.month.toString().padLeft(2, '0')}';
    final group = monthGroups[key] ?? const <String, double>{};
    months.add(MonthlyBucket(month: monthStart, amount: sum(group)));
  }

  final rankedEntries = currentByCategory.entries
      .where((entry) =>
          !selection.filtersCategories ||
          selection.categories.contains(entry.key))
      .where((entry) => entry.value > 0)
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return AnalyticsOverview(
    range: range,
    total: sum(currentByCategory),
    previousTotal: sum(previousByCategory),
    categories: currentByCategory,
    topCategories: [
      for (final entry in rankedEntries.take(kAnalyticsTopCategories))
        CategoryShare(category: entry.key, amount: entry.value),
    ],
    months: months,
  );
});

/// Цикл бюджета месяца: базовый бюджет и перенесённый остаток.
class BudgetCycle {
  const BudgetCycle({
    required this.monthlyBudget,
    required this.carryOver,
    required this.carryOverEnabled,
  });

  static final BudgetCycle none = BudgetCycle(
    monthlyBudget: 0,
    carryOver: 0,
    carryOverEnabled: false,
  );

  /// Базовый месячный бюджет пользователя.
  final double monthlyBudget;

  /// Остаток, перенесённый из прошлого месяца.
  final double carryOver;

  /// Применяется ли перенос остатка.
  final bool carryOverEnabled;

  /// Эффективный бюджет месяца с учётом переноса.
  double get total => BudgetMath.effectiveBudget(
    monthlyBudget,
    carryOverEnabled: carryOverEnabled,
    carryOverAmount: carryOver,
  );
}

/// Управляет циклом бюджета: перенос остатка в наступивший месяц.
class BudgetCycleController extends AsyncNotifier<BudgetCycle> {
  @override
  Future<BudgetCycle> build() async {
    final settings = ref.watch(appSettingsProvider);
    ref.watch(recentOperationsProvider);
    final repository = ref.watch(operationRepositoryProvider);

    final value = settings.value;
    final budget = value?.monthlyBudget;
    if (value == null || budget == null) {
      return BudgetCycle.none;
    }
    return _resolveCarryOver(value, repository);
  }

  Future<BudgetCycle> _resolveCarryOver(
    AppSettings settings,
    OperationRepository repository,
  ) async {
    final budget = settings.monthlyBudget!;
    final key = BudgetMath.monthKey(DateTime.now());

    // Уже посчитано: используем зафиксированный остаток.
    if (settings.lastProcessedMonth == key) {
      return BudgetCycle(
        monthlyBudget: budget,
        carryOver: settings.carryOverAmount ?? 0,
        carryOverEnabled: settings.carryOverEnabled,
      );
    }

    // Новый месяц (или первый запуск переноса): считаем остаток прошлого.
    final (from, to) = previousMonthRange();
    final spent = await repository.totalByType(
      OperationType.expense,
      from: from,
      to: to,
    );
    final remainder =
        BudgetMath.carryOverRemainder(
          monthlyBudget: budget,
          spent: spent,
          enabled: settings.carryOverEnabled,
        ) ??
        0;
    await ref
        .read(appSettingsProvider.notifier)
        .markMonthProcessed(monthKey: key, carryOverAmount: remainder);
    return BudgetCycle(
      monthlyBudget: budget,
      carryOver: remainder,
      carryOverEnabled: settings.carryOverEnabled,
    );
  }
}

/// Эффективный бюджет месяца с учётом переноса остатка.
final budgetCycleProvider =
    AsyncNotifierProvider<BudgetCycleController, BudgetCycle>(
      BudgetCycleController.new,
    );

/// Разрешения на микрофон и уведомления.
final permissionServiceProvider = Provider<PermissionService>(
  (ref) => const PermissionHandlerService(),
);

/// Порт доставки локальных уведомлений.
final notificationsPortProvider = Provider<SonaNotifications>(
  (ref) => LocalNotificationsService(),
);
