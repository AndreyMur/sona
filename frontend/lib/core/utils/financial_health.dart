import 'package:flutter/foundation.dart';

/// Оценка «Финансовое здоровье» (0–100) и её текстовая интерпретация.
///
/// Скоринг собирается из трёх независимых компонент (ТЗ, профиль):
/// * норма сбережений — 50 баллов;
/// * соблюдение месячного бюджета — 30 баллов;
/// * регулярность учёта — 20 баллов.
///
/// Значение детерминировано и не зависит от текущего времени, поэтому
/// пригодно для покрытия тестами.
@immutable
class FinancialHealth {
  const FinancialHealth({
    required this.score,
    required this.savingsScore,
    required this.budgetScore,
    required this.activityScore,
    required this.hasIncome,
    required this.hasBudget,
  });

  /// Итоговый балл 0–100.
  final int score;

  /// Вклад компоненты сбережений (0–50).
  final int savingsScore;

  /// Вклад компоненты бюджета (0–30).
  final int budgetScore;

  /// Вклад компоненты активности (0–20).
  final int activityScore;

  /// Был ли доход за период (иначе норма сбережений не считается).
  final bool hasIncome;

  /// Задан ли месячный бюджет.
  final bool hasBudget;

  /// Текстовая оценка итогового балла.
  String get label => financialHealthLabel(score);
}

/// Текстовая интерпретация балла «Финансовое здоровье».
String financialHealthLabel(int score) {
  if (score >= 80) return 'Отлично';
  if (score >= 60) return 'Хорошо';
  if (score >= 40) return 'Средне';
  return 'Требует внимания';
}

/// Верхняя граница вклада компонент скоринга.
const int kHealthSavingsMax = 50;
const int kHealthBudgetMax = 30;
const int kHealthActivityMax = 20;

/// Число операций за месяц, дающее максимальный балл активности.
const int kHealthActivityTarget = 20;

/// Целевая норма сбережений (доля дохода), за которую даётся максимум.
const double kHealthSavingsTarget = 0.3;

/// Считает скоринг «Финансовое здоровье».
///
/// * [monthlyIncome] — доход за текущий месяц;
/// * [monthlyExpense] — расход за текущий месяц;
/// * [monthlyBudget] — заданный месячный бюджет или `null`;
/// * [operationsThisMonth] — число операций за текущий месяц.
FinancialHealth computeFinancialHealth({
  required double monthlyIncome,
  required double monthlyExpense,
  double? monthlyBudget,
  required int operationsThisMonth,
}) {
  final hasIncome = monthlyIncome > 0;
  final hasBudget = monthlyBudget != null && monthlyBudget > 0;

  final savingsScore = _savingsComponent(
    income: monthlyIncome,
    expense: monthlyExpense,
    hasBudget: hasBudget,
    budget: monthlyBudget ?? 0,
  );
  final budgetScore = _budgetComponent(
    expense: monthlyExpense,
    budget: monthlyBudget ?? 0,
    hasBudget: hasBudget,
  );
  final activityScore = _activityComponent(operationsThisMonth);

  final total = (savingsScore + budgetScore + activityScore).clamp(0, 100).toInt();
  return FinancialHealth(
    score: total,
    savingsScore: savingsScore,
    budgetScore: budgetScore,
    activityScore: activityScore,
    hasIncome: hasIncome,
    hasBudget: hasBudget,
  );
}

int _savingsComponent({
  required double income,
  required double expense,
  required bool hasBudget,
  required double budget,
}) {
  if (income > 0) {
    final rate = (income - expense) / income;
    final normalized = (rate / kHealthSavingsTarget).clamp(0.0, 1.0);
    return (normalized * kHealthSavingsMax).round();
  }
  // Без дохода оцениваем бережливость относительно бюджета, если он задан.
  if (hasBudget) {
    final rate = (budget - expense) / budget;
    final normalized = (rate / kHealthSavingsTarget).clamp(0.0, 1.0);
    return (normalized * kHealthSavingsMax).round();
  }
  return 0;
}

int _budgetComponent({
  required double expense,
  required double budget,
  required bool hasBudget,
}) {
  if (!hasBudget) return 0;
  final ratio = expense / budget;
  if (ratio <= 0.8) return kHealthBudgetMax;
  if (ratio <= 1.0) {
    // 80–100% — линейное снижение с 30 до 15 баллов.
    final t = (ratio - 0.8) / 0.2;
    return (kHealthBudgetMax - t * (kHealthBudgetMax / 2)).round();
  }
  // Перерасход — быстрый спад до нуля к 150% бюджета.
  final t = ((ratio - 1.0) / 0.5).clamp(0.0, 1.0);
  return ((kHealthBudgetMax / 2) * (1 - t)).round();
}

int _activityComponent(int operationsThisMonth) {
  final normalized =
      (operationsThisMonth / kHealthActivityTarget).clamp(0.0, 1.0);
  return (normalized * kHealthActivityMax).round();
}
