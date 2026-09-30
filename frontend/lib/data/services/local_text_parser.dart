import '../../domain/models/category.dart';
import '../../domain/models/operation.dart';
import '../../domain/models/recognition.dart';
import '../../domain/services/category_dictionary.dart';
import '../../domain/services/recognition_service.dart';

/// Локальный разбор текста без сети: регулярки + словарь категорий.
///
/// Используется как fallback, когда прокси недоступен. Точность ниже, чем у
/// AI (~70%), поэтому результат помечается в UI бейджем «Офлайн-разбор».
class LocalTextParser implements TextParsingService {
  const LocalTextParser();

  static const String modelName = 'local/rules-v1';

  /// Делит фразу на части для нескольких операций.
  static final RegExp _splitPattern = RegExp(
    r'\s*(?:,|;|\n|\sи\s|\sплюс\s|\sзатем\s|\sпотом\s)\s*',
  );

  /// Число с разделителями тысяч и опциональным множителем.
  static final RegExp _amountPattern = RegExp(
    r'(\d+(?:[ \u00A0]\d{3})*(?:[.,]\d{1,2})?)\s*'
    r'(тыс[а-яё]*|тысяч[а-яё]*|млн[а-яё]*|миллион[а-яё]*|к|k)?'
    r'(?![а-яёa-z])',
    caseSensitive: false,
  );

  @override
  Future<ParseResult> parse(String text) async {
    final operations = _parseOperations(text);
    return ParseResult(
      operations: operations,
      overallConfidence: operations.isEmpty ? 0 : 0.7,
      model: modelName,
      fallbackUsed: true,
    );
  }

  List<ParsedOperation> _parseOperations(String text) {
    final normalized = normalizeSonaText(text);
    if (normalized.isEmpty) return const [];

    final segments = normalized
        .split(_splitPattern)
        .where((segment) => segment.trim().isNotEmpty)
        .toList();

    final operations = <ParsedOperation>[];
    var carried = '';
    for (final segment in segments) {
      final amount = _extractAmount(segment);
      if (amount == null) {
        carried = carried.isEmpty ? segment : '$carried $segment';
        continue;
      }
      final merged = carried.isEmpty ? segment : '$carried $segment';
      carried = '';
      operations.add(_buildOperation(merged, amount));
    }

    return operations;
  }

  ParsedOperation _buildOperation(String segment, double amount) {
    final isIncome = _looksLikeIncome(segment);
    final categoryWord = findCategoryInText(segment);
    final category = categoryWord?.category ?? kFallbackCategory;
    final known = categoryWord != null;

    return ParsedOperation(
      type: isIncome ? OperationType.income : OperationType.expense,
      amount: amount,
      category: category,
      subcategory: categoryWord?.subcategory,
      date: _extractDate(segment),
      confidence: known ? 0.7 : 0.4,
    );
  }

  bool _looksLikeIncome(String segment) {
    for (final word in segment.split(' ')) {
      for (final stem in kIncomeWords) {
        if (word.startsWith(stem)) return true;
      }
    }
    return false;
  }

  DateTime _extractDate(String segment) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (segment.contains('позавчера')) {
      return today.subtract(const Duration(days: 2));
    }
    if (segment.contains('вчера')) {
      return today.subtract(const Duration(days: 1));
    }
    if (segment.contains('завтра')) {
      return today.add(const Duration(days: 1));
    }
    return today;
  }

  /// Извлекает сумму из сегмента. Если чисел несколько — берёт наибольшее.
  double? _extractAmount(String segment) {
    double? best;
    for (final match in _amountPattern.allMatches(segment)) {
      final raw = match.group(1);
      if (raw == null) continue;
      var value = _parseNumber(raw);
      final multiplier = match.group(2)?.toLowerCase();
      if (multiplier != null && multiplier.isNotEmpty) {
        if (multiplier.startsWith('млн') || multiplier.startsWith('миллион')) {
          value *= 1000000;
        } else {
          value *= 1000;
        }
      }
      if (best == null || value > best) best = value;
    }
    return best;
  }

  double _parseNumber(String raw) {
    var value = raw.replaceAll(' ', '').replaceAll('\u00A0', '');
    final separatorIndex = value.lastIndexOf(RegExp(r'[.,]'));
    if (separatorIndex != -1) {
      final fraction = value.substring(separatorIndex + 1);
      if (fraction.length == 3) {
        value = value.replaceAll('.', '').replaceAll(',', '');
      } else {
        value = value.replaceAll(',', '.');
      }
    }
    return double.tryParse(value) ?? 0;
  }
}
