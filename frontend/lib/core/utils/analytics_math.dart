/// Чистая математика экрана аналитики: периоды, диапазоны и проценты.
library;

/// Периоды аналитики на экране: табы Неделя / Месяц / Год / Период.
enum AnalyticsPeriod {
  week,
  month,
  year,
  custom;

  /// Заголовок таба.
  String get label => switch (this) {
    AnalyticsPeriod.week => 'Неделя',
    AnalyticsPeriod.month => 'Месяц',
    AnalyticsPeriod.year => 'Год',
    AnalyticsPeriod.custom => 'Период',
  };

  /// Подпись сравнения с предыдущим периодом («+25% к прошлому месяцу»).
  String get comparisonLabel => switch (this) {
    AnalyticsPeriod.week => 'к прошлой неделе',
    AnalyticsPeriod.month => 'к прошлому месяцу',
    AnalyticsPeriod.year => 'к прошлому году',
    AnalyticsPeriod.custom => 'к прошлому периоду',
  };
}

/// Диапазон дат полуоткрытый: включает [from], не включает [to].
///
/// Используется для выборок аналитики (согласовано с репозиторием,
/// где окно дат считается как `[from, to)`).
class PeriodRange {
  const PeriodRange({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  bool contains(DateTime date) =>
      !date.isBefore(from) && date.isBefore(to);

  /// Длина диапазона для сдвига произвольного периода.
  Duration get length => to.difference(from);

  PeriodRange shiftBack() =>
      PeriodRange(from: from.subtract(length), to: from);

  @override
  bool operator ==(Object other) =>
      other is PeriodRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => '[$from, $to)';
}

/// Доля категории в расходах выбранного периода (для топа категорий).
class CategoryShare {
  const CategoryShare({required this.category, required this.amount});

  final String category;
  final double amount;
}

/// Сумма трат за один календарный месяц (для бар-чарта).
class MonthlyBucket {
  const MonthlyBucket({required this.month, required this.amount});

  /// Первый день месяца.
  final DateTime month;
  final double amount;
}

/// Функции агрегации и сравнения периодов.
abstract final class AnalyticsMath {
  const AnalyticsMath._();

  /// Диапазон выбранного периода, содержащий [now].
  ///
  /// Для [AnalyticsPeriod.custom] требует заданный [customRange];
  /// без него возвращается диапазон последних 30 дней.
  static PeriodRange rangeFor(
    AnalyticsPeriod period,
    DateTime now, {
    PeriodRange? customRange,
  }) {
    final moment = stripTime(now);
    return switch (period) {
      AnalyticsPeriod.week => PeriodRange(
        from: startOfWeek(moment),
        to: startOfWeek(moment).add(const Duration(days: 7)),
      ),
      AnalyticsPeriod.month => PeriodRange(
        from: DateTime(moment.year, moment.month),
        to: DateTime(moment.year, moment.month + 1),
      ),
      AnalyticsPeriod.year => PeriodRange(
        from: DateTime(moment.year),
        to: DateTime(moment.year + 1),
      ),
      AnalyticsPeriod.custom => customRange ??
          PeriodRange(
            from: moment.subtract(const Duration(days: 30)),
            to: moment.add(const Duration(days: 1)),
          ),
    };
  }

  /// Предыдущий период непосредственно перед текущим.
  ///
  /// Для месяцев и годов предыдущий период календарный (не сдвиг на длину
  /// текущего: у февраля и високосных годов длина другая). Неделя сдвигается
  /// ровно на семь дней, произвольный период — на свою длину.
  static PeriodRange previousRangeFor(
    AnalyticsPeriod period,
    DateTime now, {
    PeriodRange? customRange,
  }) {
    final moment = stripTime(now);
    return switch (period) {
      AnalyticsPeriod.week => rangeFor(period, moment).shiftBack(),
      AnalyticsPeriod.month => PeriodRange(
        from: DateTime(moment.year, moment.month - 1),
        to: DateTime(moment.year, moment.month),
      ),
      AnalyticsPeriod.year => PeriodRange(
        from: DateTime(moment.year - 1, 1, 1),
        to: DateTime(moment.year, 1, 1),
      ),
      AnalyticsPeriod.custom => (customRange ?? rangeFor(period, moment))
          .shiftBack(),
    };
  }

  /// Изменение величины в процентах: `(current − previous) / previous · 100`.
  ///
  /// Когда сравнивать не с чем (оба нуля) — `null`; когда трат раньше
  /// не было — `100` (рост с нуля отображается как «+100%»).
  static int? percentageChange({
    required double current,
    required double previous,
  }) {
    if (previous <= 0) {
      return current <= 0 ? null : 100;
    }
    return ((current - previous) / previous * 100).round();
  }

  /// Полночь того же дня.
  static DateTime stripTime(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Понедельник недели, к которой относится [date].
  static DateTime startOfWeek(DateTime date) {
    final day = stripTime(date);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }
}
