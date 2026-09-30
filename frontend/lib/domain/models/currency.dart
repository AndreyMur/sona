import 'package:flutter/foundation.dart';

/// Валюта, доступная для выбора в онбординге и настройках.
@immutable
class AppCurrency {
  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.title,
  });

  /// ISO-код валюты (например, `RUB`).
  final String code;

  /// Символ для форматирования сумм (например, `₽`).
  final String symbol;

  /// Человекочитаемое название.
  final String title;
}

/// Валюты, поддерживаемые в MVP.
const List<AppCurrency> kCurrencies = [
  AppCurrency(code: 'RUB', symbol: '₽', title: 'Российский рубль'),
  AppCurrency(code: 'USD', symbol: '\$', title: 'Доллар США'),
  AppCurrency(code: 'EUR', symbol: '€', title: 'Евро'),
  AppCurrency(code: 'KZT', symbol: '₸', title: 'Казахстанский тенге'),
  AppCurrency(code: 'BYN', symbol: 'Br', title: 'Белорусский рубль'),
  AppCurrency(code: 'UAH', symbol: '₴', title: 'Украинская гривна'),
  AppCurrency(code: 'GBP', symbol: '£', title: 'Фунт стерлингов'),
  AppCurrency(code: 'TRY', symbol: '₺', title: 'Турецкая лира'),
  AppCurrency(code: 'GEL', symbol: '₾', title: 'Грузинский лари'),
  AppCurrency(code: 'AED', symbol: 'د.إ', title: 'Дирхам ОАЭ'),
];

/// Валюта по умолчанию.
const String kDefaultCurrencyCode = 'RUB';

/// Возвращает валюту по коду или рубль, если код неизвестен.
AppCurrency currencyByCode(String code) {
  for (final currency in kCurrencies) {
    if (currency.code == code) return currency;
  }
  return kCurrencies.first;
}
