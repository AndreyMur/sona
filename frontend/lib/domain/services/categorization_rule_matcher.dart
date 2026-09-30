import '../models/categorization_rule.dart';
import 'category_dictionary.dart';

/// Подбор ключевого слова для обучения и применение выученных правил.
abstract final class CategorizationRuleMatcher {
  const CategorizationRuleMatcher._();

  /// Слова, которые не несут категорийного смысла и не годятся в ключи.
  static const Set<String> _stopwords = {
    'потратил',
    'потратила',
    'потрачено',
    'купил',
    'купила',
    'оплатил',
    'оплатила',
    'заплатил',
    'заплатила',
    'получил',
    'получила',
    'сегодня',
    'вчера',
    'позавчера',
    'завтра',
    'рублей',
    'рубля',
    'рубль',
    'тысяч',
    'тысячи',
    'тысяча',
    'операция',
    'операцию',
    'расход',
    'доход',
  };

  /// Возвращает наиболее значимое слово фразы для обучения правилу.
  ///
  /// Возвращает `null`, если во фразе нет подходящего слова.
  static String? candidateKeyword(String text) {
    final words = normalizeSonaText(text).split(' ');
    String? best;
    for (final word in words) {
      if (!_isCandidate(word)) continue;
      if (best == null || word.length > best.length) best = word;
    }
    return best;
  }

  /// Возвращает правило с самым длинным совпавшим ключом, либо `null`.
  static CategorizationRule? match(
    List<CategorizationRule> rules,
    String text,
  ) {
    if (rules.isEmpty) return null;
    final words = normalizeSonaText(text).split(' ');
    CategorizationRule? best;
    for (final rule in rules) {
      final keyword = rule.keyword;
      if (keyword.length < 3) continue;
      for (final word in words) {
        if (word.isEmpty) continue;
        final matches =
            word == keyword ||
            word.startsWith(keyword) ||
            (word.length >= 3 && keyword.startsWith(word));
        if (matches && (best == null || keyword.length > best.keyword.length)) {
          best = rule;
          break;
        }
      }
    }
    return best;
  }

  static bool _isCandidate(String word) {
    if (word.length < 3) return false;
    if (RegExp(r'^\d').hasMatch(word)) return false;
    if (_stopwords.contains(word)) return false;
    return true;
  }
}
