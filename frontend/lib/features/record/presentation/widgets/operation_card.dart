import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/models/operation.dart';

/// Карточка распознанной операции на экране записи.
class OperationCard extends StatelessWidget {
  const OperationCard({
    super.key,
    required this.operation,
    this.onEdit,
    this.onRemove,
    this.index,
  });

  final ParsedOperation operation;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;
  final int? index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;
    final isIncome = operation.type == OperationType.income;
    final accent = isIncome ? sona.income : sona.expense;

    final title = operation.subcategory == null || operation.subcategory!.isEmpty
        ? operation.category
        : '${operation.category} · ${operation.subcategory}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: sona.accentSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                isIncome
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: sona.onAccentSoft,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        SonaFormat.dateShort(operation.date),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (operation.confidence < 0.7) ...[
                        const SizedBox(width: AppSpacing.xs),
                        _LowConfidenceBadge(color: sona.warning),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              SonaFormat.amount(
                isIncome ? operation.amount : -operation.amount,
              ),
              style: theme.textTheme.titleMedium?.copyWith(color: accent),
            ),
            if (onEdit != null || onRemove != null) ...[
              const SizedBox(width: AppSpacing.xxs),
              PopupMenuButton<String>(
                tooltip: 'Действия',
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onSelected: (value) {
                  if (value == 'edit') onEdit?.call();
                  if (value == 'remove') onRemove?.call();
                },
                itemBuilder: (context) => [
                  if (onEdit != null)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Изменить'),
                    ),
                  if (onRemove != null)
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Удалить'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LowConfidenceBadge extends StatelessWidget {
  const _LowConfidenceBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Низкая уверенность распознавания',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 12, color: color),
            const SizedBox(width: 2),
            Text(
              'Проверьте',
              style: TextStyle(fontSize: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
