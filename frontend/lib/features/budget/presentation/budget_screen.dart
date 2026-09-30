import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/budget_math.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../domain/models/app_settings.dart';
import '../../../domain/models/category.dart';
import 'widgets/donut_chart.dart';

/// Экран бюджета: карточка месячного бюджета, пончик-диаграмма
/// распределения трат и список категорий с лимитами и прогрессом.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cycle = ref.watch(budgetCycleProvider);
    final categories = ref.watch(categoriesProvider);
    final expenseGroups = ref.watch(monthlyExpensesByCategoryProvider);
    final subExpenseGroups = ref.watch(monthlyExpensesBySubcategoryProvider);
    final spent = ref.watch(monthlyExpenseProvider);

    return GradientScaffold(
      appBar: AppBar(title: const Text('Бюджет')),
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
            _BudgetHeaderCard(cycle: cycle, spent: spent),
            const SizedBox(height: AppSpacing.md),
            _CategoryBreakdownCard(groups: expenseGroups, spent: spent),
            const SizedBox(height: AppSpacing.lg),
            Text('Лимиты по категориям', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            categories.when(
              data: (list) {
                final expenseCategories =
                    list.where((c) => !c.isIncome).toList();
                if (expenseCategories.isEmpty) {
                  return Text(
                    'Нет категорий расходов',
                    style: theme.textTheme.bodyMedium,
                  );
                }
                return Column(
                  children: [
                    for (final category in expenseCategories)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _LimitCard(
                          category: category,
                          cycle: cycle.asData?.value ?? BudgetCycle.none,
                          categorySpent:
                              expenseGroups.asData?.value[category.name] ?? 0,
                          subcategorySpent: subExpenseGroups.asData?.value ?? {},
                          currency: ref.watch(currencyProvider).symbol,
                          thresholds: ref.watch(alertThresholdsProvider),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, _) => Text(
                'Не удалось загрузить категории',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Карточка месячного бюджета: эффективный бюджет, прогресс, прогноз
/// и настройки порогов/переноса.
class _BudgetHeaderCard extends ConsumerWidget {
  const _BudgetHeaderCard({required this.cycle, required this.spent});

  final AsyncValue<BudgetCycle> cycle;
  final AsyncValue<double> spent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;
    final currency = ref.watch(currencyProvider).symbol;
    final thresholds = ref.watch(alertThresholdsProvider);

    final settled = cycle.asData?.value;
    final budget = settled == null || settled.monthlyBudget <= 0
        ? null
        : settled.total;
    final value = spent.asData?.value ?? 0;
    final percent = BudgetMath.budgetRatioPercent(value, budget ?? 0);
    final progress = BudgetMath.budgetProgress(value, budget ?? 0);
    final tone = BudgetMath.budgetTone(value, budget ?? 0, thresholds);

    final forecast = BudgetMath.forecastSpending(value, DateTime.now());
    final remaining = BudgetMath.budgetRemaining(budget ?? 0, value);
    final allowance = BudgetMath.dailyAllowance(remaining, DateTime.now());

    final progressColor = switch (tone) {
      BudgetTone.danger => theme.colorScheme.error,
      BudgetTone.warn => sona.warning,
      BudgetTone.ok => sona.income,
    };

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
                    'Бюджет месяца',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Изменить бюджет',
                  icon: Icon(
                    Icons.edit_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => _editBudget(
                    context,
                    ref,
                    settled ?? BudgetCycle.none,
                    thresholds,
                  ),
                ),
              ],
            ),
            if (budget == null)
              Text(
                'Бюджет не задан. Установите его, чтобы следить за лимитом.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              Text(
                SonaFormat.amount(budget, currency: currency),
                style: theme.textTheme.displayLarge,
              ),
              if (settled != null &&
                  settled.carryOverEnabled &&
                  settled.carryOver > 0) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Перенесено с прошлого месяца: '
                  '${SonaFormat.amount(settled.carryOver, currency: currency)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                color: progressColor,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Потрачено ${SonaFormat.amount(value, currency: currency)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '${percent.round()}%',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: tone == BudgetTone.ok
                          ? theme.colorScheme.onSurface
                          : progressColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                remaining >= 0
                    ? 'Осталось ${SonaFormat.amount(remaining, currency: currency)}, в день ~${SonaFormat.amount(allowance, currency: currency)}'
                    : 'Бюджет превышен на ${SonaFormat.amount(-remaining, currency: currency)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: remaining >= 0
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Прогноз к концу месяца: '
                '${SonaFormat.amount(forecast, currency: currency)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editBudget(
    BuildContext context,
    WidgetRef ref,
    BudgetCycle cycle,
    List<int> thresholds,
  ) async {
    final settings = AppSettings(
      monthlyBudget: cycle.monthlyBudget,
      alertThresholds: thresholds,
      carryOverEnabled: cycle.carryOverEnabled,
    );
    final result = await showDialog<BudgetDraft>(
      context: context,
      builder: (_) => BudgetDraftDialog(initial: settings),
    );
    if (result == null) return;
    final controller = ref.read(appSettingsProvider.notifier);
    await controller.setMonthlyBudget(result.budget);
    await controller.setAlertThresholds(result.thresholds);
    await controller.setCarryOverEnabled(result.carryOver);
  }
}

/// Черновик диалога редактирования бюджета.
class BudgetDraft {
  const BudgetDraft({
    required this.budget,
    required this.thresholds,
    required this.carryOver,
  });

  final double? budget;
  final List<int> thresholds;
  final bool carryOver;
}

/// Диалог редактирования бюджета: сумма, пороги 50/80/100% и перенос.
class BudgetDraftDialog extends StatefulWidget {
  const BudgetDraftDialog({super.key, required this.initial});

  final AppSettings initial;

  @override
  State<BudgetDraftDialog> createState() => _BudgetDraftDialogState();
}

class _BudgetDraftDialogState extends State<BudgetDraftDialog> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.initial.monthlyBudget == null
        ? ''
        : (widget.initial.monthlyBudget!).round().toString(),
  );
  late final Set<int> _thresholds = {...widget.initial.alertThresholds};
  late bool _carryOver = widget.initial.carryOverEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Бюджет месяца'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(hintText: 'Например: 50000'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Предупреждать при:', style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xxs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final threshold in const [50, 80, 100])
                  FilterChip(
                    label: Text('$threshold%'),
                    selected: _thresholds.contains(threshold),
                    onSelected: (selected) => setState(() {
                      selected
                          ? _thresholds.add(threshold)
                          : _thresholds.remove(threshold);
                    }),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                'Переносить остаток',
                style: theme.textTheme.bodyLarge,
              ),
              subtitle: Text(
                'Неизрасходованный остаток перейдёт в новый месяц',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              value: _carryOver,
              onChanged: (value) => setState(() => _carryOver = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            BudgetDraft(
              budget: _parseBudget(),
              thresholds: _thresholds.toList(),
              carryOver: _carryOver,
            ),
          ),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }

  double? _parseBudget() {
    final raw = _amount.text.replaceAll(',', '.').trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }
}

/// Пончик-диаграмма расходов по категориям с легендой.
class _CategoryBreakdownCard extends ConsumerWidget {
  const _CategoryBreakdownCard({
    required this.groups,
    required this.spent,
  });

  final AsyncValue<Map<String, double>> groups;
  final AsyncValue<double> spent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currency = ref.watch(currencyProvider).symbol;
    final entries = (groups.asData?.value ?? {})
        .entries
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = spent.asData?.value ?? entries.fold<double>(0, (s, e) => s + e.value);

    final slices = <DonutSlice>[];
    final legend = <MapEntry<String, double>>[];
    if (entries.isNotEmpty) {
      final top = entries.take(4).toList();
      for (var i = 0; i < top.length; i++) {
        slices.add(
          DonutSlice(
            label: top[i].key,
            value: top[i].value,
            color: kDonutPalette[i % kDonutPalette.length],
          ),
        );
        legend.add(top[i]);
      }
      final rest = entries.skip(4).toList();
      if (rest.isNotEmpty) {
        final restSum = rest.fold<double>(0, (s, e) => s + e.value);
        slices.add(
          DonutSlice(
            label: 'Прочее',
            value: restSum,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        );
        legend.add(MapEntry('Прочее', restSum));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Расходы по категориям', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            if (legend.isEmpty)
              Text(
                'В этом месяце пока нет расходов',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              Center(
                child: DonutChart(
                  slices: slices,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        SonaFormat.amount(total, currency: currency),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        'за месяц',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final entry in legend)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                  child: Row(
                    children: [
                      LegendDot(
                        color: slices
                            .firstWhere((slice) => slice.label == entry.key)
                            .color,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${SonaFormat.amount(entry.value, currency: currency)}'
                        '${total > 0 ? ' · ${(entry.value / total * 100).round()}%' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Карточка категории с лимитом и прогрессом расхода.
class _LimitCard extends ConsumerStatefulWidget {
  const _LimitCard({
    required this.category,
    required this.cycle,
    required this.categorySpent,
    required this.subcategorySpent,
    required this.currency,
    required this.thresholds,
  });

  final Category category;
  final BudgetCycle cycle;
  final double categorySpent;
  final Map<String, double> subcategorySpent;
  final String currency;
  final List<int> thresholds;

  @override
  ConsumerState<_LimitCard> createState() => _LimitCardState();
}

class _LimitCardState extends ConsumerState<_LimitCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;
    final limits = ref.watch(categoryLimitsProvider);
    final limit = limits[widget.category.name];

    return Card(
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => _editLimit(null, null),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: sona.accentSoft,
                child: Text(
                  widget.category.name.characters.first.toUpperCase(),
                  style: TextStyle(color: sona.onAccentSoft),
                ),
              ),
              title: Text(widget.category.name, style: theme.textTheme.titleMedium),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: _LimitProgress(
                  spent: widget.categorySpent,
                  limit: limit,
                  currency: widget.currency,
                  thresholds: widget.thresholds,
                ),
              ),
              trailing: IconButton(
                tooltip: 'Лимит категории',
                icon: Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ),
          ),
          if (_expanded && widget.category.subcategories.isNotEmpty)
            Divider(indent: AppSpacing.lg),
          if (_expanded)
            for (final sub in widget.category.subcategories)
              ListTile(
                contentPadding: const EdgeInsets.only(left: AppSpacing.xl),
                title: Text(sub, style: theme.textTheme.bodyLarge),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: _LimitProgress(
                    spent: widget.subcategorySpent[
                            subcategoryLimitKey(widget.category.name, sub)] ??
                        0,
                    limit: limits[
                        subcategoryLimitKey(widget.category.name, sub)],
                    currency: widget.currency,
                    thresholds: widget.thresholds,
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Лимит подкатегории',
                  icon: Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => _editLimit(widget.category.name, sub),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _editLimit(String? categoryOverride, String? subcategory) async {
    final category = categoryOverride ?? widget.category.name;
    final key = subcategory == null
        ? category
        : subcategoryLimitKey(category, subcategory);
    final current = ref.read(categoryLimitsProvider)[key];

    final result = await showDialog<double>(
      context: context,
      builder: (_) => _LimitInputDialog(
        title: subcategory == null
            ? 'Лимит «$category»'
            : 'Лимит «$category · $subcategory»',
        initial: current,
      ),
    );
    if (result == null || !mounted) return;
    await ref
        .read(appSettingsProvider.notifier)
        .setCategoryLimit(key, result <= 0 ? null : result);
  }
}

/// Прогресс расхода относительно лимита категории/подкатегории.
class _LimitProgress extends StatelessWidget {
  const _LimitProgress({
    required this.spent,
    required this.limit,
    required this.currency,
    required this.thresholds,
  });

  final double spent;
  final double? limit;
  final String currency;
  final List<int> thresholds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;

    final Widget primaryText;
    final Widget? progressLine;
    final double? limitValue = limit;
    if (limitValue == null || limitValue <= 0) {
      primaryText = Text(
        '${SonaFormat.amount(spent, currency: currency)} · лимит не задан',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
      progressLine = null;
    } else {
      final percent = BudgetMath.budgetRatioPercent(spent, limitValue);
      final tone = BudgetMath.budgetTone(spent, limitValue, thresholds);
      final color = switch (tone) {
        BudgetTone.danger => theme.colorScheme.error,
        BudgetTone.warn => sona.warning,
        BudgetTone.ok => sona.income,
      };
      primaryText = Row(
        children: [
          Expanded(
            child: Text(
              '${SonaFormat.amount(spent, currency: currency)} из '
              '${SonaFormat.amount(limitValue, currency: currency)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            '${percent.round()}%',
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      );
      progressLine = Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xxs),
        child: LinearProgressIndicator(
          value: BudgetMath.budgetProgress(spent, limitValue),
          minHeight: 5,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          color: color,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [primaryText, ?progressLine],
    );
  }
}

/// Диалог ввода лимита (пустая строка — снять лимит).
class _LimitInputDialog extends StatefulWidget {
  const _LimitInputDialog({required this.title, required this.initial});

  final String title;
  final double? initial;

  @override
  State<_LimitInputDialog> createState() => _LimitInputDialogState();
}

class _LimitInputDialogState extends State<_LimitInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial == null ? '' : widget.initial!.round().toString(),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(hintText: 'Например: 15000'),
        onSubmitted: (_) => Navigator.of(context).pop(_parsed()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        if (widget.initial != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(0.0),
            child: const Text('Снять лимит'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_parsed()),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }

  double? _parsed() {
    final raw = _controller.text.replaceAll(',', '.').trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
