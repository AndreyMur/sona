import 'package:flutter/foundation.dart';

import 'category.dart';
import 'currency.dart';

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
  });

  /// Пройден ли онбординг. Пока `false` — приложение показывает онбординг.
  final bool onboardingCompleted;

  /// Код выбранной валюты (см. [AppCurrency]).
  final String currencyCode;

  /// Имена включённых категорий. Пустое множество означает «все по умолчанию».
  final Set<String> selectedCategories;

  /// Месячный бюджет в валюте пользователя. `null` — бюджет не задан.
  final double? monthlyBudget;

  /// Список категорий, которые нужно показывать пользователю.
  ///
  /// Пустое множество трактуется как «все категории по умолчанию».
  Set<String> get enabledCategories =>
      selectedCategories.isEmpty ? kDefaultCategories.keys.toSet() : selectedCategories;

  AppSettings copyWith({
    bool? onboardingCompleted,
    String? currencyCode,
    Set<String>? selectedCategories,
    Object? monthlyBudget = _unset,
  }) {
    return AppSettings(
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      currencyCode: currencyCode ?? this.currencyCode,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      monthlyBudget: monthlyBudget == _unset
          ? this.monthlyBudget
          : monthlyBudget as double?,
    );
  }

  Map<String, dynamic> toJson() => {
    'onboardingCompleted': onboardingCompleted,
    'currencyCode': currencyCode,
    'selectedCategories': selectedCategories.toList(),
    'monthlyBudget': monthlyBudget,
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
    );
  }

  static const Object _unset = Object();
}
