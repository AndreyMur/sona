import 'package:flutter/foundation.dart';

import 'category.dart';
import 'currency.dart';

/// Разделитель пары «категория :: подкатегория» в ключах лимитов.
const String kCategoryLimitSeparator = '::';

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
    );
  }

  Map<String, dynamic> toJson() => {
    'onboardingCompleted': onboardingCompleted,
    'currencyCode': currencyCode,
    'selectedCategories': selectedCategories.toList(),
    'monthlyBudget': monthlyBudget,
    'categoryLimits': categoryLimits,
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
    );
  }

  static const Object _unset = Object();
}
