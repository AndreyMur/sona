import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/analytics_math.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gradient_scaffold.dart';

/// Экран аналитики: табы периодов (Неделя / Месяц / Год / Период),
/// сумма трат с процентом к прошлому периоду, бар-чарт по месяцам,
/// топ категорий и фильтры.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(analyticsSelectionProvider);
    final overview = ref.watch(analyticsOverviewProvider);

    return GradientScaffold(
      appBar: AppBar(title: const Text('Аналитика')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PeriodTabs(
              selected: selection.period,
              onSelect: (period) => ref
                  .read(analyticsSelectionProvider.notifier)
                  .setPeriod(period),
            ),
            const SizedBox(height: AppSpacing.md),
            _SpendSummaryCard(selection: selection, overview: overview),
          ],
        ),
      ),
    );
  }
}

/// Переключатель периодов аналитики: Неделя / Месяц / Год / Период.
class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.selected, required this.onSelect});

  final AnalyticsPeriod selected;
  final ValueChanged<AnalyticsPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          for (final period in AnalyticsPeriod.values)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color:
                      period == selected ? sona.accentSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: InkWell(
                  onTap: () => onSelect(period),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      period.label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: period == selected
                            ? sona.onAccentSoft
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight:
                            period == selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Карточка суммы трат за выбранный период и процента к прошлому.
class _SpendSummaryCard extends ConsumerWidget {
  const _SpendSummaryCard({required this.selection, required this.overview});

  final AnalyticsSelection selection;
  final AsyncValue<AnalyticsOverview> overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;
    final currency = ref.watch(currencyProvider).symbol;
    final value = overview.asData?.value;
    final range = selection.rangeFor(DateTime.now());

    final change = value?.percentChange;
    final Widget deltaRow;
    if (change == null) {
      deltaRow = Text(
        'Расходов за период нет',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    } else {
      final rising = change > 0;
      final flat = change == 0;
      final color = flat
          ? theme.colorScheme.onSurfaceVariant
          : rising
              ? theme.colorScheme.error
              : sona.income;
      deltaRow = Row(
        children: [
          if (!flat) ...[
            Icon(
              rising
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 16,
              color: color,
            ),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Text(
            '${rising ? '+' : '−'}${change.abs()}%'
            ' ${selection.period.comparisonLabel}',
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              SonaFormat.periodCaption(range, selection.period),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              SonaFormat.amount(value?.total ?? 0, currency: currency),
              style: theme.textTheme.displayLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            deltaRow,
          ],
        ),
      ),
    );
  }
}
