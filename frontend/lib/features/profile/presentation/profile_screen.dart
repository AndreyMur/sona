import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/financial_health.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../domain/models/app_settings.dart';
import '../../../domain/models/subscription.dart';

/// Профиль: аватар, имя, email, скоринг «Финансовое здоровье» и меню разделов.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider).value ?? const AppSettings();
    final health = ref.watch(financialHealthProvider);
    final subscription =
        ref.watch(subscriptionProvider).value ?? const SubscriptionState();
    final subscriptionSubtitle = _subscriptionSubtitle(subscription);

    return GradientScaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          _ProfileHeader(
            name: settings.userName,
            email: settings.userEmail,
            onEdit: () => _editProfile(context, ref, settings),
          ),
          const SizedBox(height: AppSpacing.md),
          _HealthCard(health: health),
          const SizedBox(height: AppSpacing.lg),
          Text('Разделы', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                _MenuTile(
                  icon: Icons.folder_outlined,
                  label: 'Данные',
                  subtitle: 'Экспорт и удаление',
                  onTap: () => context.push(AppRoutes.profileData),
                ),
                const Divider(height: 1, indent: AppSpacing.lg),
                _MenuTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Счета',
                  onTap: () => _comingSoon(context, 'Счета'),
                ),
                const Divider(height: 1, indent: AppSpacing.lg),
                _MenuTile(
                  icon: Icons.category_outlined,
                  label: 'Категории',
                  onTap: () => context.push(AppRoutes.categories),
                ),
                const Divider(height: 1, indent: AppSpacing.lg),
                _MenuTile(
                  icon: Icons.notifications_outlined,
                  label: 'Уведомления',
                  onTap: () => _comingSoon(context, 'Уведомления'),
                ),
                const Divider(height: 1, indent: AppSpacing.lg),
                _MenuTile(
                  icon: Icons.lock_outline_rounded,
                  label: 'Безопасность',
                  subtitle: settings.appLockEnabled
                      ? 'Защита включена'
                      : 'PIN и биометрия',
                  onTap: () => context.push(AppRoutes.security),
                ),
                const Divider(height: 1, indent: AppSpacing.lg),
                _MenuTile(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Подписка',
                  subtitle: subscriptionSubtitle,
                  onTap: () => context.push(AppRoutes.subscription),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => _signOut(context, ref),
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Выйти'),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final result = await showDialog<_ProfileDraft>(
      context: context,
      builder: (_) => _ProfileDialog(initial: settings),
    );
    if (result == null) return;
    await ref
        .read(appSettingsProvider.notifier)
        .setProfile(name: result.name, email: result.email);
  }

  /// Подпись пункта «Подписка»: статус Pro, пробный период или бесплатный.
  String _subscriptionSubtitle(SubscriptionState subscription) {
    final now = DateTime.now();
    if (subscription.isProAt(now)) {
      if (subscription.isTrialAt(now)) {
        final days = subscription.trialDaysLeft(now);
        return days > 0 ? 'Пробный период · $days дн.' : 'Пробный период';
      }
      return 'Sona Pro · активна';
    }
    return 'Sona Pro';
  }

  void _comingSoon(BuildContext context, String section) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('«$section» появится в следующих обновлениях')),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Выйти из профиля?'),
        content: const Text(
          'Данные останутся на устройстве, но приложение вернётся к экрану '
          'знакомства.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(appSettingsProvider.notifier).signOut();
  }
}

/// Шапка профиля: аватар, имя и email.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.onEdit,
  });

  final String? name;
  final String? email;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;
    final displayName = (name == null || name!.isEmpty) ? 'Без имени' : name!;
    final initials = _initials(displayName);

    return Card(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: sona.accentSoft,
                child: Text(
                  initials,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: sona.onAccentSoft,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      (email == null || email!.isEmpty)
                          ? 'Добавьте email'
                          : email!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

/// Карточка скоринга «Финансовое здоровье».
class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.health});

  final AsyncValue<FinancialHealth> health;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: health.when(
          data: (value) {
            final color = _scoreColor(value.score, context);
            return Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: value.score / 100,
                        strokeWidth: 7,
                        backgroundColor: sona.accentSoft,
                        color: color,
                      ),
                      Text(
                        '${value.score}',
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Финансовое здоровье',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        value.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: color,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Сбережения ${value.savingsScore}/'
                        '$kHealthSavingsMax · Бюджет ${value.budgetScore}/'
                        '$kHealthBudgetMax · Учёт ${value.activityScore}/'
                        '$kHealthActivityMax',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 72,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Text(
            'Не удалось рассчитать скоринг',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }

  Color _scoreColor(int score, BuildContext context) {
    final sona = context.sonaColors;
    if (score >= 60) return sona.income;
    if (score >= 40) return sona.warning;
    return Theme.of(context).colorScheme.error;
  }
}

/// Пункт меню профиля.
class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;
    return ListTile(
      leading: Icon(icon, color: sona.onAccentSoft),
      title: Text(label, style: theme.textTheme.titleMedium),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

/// Черновик редактирования имени и email.
class _ProfileDraft {
  const _ProfileDraft({this.name, this.email});

  final String? name;
  final String? email;
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({required this.initial});

  final AppSettings initial;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial.userName ?? '',
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.initial.userEmail ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Профиль'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Имя'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _ProfileDraft(name: _name.text, email: _email.text),
          ),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
