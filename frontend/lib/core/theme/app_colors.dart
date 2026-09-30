import 'package:flutter/material.dart';

/// Базовая палитра бренда Sona.
///
/// Значения зафиксированы в дизайн-системе (ТЗ, раздел 5 «Дизайн-система»):
/// чистый, спокойный стиль «финансовый wellness».
abstract final class AppColors {
  const AppColors._();

  /// Основной фирменный цвет.
  static const Color primary = Color(0xFF0F6B4F);

  /// Светлый акцент (подложки, чипы, вторичные кнопки).
  static const Color accent = Color(0xFFD4F0E2);

  /// Начало фонового градиента.
  static const Color backgroundTop = Color(0xFFE8F5EE);

  /// Конец фонового градиента.
  static const Color backgroundBottom = Color(0xFFFFFFFF);

  /// Основной текст.
  static const Color textPrimary = Color(0xFF1A1A1A);

  /// Второстепенный текст.
  static const Color textSecondary = Color(0xFF6B7280);

  /// Доход.
  static const Color income = Color(0xFF16A34A);

  /// Расход.
  static const Color expense = Color(0xFF1A1A1A);

  /// Ошибка.
  static const Color error = Color(0xFFDC2626);

  /// Предупреждение.
  static const Color warning = Color(0xFFF59E0B);

  /// Фон поверхностей.
  static const Color surface = Color(0xFFFFFFFF);

  /// Фон поверхностей в тёмной теме.
  static const Color surfaceDark = Color(0xFF121815);

  /// Фон приложения в тёмной теме.
  static const Color backgroundDark = Color(0xFF0B100D);

  /// Основной текст в тёмной теме.
  static const Color textPrimaryDark = Color(0xFFF5F7F6);

  /// Второстепенный текст в тёмной теме.
  static const Color textSecondaryDark = Color(0xFF9CA3AF);

  /// Светлый оттенок primary для тёмной темы.
  static const Color primaryDark = Color(0xFF4FD1A5);

  /// Фоновый градиент приложения.
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundTop, backgroundBottom],
  );
}
