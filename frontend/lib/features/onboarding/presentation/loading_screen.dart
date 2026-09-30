import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gradient_scaffold.dart';

/// Показывается на холодном старте, пока загружаются настройки пользователя.
///
/// Закрывает возможный миг экрана навигации: пользователь видит либо
/// онбординг, либо главную — никогда обе.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;

    return GradientScaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sona',
                style: theme.textTheme.displayLarge?.copyWith(
                  color: sona.onAccentSoft,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'скажи — я запишу',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
