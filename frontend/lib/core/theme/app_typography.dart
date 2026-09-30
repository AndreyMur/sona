import 'package:flutter/material.dart';

/// Типографика дизайн-системы Sona.
///
/// Заголовки 28–32pt bold, тело 15–16pt (ТЗ, раздел 5). Шрифт — Inter/Manrope;
/// семейство шрифта задаётся темой и при отсутствии ассетов берётся системное.
abstract final class AppTypography {
  const AppTypography._();

  static const String fontFamily = 'Inter';

  static const TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.15),
    displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2),
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.25),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3),
    titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.3),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.45),
    bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.45),
    bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.4),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.2),
    labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.2),
  );
}
