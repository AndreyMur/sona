import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/currency.dart';
import '../../../domain/services/permission_service.dart';

/// Онбординг из 4 слайдов: приветствие, ИИ-категории, лимиты и настройка
/// (валюта, категории, разрешения на микрофон и уведомления).
///
/// Завершение сохраняет [AppSettings] — навигация на главную происходит
/// через redirect роутера по изменению настроек.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _page = 0;
  String _currencyCode = kDefaultCurrencyCode;
  final Set<String> _selectedCategories = kDefaultCategories.keys.toSet();
  SonaPermissionStatus? _microphoneStatus;
  SonaPermissionStatus? _notificationsStatus;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _loadPermissionStatuses();
  }

  Future<void> _loadPermissionStatuses() async {
    final permissions = ref.read(permissionServiceProvider);
    final microphone = await permissions.microphoneStatus();
    final notifications = await permissions.notificationStatus();
    if (!mounted) return;
    setState(() {
      _microphoneStatus = microphone;
      _notificationsStatus = notifications;
    });
  }

  Future<void> _requestMicrophone() async {
    final status = await ref.read(permissionServiceProvider).requestMicrophone();
    if (!mounted) return;
    setState(() => _microphoneStatus = status);
  }

  Future<void> _requestNotifications() async {
    final status =
        await ref.read(permissionServiceProvider).requestNotifications();
    if (!mounted) return;
    setState(() => _notificationsStatus = status);
  }

  void _next() {
    if (_page >= 3) {
      _finish();
      return;
    }
    setState(() => _page += 1);
  }

  void _skipToSetup() {
    setState(() => _page = 3);
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await ref.read(appSettingsProvider.notifier).completeOnboarding(
        currencyCode: _currencyCode,
        selectedCategories: _selectedCategories,
      );
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Sona'),
        actions: [
          if (_page < 3)
            TextButton(
              onPressed: _skipToSetup,
              child: const Text('Пропустить'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(
                  key: ValueKey(_page),
                  child: IndexedStack(
                    index: _page,
                    children: [
                      _IntroSlide(
                        title: 'Скажи — я запишу',
                        subtitle:
                            'Записывайте траты голосом: назовите покупку — '
                            'Sona сохранит операцию за пару секунд',
                        icon: Icons.mic_rounded,
                      ),
                      _IntroSlide(
                        title: 'ИИ распределит по категориям',
                        subtitle:
                            'Просто скажите «кофе 450» — Sona подберёт '
                            'категорию и подкатегорию сама',
                        icon: Icons.auto_awesome_rounded,
                      ),
                      _IntroSlide(
                        title: 'Следите за лимитами без таблиц',
                        subtitle:
                            'Месячный бюджет и аккуратные напоминания, '
                            'когда вы приближаетесь к лимиту',
                        icon: Icons.savings_rounded,
                      ),
                      _SetupSlide(
                        currencyCode: _currencyCode,
                        onCurrencyChanged: (code) =>
                            setState(() => _currencyCode = code),
                        selectedCategories: _selectedCategories,
                        onCategoryToggled: (name, selected) => setState(() {
                          selected
                              ? _selectedCategories.add(name)
                              : _selectedCategories.remove(name);
                        }),
                        microphoneStatus: _microphoneStatus,
                        notificationsStatus: _notificationsStatus,
                        onRequestMicrophone: _requestMicrophone,
                        onRequestNotifications: _requestNotifications,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _PageIndicator(page: _page, pageCount: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: FilledButton(
                onPressed: _finishing ? null : _next,
                child: Text(_page == 3 ? 'Начать пользоваться' : 'Далее'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Слайд-знакомство: крупная иконка в акцентном круге, заголовок и текст.
class _IntroSlide extends StatelessWidget {
  const _IntroSlide({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: sona.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: sona.onAccentSoft),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              style: theme.textTheme.displayMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Слайд настройки: валюта, категории, разрешения.
class _SetupSlide extends StatelessWidget {
  const _SetupSlide({
    required this.currencyCode,
    required this.onCurrencyChanged,
    required this.selectedCategories,
    required this.onCategoryToggled,
    required this.microphoneStatus,
    required this.notificationsStatus,
    required this.onRequestMicrophone,
    required this.onRequestNotifications,
  });

  final String currencyCode;
  final ValueChanged<String> onCurrencyChanged;
  final Set<String> selectedCategories;
  final void Function(String name, bool selected) onCategoryToggled;
  final SonaPermissionStatus? microphoneStatus;
  final SonaPermissionStatus? notificationsStatus;
  final VoidCallback onRequestMicrophone;
  final VoidCallback onRequestNotifications;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Настройте Sona под себя', style: theme.textTheme.displayMedium),
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel('Валюта'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final currency in kCurrencies)
                ChoiceChip(
                  label: Text('${currency.code} ${currency.symbol}'),
                  selected: currencyCode == currency.code,
                  onSelected: (_) => onCurrencyChanged(currency.code),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel('Категории'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Выберите, какие категории вам нужны. Можно будет изменить позже.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final name in kDefaultCategories.keys)
                FilterChip(
                  label: Text(name),
                  selected: selectedCategories.contains(name),
                  onSelected: (selected) => onCategoryToggled(name, selected),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel('Разрешения'),
          const SizedBox(height: AppSpacing.sm),
          _PermissionTile(
            icon: Icons.mic_rounded,
            title: 'Микрофон',
            subtitle: 'Чтобы записывать операции голосом',
            status: microphoneStatus,
            onRequest: onRequestMicrophone,
          ),
          const SizedBox(height: AppSpacing.sm),
          _PermissionTile(
            icon: Icons.notifications_rounded,
            title: 'Уведомления',
            subtitle: 'Напоминания о бюджете и лимитах',
            status: notificationsStatus,
            onRequest: onRequestNotifications,
          ),
        ],
      ),
    );
  }
}

/// Подпись секции на слайде настройки.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

/// Строка разрешения: статус и кнопка запроса либо галочка.
class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onRequest,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final SonaPermissionStatus? status;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;
    final granted = status == SonaPermissionStatus.granted;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: sona.accentSoft,
          child: Icon(icon, size: 20, color: sona.onAccentSoft),
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(
          statusText(status),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: granted
            ? Icon(Icons.check_circle_rounded, color: sona.income)
            : FilledButton.tonal(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(112, 40),
                  textStyle: theme.textTheme.labelMedium,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                ),
                onPressed: onRequest,
                child: const Text('Разрешить'),
              ),
      ),
    );
  }

  String statusText(SonaPermissionStatus? status) {
    return switch (status) {
      SonaPermissionStatus.granted => 'Разрешено',
      SonaPermissionStatus.denied => subtitle,
      SonaPermissionStatus.permanentlyDenied =>
        'Отклонено — разрешите в настройках системы',
      SonaPermissionStatus.restricted => 'Недоступно на устройстве',
      null => subtitle,
    };
  }
}

/// Индикатор страниц онбординга.
class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.page, required this.pageCount});

  final int page;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    final sona = context.sonaColors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < pageCount; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            width: i == page ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == page
                  ? sona.onAccentSoft
                  : sona.onAccentSoft.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
    );
  }
}
