import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Семантические цвета темы (доход, расход, акцент и фон-градиент).
@immutable
class SonaColors extends ThemeExtension<SonaColors> {
  const SonaColors({
    required this.income,
    required this.expense,
    required this.warning,
    required this.accentSoft,
    required this.backgroundGradient,
    required this.onAccentSoft,
  });

  final Color income;
  final Color expense;
  final Color warning;
  final Color accentSoft;
  final LinearGradient backgroundGradient;
  final Color onAccentSoft;

  static const SonaColors light = SonaColors(
    income: AppColors.income,
    expense: AppColors.expense,
    warning: AppColors.warning,
    accentSoft: AppColors.accent,
    backgroundGradient: AppColors.backgroundGradient,
    onAccentSoft: AppColors.primary,
  );

  static const SonaColors dark = SonaColors(
    income: AppColors.income,
    expense: AppColors.textPrimaryDark,
    warning: AppColors.warning,
    accentSoft: Color(0xFF16352A),
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppColors.backgroundDark, AppColors.surfaceDark],
    ),
    onAccentSoft: AppColors.primaryDark,
  );

  @override
  SonaColors copyWith({
    Color? income,
    Color? expense,
    Color? warning,
    Color? accentSoft,
    LinearGradient? backgroundGradient,
    Color? onAccentSoft,
  }) {
    return SonaColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      warning: warning ?? this.warning,
      accentSoft: accentSoft ?? this.accentSoft,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      onAccentSoft: onAccentSoft ?? this.onAccentSoft,
    );
  }

  @override
  SonaColors lerp(ThemeExtension<SonaColors>? other, double t) {
    if (other is! SonaColors) return this;
    return SonaColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      backgroundGradient: LinearGradient.lerp(
        backgroundGradient,
        other.backgroundGradient,
        t,
      )!,
      onAccentSoft: Color.lerp(onAccentSoft, other.onAccentSoft, t)!,
    );
  }
}

/// Быстрый доступ к семантическим цветам из [BuildContext].
extension SonaColorsX on BuildContext {
  SonaColors get sonaColors => Theme.of(this).extension<SonaColors>()!;
}

/// Сборка светлой и тёмной тем Material 3 на токенах дизайн-системы.
abstract final class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: AppColors.primary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
    );

    return _base(scheme, SonaColors.light);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primaryDark,
      onPrimary: AppColors.backgroundDark,
      secondary: AppColors.accent,
      onSecondary: AppColors.primary,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textPrimaryDark,
      error: AppColors.error,
    );

    return _base(scheme, SonaColors.dark);
  }

  static ThemeData _base(
    ColorScheme scheme,
    SonaColors sonaColors,
  ) {
    final textTheme = AppTypography.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: AppTypography.fontFamily,
      textTheme: textTheme,
      extensions: [sonaColors],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: textTheme.labelLarge),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
      ),
    );
  }
}
