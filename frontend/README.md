# Sona (frontend)

Кроссплатформенное приложение Sona: голосовой учёт личных финансов.

## Запуск

```sh
flutter pub get
flutter gen-l10n
flutter run
```

## Локализация

Строки интерфейса живут в `lib/l10n/app_ru.arb` (основной) и
`lib/l10n/app_en.arb`. Генерация кода — `flutter gen-l10n`
(настройки в `l10n.yaml`), результат в `lib/l10n/gen/`. В коде строки
доступны через `context.l10n.<key>`.

## Производительность (ТЗ, раздел 12)

Бюджеты: холодный запуск ≤ 1,5 с, размер приложения ≤ 60 МБ.

- Замер запуска до первого кадра — `StartupMetrics` (`lib/core/performance`).
  В debug-сборке значение печатается в консоль при старте.
- Release-сборка с деревотрясением иконок (по умолчанию) и выносом
  символов:

  ```sh
  # Android: отдельный APK под каждую ABI + символы отдельно
  flutter build appbundle --release --split-per-abi \
    --obfuscate --split-debug-info=build/symbols

  # iOS
  flutter build ipa --release --obfuscate --split-debug-info=build/symbols
  ```

- Анализ размера: `flutter build apk --release --analyze-size`.
- Дизайн-система не тянет бинарный Rive-рантайм: волновая анимация
  реализована лёгким `CustomPainter` (`SonaWaveform`), что помогает
  удержать размер в бюджете.
