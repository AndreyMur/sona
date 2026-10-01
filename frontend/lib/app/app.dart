import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../features/security/presentation/app_lock_gate.dart';
import '../l10n/l10n.dart';
import 'providers.dart';

/// Корневое приложение Sona.
class SonaApp extends ConsumerWidget {
  const SonaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider).materialThemeMode,
      builder: (context, child) =>
          AppLockGate(child: child ?? const SizedBox.shrink()),
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('ru'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    );
  }
}
