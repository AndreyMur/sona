import 'package:flutter/foundation.dart';

/// Вид голосового шортката.
enum VoiceShortcutKind {
  /// «Баланс» — показать текущий баланс.
  balance,

  /// «Сколько на продукты» — остаток по категории.
  category,

  /// «Отмена» — отменить текущую операцию.
  cancel,
}

/// Распознанный шорткат во фразе.
@immutable
class VoiceShortcutMatch {
  const VoiceShortcutMatch(this.kind, {this.category});

  final VoiceShortcutKind kind;

  /// Категория для [VoiceShortcutKind.category].
  final String? category;
}

/// Результат выполнения шортката, показываемый пользователю.
@immutable
class ShortcutResult {
  const ShortcutResult({
    required this.kind,
    required this.title,
    required this.value,
    this.subtitle,
    this.category,
  });

  final VoiceShortcutKind kind;
  final String title;
  final String value;
  final String? subtitle;
  final String? category;
}
