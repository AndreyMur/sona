import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../domain/models/subscription.dart';
import '../../../domain/services/purchase_service.dart';

/// Экран Sona Pro: оформление подписки, пробный период, восстановление
/// покупок и настройка качества распознавания.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  SubscriptionPlan _selected = SubscriptionPlan.annual;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionProvider).value ??
        const SubscriptionState();
    final isPro = state.isProAt(DateTime.now());

    return GradientScaffold(
      appBar: AppBar(title: const Text('Sona Pro')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          _HeroCard(state: state),
          const SizedBox(height: AppSpacing.md),
          if (isPro)
            _ProStatusCard(state: state, busy: _busy, onCancel: _cancel)
          else ...[
            _PlanSelector(
              selected: _selected,
              onSelect: (plan) => setState(() => _selected = plan),
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.canStartTrial) ...[
              OutlinedButton.icon(
                onPressed: _busy ? null : _startTrial,
                icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                label: const Text('Попробовать 7 дней бесплатно'),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            FilledButton(
              onPressed: _busy ? null : () => _purchase(_selected),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Оформить · ${_selected.priceLabel}'),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const _FeaturesCard(),
          const SizedBox(height: AppSpacing.md),
          _QualityCard(state: state),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _busy ? null : _restore,
            icon: const Icon(Icons.restore_rounded, size: 20),
            label: const Text('Восстановить покупки'),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Подписка оформляется через магазин приложения. Отменить или '
            'изменить её можно в настройках App Store / Google Play.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _purchase(SubscriptionPlan plan) async {
    setState(() => _busy = true);
    try {
      final result = await ref.read(subscriptionProvider.notifier).purchase(plan);
      if (!mounted) return;
      _showResult(result, successText: 'Sona Pro активирован');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      final result = await ref.read(subscriptionProvider.notifier).restore();
      if (!mounted) return;
      _showResult(result, successText: 'Подписка восстановлена');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startTrial() async {
    setState(() => _busy = true);
    try {
      final started =
          await ref.read(subscriptionProvider.notifier).startTrial();
      if (!mounted) return;
      _snack(
        started
            ? 'Пробный период на 7 дней активирован'
            : 'Пробный период уже использован',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Отменить Sona Pro?'),
        content: const Text(
          'Тариф вернётся к бесплатному: 30 операций в месяц и базовая '
          'статистика.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Оставить'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Отменить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(subscriptionProvider.notifier).cancel();
    if (!mounted) return;
    _snack('Подписка отменена');
  }

  void _showResult(PurchaseResult result, {required String successText}) {
    switch (result.outcome) {
      case PurchaseOutcome.success:
      case PurchaseOutcome.restored:
        _snack(successText);
      case PurchaseOutcome.canceled:
        break;
      case PurchaseOutcome.pending:
        _snack(result.message ?? 'Покупка обрабатывается');
      case PurchaseOutcome.unavailable:
        _snack(result.message ?? 'Покупки недоступны');
      case PurchaseOutcome.error:
        _snack(result.message ?? 'Не удалось выполнить операцию');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Шапка экрана: название, статус и краткое описание тарифа.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.state});

  final SubscriptionState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;
    final isPro = state.isProAt(DateTime.now());

    return Card(
      color: sona.accentSoft,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  size: 28,
                  color: sona.onAccentSoft,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text('Sona Pro', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isPro
                  ? 'Подписка активна. Все возможности открыты.'
                  : 'Неограниченный голосовой ввод, полная аналитика и '
                        'приоритетная обработка.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: sona.onAccentSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Статус активной подписки: план, срок и отмена.
class _ProStatusCard extends StatelessWidget {
  const _ProStatusCard({
    required this.state,
    required this.busy,
    required this.onCancel,
  });

  final SubscriptionState state;
  final bool busy;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;
    final now = DateTime.now();
    final plan = state.plan;
    final trial = state.isTrialAt(now);
    final daysLeft = state.trialDaysLeft(now);
    final expiry = state.expiresAt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_rounded, color: sona.income),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    trial ? 'Пробный период' : 'Подписка активна',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              [
                if (plan != null) plan.title,
                if (trial && daysLeft > 0) 'осталось $daysLeft дн.',
                if (expiry != null)
                  'до ${SonaFormat.dateShort(expiry)}',
              ].join(' · '),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: busy ? null : onCancel,
              icon: const Icon(Icons.cancel_outlined, size: 20),
              label: const Text('Отменить подписку'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Выбор плана: месяц или год.
class _PlanSelector extends StatelessWidget {
  const _PlanSelector({required this.selected, required this.onSelect});

  final SubscriptionPlan selected;
  final ValueChanged<SubscriptionPlan> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;

    return Column(
      children: [
        for (final plan in SubscriptionPlan.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () => onSelect(plan),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: plan == selected
                      ? sona.accentSoft.withValues(alpha: 0.6)
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: plan == selected
                        ? sona.onAccentSoft
                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: plan == selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      plan == selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: plan == selected
                          ? sona.onAccentSoft
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(plan.title, style: theme.textTheme.titleMedium),
                          Text(
                            plan.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(plan.priceLabel, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Что входит в бесплатный тариф и Sona Pro.
class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard();

  static const List<({String label, bool pro})> _features = [
    (label: '30 операций в месяц', pro: false),
    (label: 'Ручной ввод', pro: false),
    (label: 'Базовая статистика', pro: false),
    (label: '1 бюджет', pro: false),
    (label: 'Неограниченный голосовой ввод', pro: true),
    (label: 'Полная аналитика', pro: true),
    (label: 'Неограниченные бюджеты и цели', pro: true),
    (label: 'Прогнозы и советы', pro: true),
    (label: 'Экспорт данных', pro: true),
    (label: 'Приоритетная обработка', pro: true),
    (label: 'Качество распознавания «Максимум»', pro: true),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Что входит', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final feature in _features)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      feature.pro
                          ? Icons.workspace_premium_rounded
                          : Icons.check_rounded,
                      size: 18,
                      color: feature.pro
                          ? sona.onAccentSoft
                          : sona.income,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        feature.label,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    if (feature.pro)
                      Text(
                        'Pro',
                        style: theme.textTheme.labelSmall?.copyWith(
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

/// Настройка качества распознавания (Максимум — только Pro).
class _QualityCard extends ConsumerWidget {
  const _QualityCard({required this.state});

  final SubscriptionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;
    final isPro = state.isProAt(DateTime.now());
    final selected =
        ref.watch(appSettingsProvider).value?.recognitionQuality ??
        RecognitionQuality.standard;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Качество распознавания', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            SegmentedButton<RecognitionQuality>(
              segments: [
                for (final quality in RecognitionQuality.values)
                  ButtonSegment(
                    value: quality,
                    label: Text(quality.label),
                    icon: quality == RecognitionQuality.max && !isPro
                        ? const Icon(Icons.lock_outline_rounded, size: 16)
                        : null,
                  ),
              ],
              selected: {isPro ? selected : RecognitionQuality.standard},
              onSelectionChanged: (values) {
                final quality = values.first;
                if (quality == RecognitionQuality.max && !isPro) return;
                ref
                    .read(appSettingsProvider.notifier)
                    .setRecognitionQuality(quality);
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isPro
                  ? selected.description
                  : 'Режим «Максимум» доступен на тарифе Sona Pro.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isPro
                    ? theme.colorScheme.onSurfaceVariant
                    : sona.onAccentSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
