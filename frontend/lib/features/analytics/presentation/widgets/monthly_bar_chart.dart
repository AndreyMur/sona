import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';

/// Один месяц бар-чарта: подпись месяца, сумма и признак текущего месяца.
class BarMonth {
  const BarMonth({
    required this.label,
    required this.value,
    required this.currency,
    required this.current,
  });

  /// Подпись под столбцом: короткое имя месяца («сен»).
  final String label;

  /// Компактная сумма над столбцом («1,5 тыс ₽»).
  final double value;
  final String currency;

  /// Текущий месяц выделяется насыщенным цветом.
  final bool current;
}

/// Бар-чарт динамики трат по месяцам.
///
/// Столбцы собираются виджетами (высота — доля от максимума), поэтому
/// подписи сумм доступны в виджет-тестах. Цвета — токены дизайн-системы:
/// прошлые месяцы приглушённым primary, текущий — полным.
class MonthlyBarChart extends StatelessWidget {
  const MonthlyBarChart({
    super.key,
    required this.months,
    this.chartHeight = 140,
  });

  final List<BarMonth> months;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    final maxValue = months.fold<double>(
      0,
      (max, month) => max > month.value ? max : month.value,
    );

    return SizedBox(
      height: chartHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final month in months)
            Expanded(child: _BarColumn(month: month, maxValue: maxValue)),
        ],
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({required this.month, required this.maxValue});

  final BarMonth month;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final factor = maxValue > 0 ? (month.value / maxValue).clamp(0.0, 1.0) : 0.0;
    final barColor = month.current
        ? AppColors.primary
        : AppColors.primary.withValues(alpha: 0.35);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: Column(
        children: [
          SizedBox(
            height: theme.textTheme.labelSmall!.fontSize! * 1.4,
            child: month.value > 0
                ? Text(
                    SonaFormat.compact(month.value, currency: month.currency),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: factor,
                widthFactor: 0.55,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: factor > 0 ? barColor : Colors.transparent,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadius.sm),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            month.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: month.current
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
