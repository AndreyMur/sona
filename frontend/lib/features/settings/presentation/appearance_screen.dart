import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../domain/models/theme_mode.dart';
import '../../../l10n/l10n.dart';

/// Экран «Внешний вид»: выбор режима оформления (системная / светлая / тёмная).
///
/// Значение сохраняется в [AppSettings] и применяется ко всему приложению
/// через `MaterialApp.themeMode`.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selected = ref.watch(themeModeProvider);

    return GradientScaffold(
      appBar: AppBar(title: Text(context.l10n.appearanceTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Text(
            context.l10n.appearanceThemeSection,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                for (final mode in SonaThemeMode.values) ...[
                  if (mode != SonaThemeMode.values.first)
                    const Divider(height: 1, indent: AppSpacing.lg),
                  _ThemeOption(
                    mode: mode,
                    selected: mode == selected,
                    onTap: () => ref
                        .read(appSettingsProvider.notifier)
                        .setThemeMode(mode),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.l10n.appearanceThemeHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Пункт выбора темы с миниатюрой-предпросмотром и отметкой выбора.
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final SonaThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final (label, description) = switch (mode) {
      SonaThemeMode.system => (
        l10n.themeModeSystem,
        l10n.themeModeSystemDescription,
      ),
      SonaThemeMode.light => (
        l10n.themeModeLight,
        l10n.themeModeLightDescription,
      ),
      SonaThemeMode.dark => (l10n.themeModeDark, l10n.themeModeDarkDescription),
    };

    return Semantics(
      selected: selected,
      button: true,
      label: l10n.a11yThemeOption(label),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        leading: _ThemeSwatch(mode: mode),
        title: Text(label, style: theme.textTheme.titleMedium),
        subtitle: Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: selected
            ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
            : Icon(
                Icons.circle_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
        onTap: onTap,
      ),
    );
  }
}

/// Миниатюра-предпросмотр палитры для режима темы.
class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.mode});

  final SonaThemeMode mode;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          gradient: switch (mode) {
            SonaThemeMode.light => const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.backgroundTop, AppColors.surface],
            ),
            SonaThemeMode.dark => const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.backgroundDark, AppColors.surfaceDark],
            ),
            SonaThemeMode.system => const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.backgroundTop,
                AppColors.backgroundTop,
                AppColors.backgroundDark,
                AppColors.backgroundDark,
              ],
              stops: [0, 0.5, 0.5, 1],
            ),
          },
        ),
        child: Center(
          child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
