import '../models/shortcut.dart';
import 'category_dictionary.dart';

/// Распознаёт голосовые шорткаты во фразе.
///
/// Поддерживаются: «Баланс», «Сколько на <категория>» и «Отмена».
abstract final class ShortcutMatcher {
  const ShortcutMatcher._();

  static const List<String> _categoryTriggers = [
    'сколько',
    'скока',
    'осталось',
    'остаток',
    'лимит',
    'потратил',
    'потратила',
    'потрачено',
  ];

  /// Возвращает шорткат, если фраза является командой, иначе `null`.
  static VoiceShortcutMatch? match(String raw) {
    final text = normalizeSonaText(raw);
    if (text.isEmpty) return null;

    if (text.startsWith('отмен')) {
      return const VoiceShortcutMatch(VoiceShortcutKind.cancel);
    }

    if (_isBalance(text)) {
      return const VoiceShortcutMatch(VoiceShortcutKind.balance);
    }

    final category = _matchCategory(text);
    if (category != null) {
      return VoiceShortcutMatch(VoiceShortcutKind.category, category: category);
    }

    return null;
  }

  static bool _isBalance(String text) {
    if (text.contains('баланс')) return true;
    const phrases = [
      'сколько денег',
      'сколько у меня денег',
      'сколько средств',
      'мой баланс',
      'остаток средств',
    ];
    return phrases.any(text.startsWith);
  }

  static String? _matchCategory(String text) {
    final words = text.split(' ');
    var index = 0;
    var triggered = false;

    while (index < words.length) {
      final word = words[index];
      if (_categoryTriggers.contains(word) ||
          word.startsWith('остал') ||
          word.startsWith('потрат')) {
        triggered = true;
        index++;
        continue;
      }
      if (triggered && _isFiller(word)) {
        index++;
        continue;
      }
      break;
    }

    if (!triggered) return null;
    final rest = words.sublist(index).join(' ');
    return findCategoryInText(rest)?.category;
  }

  static bool _isFiller(String word) {
    const fillers = {'на', 'за', 'по', 'в', 'у', 'меня', 'этот', 'эту', 'месяц'};
    return fillers.contains(word);
  }
}
