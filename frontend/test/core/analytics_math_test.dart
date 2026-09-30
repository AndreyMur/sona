import 'package:flutter_test/flutter_test.dart';
import 'package:sona/core/utils/analytics_math.dart';

void main() {
  group('rangeFor', () {
    test('неделя начинается с понедельника и длится семь дней', () {
      // Среда 30 сентября 2026.
      final range = AnalyticsMath.rangeFor(
        AnalyticsPeriod.week,
        DateTime(2026, 9, 30, 15, 40),
      );

      expect(range.from, DateTime(2026, 9, 28));
      expect(range.to, DateTime(2026, 10, 5));
      expect(range.contains(DateTime(2026, 9, 28)), isTrue);
      expect(range.contains(DateTime(2026, 10, 4, 23, 59)), isTrue);
      expect(range.contains(DateTime(2026, 10, 5)), isFalse);
    });

    test('понедельник — начало самой себя', () {
      final range = AnalyticsMath.rangeFor(
        AnalyticsPeriod.week,
        DateTime(2026, 9, 28),
      );

      expect(range.from, DateTime(2026, 9, 28));
      expect(range.to, DateTime(2026, 10, 5));
    });

    test('месяц — календарный диапазон', () {
      final range = AnalyticsMath.rangeFor(
        AnalyticsPeriod.month,
        DateTime(2026, 9, 30, 22),
      );

      expect(range.from, DateTime(2026, 9, 1));
      expect(range.to, DateTime(2026, 10, 1));
    });

    test('год — календарный диапазон', () {
      final range = AnalyticsMath.rangeFor(
        AnalyticsPeriod.year,
        DateTime(2026, 9, 30),
      );

      expect(range.from, DateTime(2026, 1, 1));
      expect(range.to, DateTime(2027, 1, 1));
    });

    test('произвольный период использует заданный диапазон', () {
      final custom = PeriodRange(
        from: DateTime(2026, 8, 10),
        to: DateTime(2026, 8, 20),
      );

      final range = AnalyticsMath.rangeFor(
        AnalyticsPeriod.custom,
        DateTime(2026, 9, 30),
        customRange: custom,
      );

      expect(range, custom);
    });

    test('без заданного диапазона — последние 30 дней', () {
      final now = DateTime(2026, 9, 30);

      final range = AnalyticsMath.rangeFor(AnalyticsPeriod.custom, now);

      expect(range.from, DateTime(2026, 8, 31));
      expect(range.to, DateTime(2026, 10, 1));
    });
  });

  group('previousRangeFor', () {
    test('предыдущая неделя той же длины', () {
      final previous = AnalyticsMath.previousRangeFor(
        AnalyticsPeriod.week,
        DateTime(2026, 9, 30),
      );

      expect(previous.from, DateTime(2026, 9, 21));
      expect(previous.to, DateTime(2026, 9, 28));
    });

    test('предыдущий месяц — календарный, даже разной длины', () {
      final previous = AnalyticsMath.previousRangeFor(
        AnalyticsPeriod.month,
        DateTime(2026, 3, 15),
      );

      // Февраль 2026 — 28 дней, но диапазон календарный.
      expect(previous.from, DateTime(2026, 2, 1));
      expect(previous.to, DateTime(2026, 3, 1));
    });

    test('предыдущий год', () {
      final previous = AnalyticsMath.previousRangeFor(
        AnalyticsPeriod.year,
        DateTime(2026, 9, 30),
      );

      expect(previous.from, DateTime(2025, 1, 1));
      expect(previous.to, DateTime(2026, 1, 1));
    });

    test('произвольный период сдвигается назад на свою длину', () {
      final custom = PeriodRange(
        from: DateTime(2026, 8, 10),
        to: DateTime(2026, 8, 25),
      );

      final previous = AnalyticsMath.previousRangeFor(
        AnalyticsPeriod.custom,
        DateTime(2026, 9, 30),
        customRange: custom,
      );

      expect(previous.from, DateTime(2026, 7, 26));
      expect(previous.to, DateTime(2026, 8, 10));
    });
  });

  group('percentageChange', () {
    test('рост и снижение считаются от предыдущего значения', () {
      expect(
        AnalyticsMath.percentageChange(current: 150, previous: 100),
        50,
      );
      expect(
        AnalyticsMath.percentageChange(current: 50, previous: 100),
        -50,
      );
      expect(
        AnalyticsMath.percentageChange(current: 2500, previous: 1000),
        150,
      );
    });

    test('не с чем сравнивать — null', () {
      expect(
        AnalyticsMath.percentageChange(current: 0, previous: 0),
        isNull,
      );
    });

    test('трат раньше не было — рост с нуля равен 100%', () {
      expect(
        AnalyticsMath.percentageChange(current: 500, previous: 0),
        100,
      );
    });

    test('округляется до целого процента', () {
      expect(
        AnalyticsMath.percentageChange(current: 100, previous: 3),
        3233,
      );
    });
  });

  group('labels', () {
    test('периоды называются по-русски', () {
      expect(AnalyticsPeriod.week.label, 'Неделя');
      expect(AnalyticsPeriod.month.label, 'Месяц');
      expect(AnalyticsPeriod.year.label, 'Год');
      expect(AnalyticsPeriod.custom.label, 'Период');
    });

    test('подписи сравнения соответствуют периоду', () {
      expect(AnalyticsPeriod.week.comparisonLabel, 'к прошлой неделе');
      expect(AnalyticsPeriod.month.comparisonLabel, 'к прошлому месяцу');
      expect(AnalyticsPeriod.year.comparisonLabel, 'к прошлому году');
      expect(AnalyticsPeriod.custom.comparisonLabel, 'к прошлому периоду');
    });
  });
}
