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

  /// «00:07».
  static String timer(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
