import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/core/theme/app_theme.dart';
import 'package:sona/domain/models/app_settings.dart';
import 'package:sona/domain/models/theme_mode.dart';

void main() {
  group('SonaThemeMode', () {
    test('fromWire распознаёт значения и по умолчанию системная', () {
      expect(SonaThemeMode.fromWire('light'), SonaThemeMode.light);
      expect(SonaThemeMode.fromWire('dark'), SonaThemeMode.dark);
      expect(SonaThemeMode.fromWire('system'), SonaThemeMode.system);
      expect(SonaThemeMode.fromWire('unknown'), SonaThemeMode.system);
      expect(SonaThemeMode.fromWire(null), SonaThemeMode.system);
    });

    test('преобразуется в ThemeMode Flutter', () {
      expect(SonaThemeMode.system.materialThemeMode, ThemeMode.system);
      expect(SonaThemeMode.light.materialThemeMode, ThemeMode.light);
      expect(SonaThemeMode.dark.materialThemeMode, ThemeMode.dark);
    });
  });

  group('AppSettings.themeMode', () {
    test('по умолчанию — системная', () {
      expect(const AppSettings().themeMode, SonaThemeMode.system);
    });

    test('copyWith меняет только тему', () {
      const settings = AppSettings(currencyCode: 'USD');
      final updated = settings.copyWith(themeMode: SonaThemeMode.dark);
      expect(updated.themeMode, SonaThemeMode.dark);
      expect(updated.currencyCode, 'USD');
    });

    test('сериализуется и читается обратно', () {
      const settings = AppSettings(themeMode: SonaThemeMode.light);
      final restored = AppSettings.fromJson(settings.toJson());
      expect(restored.themeMode, SonaThemeMode.light);
    });

    test('старые настройки без темы читаются как системная', () {
      final restored = AppSettings.fromJson(const {
        'onboardingCompleted': true,
      });
      expect(restored.themeMode, SonaThemeMode.system);
    });
  });
}
