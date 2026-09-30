import 'package:flutter_test/flutter_test.dart';
import 'package:sona/core/utils/budget_math.dart';

void main() {
  group('normalizeThresholds', () {
    test('сортирует и убирает дубликаты и мусор', () {
      expect(
        BudgetMath.normalizeThresholds([100, 50, 80, 50, 120, 0, -10]),
        [50, 80, 100],
      );
    });

    test('пустой набор — пустой список', () {
      expect(BudgetMath.normalizeThresholds(const []), isEmpty);
    });
  });

  group('budgetProgress и проценты', () {
    test('доля клампится в [0..1]', () {
      expect(BudgetMath.budgetProgress(15000, 30000), 0.5);
      expect(BudgetMath.budgetProgress(40000, 30000), 1.0);
      expect(BudgetMath.budgetProgress(0, 30000), 0.0);
    });

    test('нулевой бюджет не делит на ноль', () {
      expect(BudgetMath.budgetProgress(5000, 0), 0.0);
      expect(BudgetMath.budgetRatioPercent(5000, 0), 0.0);
    });

    test('ratioPercent не клампится: превышение видно', () {
      expect(BudgetMath.budgetRatioPercent(31000, 30000), closeTo(103.33, 0.01));
    });
  });

  group('reachedThresholds', () {
    test('достигнутые пороги по возрастанию', () {
      expect(
        BudgetMath.reachedThresholds(16000, 30000, [50, 80, 100]),
        [50],
      );
      expect(
        BudgetMath.reachedThresholds(25000, 30000, [50, 80, 100]),
        [50, 80],
      );
      expect(
        BudgetMath.reachedThresholds(30000, 30000, [50, 80, 100]),
        [50, 80, 100],
      );
      expect(
        BudgetMath.reachedThresholds(31000, 30000, [50, 80, 100]),
        [50, 80, 100],
      );
    });

    test('без бюджета пороги не достигаются', () {
      expect(BudgetMath.reachedThresholds(1000, 0, [50, 80]), isEmpty);
    });
  });

  group('unseenThresholds', () {
    test('возвращает только неуведомлённые', () {
      expect(BudgetMath.unseenThresholds([50, 80, 100], [50]), [80, 100]);
      expect(BudgetMath.unseenThresholds([50, 80], [50, 80, 100]), isEmpty);
    });
  });

  group('budgetTone', () {
    test('ok → warn → danger по настройкам порогов', () {
      expect(
        BudgetMath.budgetTone(10000, 30000, [50, 80, 100]),
        BudgetTone.ok,
      );
      expect(
        BudgetMath.budgetTone(25000, 30000, [50, 80, 100]),
        BudgetTone.warn,
      );
      expect(
        BudgetMath.budgetTone(30000, 30000, [50, 80, 100]),
        BudgetTone.danger,
      );
    });

    test('превышение бюджета всегда danger', () {
      expect(
        BudgetMath.budgetTone(40000, 30000, []),
        BudgetTone.danger,
      );
    });

    test('порог 100 снят — предупреждение остаётся', () {
      expect(
        BudgetMath.budgetTone(40000, 30000, [50, 80]),
        BudgetTone.danger,
      );
      expect(
        BudgetMath.budgetTone(29000, 30000, [50]),
        BudgetTone.warn,
      );
    });
  });

  group('forecastSpending', () {
    test('по средней скорости трат', () {
      // Сентябрь: 30 дней, потрачено 9000 за 15 дней → 18000.
      expect(BudgetMath.forecastSpending(9000, DateTime(2026, 9, 15)), 18000);
    });

    test('первый день месяца проецирует весь объём', () {
      expect(BudgetMath.forecastSpending(1000, DateTime(2026, 10, 1)), 31000);
    });

    test('нулевые траты — нулевой прогноз', () {
      expect(BudgetMath.forecastSpending(0, DateTime(2026, 9, 15)), 0);
    });
  });

  group('остаток и дневной запас', () {
    test('budgetRemaining с перерасходом', () {
      expect(BudgetMath.budgetRemaining(30000, 25000), 5000);
      expect(BudgetMath.budgetRemaining(30000, 31000), -1000);
    });

    test('dailyAllowance делит на оставшиеся дни включительно', () {
      // 25 сентября: осталось 6 дней → 1200 / 6 = 200.
      expect(
        BudgetMath.dailyAllowance(1200, DateTime(2026, 9, 25)),
        closeTo(200, 0.01),
      );
    });

    test('в последний день минимум один день', () {
      expect(
        BudgetMath.dailyAllowance(500, DateTime(2026, 9, 30)),
        closeTo(500, 0.01),
      );
    });
  });

  group('перенос остатка', () {
    test('неиспользованный остаток переходит, перерасход — ноль', () {
      expect(
        BudgetMath.carryOverRemainder(
          monthlyBudget: 30000,
          spent: 27000,
          enabled: true,
        ),
        3000,
      );
      expect(
        BudgetMath.carryOverRemainder(
          monthlyBudget: 30000,
          spent: 31000,
          enabled: true,
        ),
        0,
      );
    });

    test('выключенный перенос и незаданный бюджет дают null', () {
      expect(
        BudgetMath.carryOverRemainder(monthlyBudget: 30000, spent: 1000, enabled: false),
        isNull,
      );
      expect(
        BudgetMath.carryOverRemainder(monthlyBudget: null, spent: 1000, enabled: true),
        isNull,
      );
    });

    test('effectiveBudget учитывает перенос', () {
      expect(
        BudgetMath.effectiveBudget(
          30000,
          carryOverEnabled: true,
          carryOverAmount: 2000,
        ),
        32000,
      );
      expect(
        BudgetMath.effectiveBudget(
          30000,
          carryOverEnabled: false,
          carryOverAmount: 2000,
        ),
        30000,
      );
    });
  });

  group('служебные функции', () {
    test('daysInMonth', () {
      expect(BudgetMath.daysInMonth(2026, 9), 30);
      expect(BudgetMath.daysInMonth(2026, 2), 28);
      expect(BudgetMath.daysInMonth(2028, 2), 29);
    });

    test('monthKey с ведущим нулём', () {
      expect(BudgetMath.monthKey(DateTime(2026, 9, 30)), '2026-09');
      expect(BudgetMath.monthKey(DateTime(2026, 11, 1)), '2026-11');
    });
  });
}
