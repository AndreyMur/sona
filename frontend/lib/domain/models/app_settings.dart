import 'package:flutter/foundation.dart';

import 'category.dart';
import 'currency.dart';

/// Разделитель пары «категория :: подкатегория» в ключах лимитов.
const String kCategoryLimitSeparator = '::';

/// Автоблокировка по умолчанию: 60 секунд в фоне (см. [AppSettings.autoLockSeconds]).
const int kDefaultAutoLockSeconds = 60;

/// Значение [AppSettings.autoLockSeconds] «блокировать сразу» при уходе в фон.
const int kLockImmediatelySeconds = 0;

/// Ключ лимита расхода для пары «категория — подкатегория».
String subcategoryLimitKey(String category, String subcategory) =>
    '$category$kCategoryLimitSeparator$subcategory';

/// Пользовательские настройки приложения.
///
/// Хранятся локально в защищённом хранилище и переживают перезапуск.
@immutable
class AppSettings {
  const AppSettings({
    this.onboardingCompleted = false,
    this.currencyCode = kDefaultCurrencyCode,
    this.selectedCategories = const <String>{},
    this.monthlyBudget,
    this.categoryLimits = const <String, double>{},
    this.alertThresholds = const <int>[50, 80, 100],
    this.carryOverEnabled = false,
    this.carryOverAmount,
    this.lastProcessedMonth,
    this.alertMarkers = const <String>{},
    this.userName,
    this.userEmail,
    this.manualOnlyMode = false,
    this.appLockEnabled = false,
    this.biometricEnabled = false,
    this.pinHash,
    this.autoLockSeconds = kDefaultAutoLockSeconds,
  });

  /// Пройден ли онбординг. Пока `false` — приложение показывает онбординг.
  final bool onboardingCompleted;

  /// Код выбранной валюты (см. [AppCurrency]).
  final String currencyCode;

  /// Имена включённых категорий. Пустое множество означает «все по умолчанию».
  final Set<String> selectedCategories;

  /// Месячный бюджет в валюте пользователя. `null` — бюджет не задан.
  final double? monthlyBudget;

  /// Лимиты расходов по категориям и подкатегориям.
  ///
  /// Ключ — имя категории (`Продукты`) либо пара «категория ::
  /// подкатегория» через [subcategoryLimitKey] (`Продукты::Супермаркет`).
  final Map<String, double> categoryLimits;

  /// Пороги (в процентах) предупреждений о расходе бюджета, по возрастанию.
  final List<int> alertThresholds;

  /// Переносится ли неиспользованный остаток бюджета в новый месяц.
  final bool carryOverEnabled;

  /// Остаток, перенесённый из прошлого месяца в текущий.
  final double? carryOverAmount;

  /// Месяц («ГГГГ-ММ»), для которого остаток уже переносился.
  final String? lastProcessedMonth;

  /// Маркеры уже отправленных событий уведомлений (idемпотентность алертов).
  ///
  /// Например: `thr:2026-09:80` — порог 80% уведомлён за сентябрь,
  /// `anomaly:2026-09-15` — аномалия трат уже сообщена в этот день.
  final Set<String> alertMarkers;

  /// Отображаемое имя пользователя (необязательно).
  final String? userName;

  /// Email пользователя (необязательно).
  final String? userEmail;

  /// Режим «Только ручной ввод»: приложение работает полностью локально
  /// и не отправляет аудио в облако.
  final bool manualOnlyMode;

  /// Включена ли защита входа (PIN / биометрия).
  final bool appLockEnabled;

  /// Разрешён ли вход по Face ID / Touch ID.
  final bool biometricEnabled;

  /// Хеш PIN-кода (см. `PinHasher`). `null` — PIN не задан.
  final String? pinHash;

  /// Через сколько секунд в фоне срабатывает автоблокировка
  /// ([kLockImmediatelySeconds] — сразу, 0 — мгновенно).
  final int autoLockSeconds;

  /// Список категорий, которые нужно показывать пользователю.
  ///
  /// Пустое множество трактуется как «все категории по умолчанию».
  Set<String> get enabledCategories =>
      selectedCategories.isEmpty ? kDefaultCategories.keys.toSet() : selectedCategories;

  /// Действующий лимит для пары «категория — подкатегория»: сначала
  /// проверяется точная пара, затем лимит всей категории.
  double? limitFor(String category, [String? subcategory]) {
    if (subcategory != null && subcategory.isNotEmpty) {
      final limit = categoryLimits[subcategoryLimitKey(category, subcategory)];
      if (limit != null) return limit;
    }
    return categoryLimits[category];
  }

