import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/budget_math.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../domain/models/operation.dart';
import '../../record/presentation/widgets/pulsing_mic_button.dart';

/// Советы дня: ротация по номеру дня в году.
const List<String> kDailyTips = [
  'Записывайте траты сразу — так проще держать бюджет в руках.',
  'Проверяйте категории раз в неделю: точные категории — точная статистика.',
  'Задайте месячный бюджет — Sona предупредит, когда вы приблизитесь к лимиту.',
  'Добавляйте крупные покупки в тот же день, чтобы статистика не искажалась.',
  'Называйте покупку голосом — быстрее, чем набирать руками.',
  'Раз в неделю заглядывайте в категории: они учатся на ваших правках.',
];

String dailyTip([DateTime? now]) {
  final date = now ?? DateTime.now();
  final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
  return kDailyTips[dayOfYear % kDailyTips.length];
}

String greetingForNow([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour < 6) return 'Доброй ночи';
  if (hour < 12) return 'Доброе утро';
  if (hour < 18) return 'Добрый день';
  return 'Добрый вечер';
}

/// Главная: приветствие, карточка баланса, кнопка «Сказать», быстрые
/// действия, мини-прогресс бюджета, последние операции и совет дня.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recent = ref.watch(recentOperationsProvider);
    final balance = ref.watch(balanceProvider);
    final monthIncome = ref.watch(monthlyIncomeProvider);
    final monthExpense = ref.watch(monthlyExpenseProvider);
    final cycle = ref.watch(budgetCycleProvider).asData?.value;
    final currency = ref.watch(currencyProvider);

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Sona'),
        actions: [
          IconButton(
            tooltip: 'Профиль',
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () => context.push(AppRoutes.profile),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                greetingForNow(),
                style: theme.textTheme.displayMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              _BalanceCard(
                balance: balance.asData?.value,
                monthIncome: monthIncome.asData?.value,
                monthExpense: monthExpense.asData?.value,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: PulsingMicButton(
                  onPressed: () => context.push(AppRoutes.record),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.keyboard_rounded,
                      label: 'Написать',
                      onTap: () => context.push('${AppRoutes.record}?mode=text'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.category_rounded,
                      label: 'Категории',
                      onTap: () => context.push(AppRoutes.categories),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.savings_rounded,
                      label: 'Бюджет',
                      onTap: () => context.push(AppRoutes.budget),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.query_stats_rounded,
                      label: 'Аналитика',
                      onTap: () => context.push(AppRoutes.analytics),
                    ),
                  ),
                ],
              ),
              if (cycle != null && cycle.monthlyBudget > 0) ...[
                const SizedBox(height: AppSpacing.md),
                _BudgetProgressCard(
                  budget: cycle.total,
                  spent: monthExpense.asData?.value,
                  currencySymbol: currency.symbol,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Последние операции',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              recent.when(
                data: (operations) => operations.isEmpty
                    ? Text(
                        'Пока нет операций. Скажите, что потратили!',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Column(
                        children: [
                          for (final operation in operations.take(5))
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: _OperationTile(
                                operation: operation,
                                currencySymbol: currency.symbol,
                              ),
                            ),
                        ],
                      ),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (_, _) => Text(
                  'Не удалось загрузить операции',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const _TipCard(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Карточка баланса: общий баланс и доходы/расходы месяца.
class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({
    required this.balance,
    required this.monthIncome,
    required this.monthExpense,
  });

  final double? balance;
  final double? monthIncome;
  final double? monthExpense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;
    final currency = ref.watch(currencyProvider);
    final formatted = SonaFormat.amount(balance ?? 0, currency: currency.symbol);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Баланс',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(formatted, style: theme.textTheme.displayLarge),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.arrow_downward_rounded,
                  size: 16,
                  color: sona.income,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Flexible(
                  child: Text(
                    '+${SonaFormat.amount(monthIncome ?? 0, currency: currency.symbol)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: sona.income,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Icon(
                  Icons.arrow_upward_rounded,
                  size: 16,
                  color: sona.expense,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Flexible(
                  child: Text(
                    '−${SonaFormat.amount(monthExpense ?? 0, currency: currency.symbol)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'доходы и расходы за этот месяц',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Карточка быстрого действия.
class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: sona.onAccentSoft),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Мини-прогресс бюджета месяца. Тап открывает экран бюджета.
class _BudgetProgressCard extends ConsumerWidget {
  const _BudgetProgressCard({
    required this.budget,
    required this.spent,
    required this.currencySymbol,
  });

  final double budget;
  final double? spent;
  final String currencySymbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;
    final thresholds = ref.watch(alertThresholdsProvider);
    final value = spent ?? 0;
    final percent = BudgetMath.budgetProgress(value, budget);
    final percentLabel = BudgetMath.budgetRatioPercent(value, budget).round();
    final tone = BudgetMath.budgetTone(value, budget, thresholds);
    final accentColor = switch (tone) {
      BudgetTone.danger => theme.colorScheme.error,
      BudgetTone.warn => sona.warning,
      BudgetTone.ok => sona.income,
    };
    final percentColor = tone == BudgetTone.ok
        ? theme.colorScheme.onSurface
        : accentColor;

    return Card(
      child: InkWell(
        onTap: () => context.push(AppRoutes.budget),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child:
                        Text('Бюджет месяца', style: theme.textTheme.titleMedium),
                  ),
                  Text(
                    '$percentLabel%',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: percentColor,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(
                value: percent,
                minHeight: 8,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                color: accentColor,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${SonaFormat.amount(value, currency: currencySymbol)} из '
                '${SonaFormat.amount(budget, currency: currencySymbol)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (value >= budget) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Бюджет превышен',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Совет дня.
class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;

    return Card(
      color: sona.accentSoft,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.tips_and_updates_rounded, size: 20, color: sona.onAccentSoft),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Совет дня', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    dailyTip(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: sona.onAccentSoft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Плитка последней операции.
class _OperationTile extends StatelessWidget {
  const _OperationTile({
    required this.operation,
    required this.currencySymbol,
  });

  final Operation operation;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;
    final isIncome = operation.type == OperationType.income;
    final title =
        operation.subcategory == null || operation.subcategory!.isEmpty
        ? operation.category
        : '${operation.category} · ${operation.subcategory}';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: sona.accentSoft,
          radius: 20,
          child: Icon(
            isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            size: 20,
            color: sona.onAccentSoft,
          ),
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(SonaFormat.dateShort(operation.date)),
        trailing: Text(
          SonaFormat.amount(
            isIncome ? operation.amount : -operation.amount,
            currency: currencySymbol,
          ),
          style: theme.textTheme.titleMedium?.copyWith(
            color: isIncome ? sona.income : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
