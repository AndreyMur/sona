import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../domain/models/operation.dart';

/// Главная: заглушка tracer bullet с последними операциями и кнопкой «Сказать».
///
/// Полноценная главная (баланс, бюджет, совет дня) — Фаза 4.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;
    final recent = ref.watch(recentOperationsProvider);

    return GradientScaffold(
      appBar: AppBar(title: const Text('Sona')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Скажи — я запишу', style: theme.textTheme.displayMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Последние операции',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: recent.when(
                  data: (operations) => operations.isEmpty
                      ? Center(
                          child: Text(
                            'Пока нет операций',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: operations.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) =>
                              _OperationTile(operation: operations[index]),
                        ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (_, _) => Center(
                    child: Text(
                      'Не удалось загрузить операции',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: () => context.push(AppRoutes.record),
                icon: Icon(Icons.mic_rounded, color: sona.onAccentSoft),
                label: const Text('Сказать'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationTile extends StatelessWidget {
  const _OperationTile({required this.operation});

  final Operation operation;

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
        leading: Icon(
          isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
          color: sona.onAccentSoft,
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(SonaFormat.dateShort(operation.date)),
        trailing: Text(
          SonaFormat.amount(isIncome ? operation.amount : -operation.amount),
          style: theme.textTheme.titleMedium?.copyWith(
            color: isIncome ? sona.income : sona.expense,
          ),
        ),
      ),
    );
  }
}
