import 'package:flutter_test/flutter_test.dart';
import 'package:sona/core/utils/financial_health.dart';

void main() {
  group('computeFinancialHealth', () {
    test('сбережения, бюджет и активность дают максимум баллов', () {
      final health = computeFinancialHealth(
        monthlyIncome: 100000,
        monthlyExpense: 50000,
        monthlyBudget: 100000,
        operationsThisMonth: kHealthActivityTarget,
      );

      expect(health.score, 100);
      expect(health.savingsScore, kHealthSavingsMax);
      expect(health.budgetScore, kHealthBudgetMax);
      expect(health.activityScore, kHealthActivityMax);
      expect(health.label, 'Отлично');
    });

    test('без дохода, бюджета и операций — нулевой балл', () {
      final health = computeFinancialHealth(
        monthlyIncome: 0,
        monthlyExpense: 0,
        operationsThisMonth: 0,
      );

      expect(health.score, 0);
      expect(health.hasIncome, isFalse);
      expect(health.hasBudget, isFalse);
      expect(health.label, 'Требует внимания');
    });

    test('норма сбережений растёт до целевой и выше не считается', () {
      final below = computeFinancialHealth(
        monthlyIncome: 100000,
        monthlyExpense: 80000, // 20% — две трети цели
        operationsThisMonth: 0,
      );
      final above = computeFinancialHealth(
        monthlyIncome: 100000,
        monthlyExpense: 50000, // 50% — выше цели 30%
        operationsThisMonth: 0,
      );

      expect(below.savingsScore, lessThan(kHealthSavingsMax));
      expect(above.savingsScore, kHealthSavingsMax);
    });

    test('перерасход бюджета обнуляет бюджетную компоненту', () {
      final health = computeFinancialHealth(
        monthlyIncome: 100000,
        monthlyExpense: 150000,
        monthlyBudget: 100000,
        operationsThisMonth: 5,
      );

      expect(health.savingsScore, 0);
      expect(health.budgetScore, 0);
      expect(health.activityScore, 5);
      expect(health.score, 5);
    });

    test('бюджет в пределах 80% сохраняет максимум компоненты', () {
      final health = computeFinancialHealth(
        monthlyIncome: 0,
        monthlyExpense: 80000,
        monthlyBudget: 100000,
        operationsThisMonth: 0,
      );

      expect(health.budgetScore, kHealthBudgetMax);
    });

    test('активность пропорциональна числу операций', () {
      final half = computeFinancialHealth(
        monthlyIncome: 0,
        monthlyExpense: 0,
        operationsThisMonth: kHealthActivityTarget ~/ 2,
      );
      expect(half.activityScore, kHealthActivityMax ~/ 2);

      final overflow = computeFinancialHealth(
        monthlyIncome: 0,
        monthlyExpense: 0,
        operationsThisMonth: 1000,
      );
      expect(overflow.activityScore, kHealthActivityMax);
    });

    test('подписи соответствуют диапазонам баллов', () {
      expect(financialHealthLabel(80), 'Отлично');
      expect(financialHealthLabel(60), 'Хорошо');
      expect(financialHealthLabel(40), 'Средне');
      expect(financialHealthLabel(39), 'Требует внимания');
    });
  });
}
