import 'package:flutter/material.dart';

/// Типографика дизайн-системы Sona.
///
/// Заголовки 28–32pt bold, тело 15–16pt (ТЗ, раздел 5). Шрифты — Inter
/// (текст) и Manrope (заголовки), подключены как вариативные ассеты
/// (`assets/fonts`). Вес задаётся осью `wght` через [FontVariation], чтобы
/// не хранить по файлу на каждое начертание.
abstract final class AppTypography {
  const AppTypography._();

  /// Семейство основного текста.
  static const String fontFamily = 'Inter';

  /// Семейство заголовков.
  static const String displayFontFamily = 'Manrope';

  static TextStyle _display(
    double size,
    double weight, {
    required double height,
  }) {
    return TextStyle(
      fontFamily: displayFontFamily,
      fontSize: size,
      fontWeight: _fontWeight(weight),
      fontVariations: [FontVariation('wght', weight)],
      height: height,
    );
  }

  static TextStyle _body(double size, double weight, {required double height}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: _fontWeight(weight),
      fontVariations: [FontVariation('wght', weight)],
      height: height,
    );
  }

  static FontWeight _fontWeight(double value) {
    final index = ((value / 100).round() - 1).clamp(0, 8);
    return FontWeight.values[index];
  }

  static final TextTheme textTheme = TextTheme(
    displayLarge: _display(32, 700, height: 1.15),
    displayMedium: _display(28, 700, height: 1.2),
    headlineSmall: _display(24, 700, height: 1.25),
    titleLarge: _display(20, 600, height: 1.3),
    titleMedium: _display(17, 600, height: 1.3),
    bodyLarge: _body(16, 400, height: 1.45),
    bodyMedium: _body(15, 400, height: 1.45),
    bodySmall: _body(13, 400, height: 1.4),
    labelLarge: _body(15, 600, height: 1.2),
    labelMedium: _body(13, 500, height: 1.2),
  );
}
