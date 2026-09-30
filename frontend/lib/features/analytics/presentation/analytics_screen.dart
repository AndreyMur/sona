import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/analytics_math.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../budget/presentation/widgets/donut_chart.dart';
import 'widgets/monthly_bar_chart.dart';

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
            const SizedBox(height: AppSpacing.md),
            if (selection.period == AnalyticsPeriod.custom)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _CustomPeriodCard(selection: selection),
              ),
            _MonthlyTrendCard(overview: overview),
            const SizedBox(height: AppSpacing.md),
            _TopCategoriesCard(overview: overview),
            const SizedBox(height: AppSpacing.md),
            _CategoryFilterCard(overview: overview),
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
            '${flat ? '' : rising ? '+' : '−'}${change.abs()}%'
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

/// Карточка бар-чарта динамики трат по месяцам.
class _MonthlyTrendCard extends ConsumerWidget {
  const _MonthlyTrendCard({required this.overview});

  final AsyncValue<AnalyticsOverview> overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currency = ref.watch(currencyProvider).symbol;
    final now = DateTime.now();
    final data = overview.asData?.value;
    final months = data?.months ?? [];

    final bars = [
      for (final bucket in months)
        BarMonth(
          label: SonaFormat.monthShort(bucket.month.month),
          value: bucket.amount,
          currency: currency,
          current:
              bucket.month.year == now.year && bucket.month.month == now.month,
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('По месяцам', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            MonthlyBarChart(months: bars),
          ],
        ),
      ),
    );
  }
}

/// Карточка топ категорий выбранного периода.
class _TopCategoriesCard extends ConsumerWidget {
  const _TopCategoriesCard({required this.overview});

  final AsyncValue<AnalyticsOverview> overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currency = ref.watch(currencyProvider).symbol;
    final data = overview.asData?.value;
    final shares = data?.topCategories ?? const <CategoryShare>[];
    final total = data?.total ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Топ категорий', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            if (shares.isEmpty)
              Text(
                'Нет расходов за период',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (var i = 0; i < shares.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _CategoryShareRow(
                    share: shares[i],
                    total: total,
                    currency: currency,
                    color: kDonutPalette[i % kDonutPalette.length],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Строка топа категорий: метка цвета, название, сумма, доля и прогресс.
class _CategoryShareRow extends StatelessWidget {
  const _CategoryShareRow({
    required this.share,
    required this.total,
    required this.currency,
    required this.color,
  });

  final CategoryShare share;
  final double total;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;
    final fraction = total > 0 ? (share.amount / total).clamp(0.0, 1.0) : 0.0;
    final percent = (fraction * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            LegendDot(color: color),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                share.category,
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${SonaFormat.amount(share.amount, currency: currency)}'
              '${total > 0 ? ' · $percent%' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        LinearProgressIndicator(
          value: fraction,
          minHeight: 5,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          color: color,
          backgroundColor: sona.accentSoft.withValues(alpha: 0.4),
        ),
      ],
    );
  }
}

/// Карточка произвольного периода: выбор диапазона дат календарём.
class _CustomPeriodCard extends ConsumerWidget {
  const _CustomPeriodCard({required this.selection});

  final AnalyticsSelection selection;

  Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final current = selection.customRange ??
        selection.rangeFor(now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: current.from, end: current.to),
    );
    if (picked == null || !context.mounted) return;
    ref.read(analyticsSelectionProvider.notifier).setCustomRange(
          PeriodRange(
            from: AnalyticsMath.stripTime(picked.start),
            to: AnalyticsMath.stripTime(picked.end).add(const Duration(days: 1)),
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final caption = SonaFormat.periodCaption(
      selection.rangeFor(DateTime.now()),
      AnalyticsPeriod.custom,
    );

    return Card(
      child: InkWell(
        onTap: () => _pickRange(context, ref),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.lg,
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Диапазон: $caption',
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Фильтр аналитики по категориям периода: чипы категорий.
/// Пустое множество в выборе — показываются все категории.
class _CategoryFilterCard extends ConsumerWidget {
  const _CategoryFilterCard({required this.overview});

  final AsyncValue<AnalyticsOverview> overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;
    final selection = ref.watch(analyticsSelectionProvider);
    final categories = (overview.asData?.value.categories ?? const {})
        .keys
        .toList()
      ..sort();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Фильтр по категориям',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (selection.filtersCategories)
                  IconButton(
                    tooltip: 'Сбросить фильтр',
                    icon: Icon(
                      Icons.filter_alt_off_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => ref
                        .read(analyticsSelectionProvider.notifier)
                        .clearCategories(),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (categories.isEmpty)
              Text(
                'За период нет расходов',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final category in categories)
                    FilterChip(
                      label: Text(category),
                      selected:
                          selection.categories.contains(category),
                      onSelected: (_) => ref
                          .read(analyticsSelectionProvider.notifier)
                          .toggleCategory(category),
                    ),
                ],
              ),
            if (selection.filtersCategories) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Показаны: ${selection.categories.length} из ${categories.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: sona.onAccentSoft,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
