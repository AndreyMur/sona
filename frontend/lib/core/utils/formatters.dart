import 'analytics_math.dart';

/// Форматирование чисел и дат без внешних локалей (детерминированно в тестах).
abstract final class SonaFormat {
  const SonaFormat._();

  static const List<String> _monthsShort = [
    'янв',
    'фев',
    'мар',
    'апр',
    'мая',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];

  static const List<String> _monthsFull = [
    'январь',
    'февраль',
    'март',
    'апрель',
    'май',
    'июнь',
    'июль',
    'август',
    'сентябрь',
    'октябрь',
    'ноябрь',
    'декабрь',
  ];

  /// «2 300 ₽».
  static String amount(double value, {String currency = '₽'}) {
    final rounded = value.round();
    final sign = rounded < 0 ? '−' : '';
    final digits = rounded.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return '$sign$buffer $currency';
  }

  /// «29 сен».
  static String dateShort(DateTime date) {
    return '${date.day} ${_monthsShort[date.month - 1]}';
  }

  /// «сен» — короткое имя месяца по номеру.
  static String monthShort(int month) => _monthsShort[month - 1];

  /// «сентябрь» — полное имя месяца по номеру.
  static String monthName(int month) => _monthsFull[month - 1];

  /// Подпись периода аналитики: «28 сен – 4 окт», «сентябрь 2026», «2026».
  static String periodCaption(PeriodRange range, AnalyticsPeriod period) {
    final lastDay = range.to.subtract(const Duration(microseconds: 1));
    return switch (period) {
      AnalyticsPeriod.week ||
      AnalyticsPeriod.custom =>
        range.from.month == lastDay.month
            ? '${range.from.day} – ${lastDay.day} ${_monthsShort[lastDay.month - 1]}'
            : '${dateShort(range.from)} – ${dateShort(lastDay)}',
      AnalyticsPeriod.month => '${_monthsFull[range.from.month - 1]} ${range.from.year}',
      AnalyticsPeriod.year => '${range.from.year}',
    };
  }

  /// «00:07».
  static String timer(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