  AppSettings copyWith({
    bool? onboardingCompleted,
    String? currencyCode,
    Set<String>? selectedCategories,
    Object? monthlyBudget = _unset,
    Object? categoryLimits = _unset,
    List<int>? alertThresholds,
    bool? carryOverEnabled,
    Object? carryOverAmount = _unset,
    Object? lastProcessedMonth = _unset,
    Set<String>? alertMarkers,
    Object? userName = _unset,
    Object? userEmail = _unset,
    bool? manualOnlyMode,
    bool? appLockEnabled,
    bool? biometricEnabled,
    Object? pinHash = _unset,
    int? autoLockSeconds,
  }) {
    return AppSettings(
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      currencyCode: currencyCode ?? this.currencyCode,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      monthlyBudget: monthlyBudget == _unset
          ? this.monthlyBudget
          : monthlyBudget as double?,
      categoryLimits: categoryLimits == _unset
          ? this.categoryLimits
          : categoryLimits as Map<String, double>,
      alertThresholds: alertThresholds ?? this.alertThresholds,
      carryOverEnabled: carryOverEnabled ?? this.carryOverEnabled,
      carryOverAmount: carryOverAmount == _unset
          ? this.carryOverAmount
          : carryOverAmount as double?,
      lastProcessedMonth: lastProcessedMonth == _unset
          ? this.lastProcessedMonth
          : lastProcessedMonth as String?,
      alertMarkers: alertMarkers ?? this.alertMarkers,
      userName: userName == _unset ? this.userName : userName as String?,
      userEmail: userEmail == _unset ? this.userEmail : userEmail as String?,
      manualOnlyMode: manualOnlyMode ?? this.manualOnlyMode,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      pinHash: pinHash == _unset ? this.pinHash : pinHash as String?,
      autoLockSeconds: autoLockSeconds ?? this.autoLockSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
    'onboardingCompleted': onboardingCompleted,
    'currencyCode': currencyCode,
    'selectedCategories': selectedCategories.toList(),
    'monthlyBudget': monthlyBudget,
    'categoryLimits': categoryLimits,
    'alertThresholds': alertThresholds,
    'carryOverEnabled': carryOverEnabled,
    'carryOverAmount': carryOverAmount,
    'lastProcessedMonth': lastProcessedMonth,
    'alertMarkers': alertMarkers.toList(),
    'userName': userName,
    'userEmail': userEmail,
    'manualOnlyMode': manualOnlyMode,
    'appLockEnabled': appLockEnabled,
    'biometricEnabled': biometricEnabled,
    'pinHash': pinHash,
    'autoLockSeconds': autoLockSeconds,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      currencyCode: json['currencyCode'] as String? ?? kDefaultCurrencyCode,
      selectedCategories:
          (json['selectedCategories'] as List<dynamic>?)
              ?.map((value) => value.toString())
              .toSet() ??
          const <String>{},
      monthlyBudget: (json['monthlyBudget'] as num?)?.toDouble(),
      categoryLimits:
          (json['categoryLimits'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, (value as num).toDouble()),
          ) ??
          const <String, double>{},
      alertThresholds: (json['alertThresholds'] as List<dynamic>?)
              ?.map((value) => (value as num).toInt())
              .toList() ??
          const <int>[50, 80, 100],
      carryOverEnabled: json['carryOverEnabled'] as bool? ?? false,
      carryOverAmount: (json['carryOverAmount'] as num?)?.toDouble(),
      lastProcessedMonth: json['lastProcessedMonth'] as String?,
      alertMarkers:
          (json['alertMarkers'] as List<dynamic>?)
              ?.map((value) => value.toString())
              .toSet() ??
          const <String>{},
      userName: json['userName'] as String?,
      userEmail: json['userEmail'] as String?,
      manualOnlyMode: json['manualOnlyMode'] as bool? ?? false,
      appLockEnabled: json['appLockEnabled'] as bool? ?? false,
      biometricEnabled: json['biometricEnabled'] as bool? ?? false,
      pinHash: json['pinHash'] as String?,
      autoLockSeconds:
          (json['autoLockSeconds'] as num?)?.toInt() ?? kDefaultAutoLockSeconds,
    );
  }

  static const Object _unset = Object();
}
