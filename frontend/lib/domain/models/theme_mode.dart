/// Режим оформления приложения (ТЗ, раздел 5 «Дизайн-система»).
///
/// Светлая и тёмная темы строятся из одной палитры дизайн-системы
/// (см. `AppTheme`), «Системная» следует за настройкой ОС.
enum SonaThemeMode {
  system(wire: 'system', label: 'Системная', description: 'Как в системе'),
  light(
    wire: 'light',
    label: 'Светлая',
    description: 'Всегда светлое оформление',
  ),
  dark(wire: 'dark', label: 'Тёмная', description: 'Всегда тёмное оформление');

  const SonaThemeMode({
    required this.wire,
    required this.label,
    required this.description,
  });

  /// Значение для хранения в настройках (`system` / `light` / `dark`).
  final String wire;

  /// Отображаемое название.
  final String label;

  /// Короткое пояснение режима.
  final String description;

  /// Находит режим по сохранённому значению. По умолчанию — «Системная».
  static SonaThemeMode fromWire(String? wire) {
    for (final mode in SonaThemeMode.values) {
      if (mode.wire == wire) return mode;
    }
    return SonaThemeMode.system;
  }
}
