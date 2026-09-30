import '../models/category.dart';
import '../models/operation.dart';
import '../models/recognition.dart';
import '../repositories/categorization_repository.dart';
import 'categorization_rule_matcher.dart';
import 'recognition_service.dart';

/// Разбор текста с применением выученных правил категоризации.
///
/// Оборачивает базовый парсер (офлайн или AI): если во фразе найдено
/// выученное правило, а операция одна — правило переопределяет категорию,
/// подкатегорию и тип операции. Для фраз с несколькими операциями правило
/// не применяется: непонятно, к какой части фразы оно относится.
class LearnedRulesParser implements TextParsingService {
  const LearnedRulesParser(this._base, this._rules);

  final TextParsingService _base;
  final CategorizationRepository _rules;

  @override
  Future<ParseResult> parse(String text) async {
    final result = await _base.parse(text);
    if (result.operations.length != 1) return result;

    final stored = await _rules.all();
    if (stored.isEmpty) return result;

    final rule = CategorizationRuleMatcher.match(stored, text);
    if (rule == null) return result;

    final operation = result.operations.single;
    if (operation.category == rule.category &&
        operation.subcategory == rule.subcategory) {
      return result;
    }

    final adjusted = operation.copyWith(
      type: rule.category == kIncomeCategory
          ? OperationType.income
          : OperationType.expense,
      category: rule.category,
      subcategory: rule.subcategory,
      confidence: 0.85,
    );
    return ParseResult(
      operations: [adjusted],
      overallConfidence: 0.85,
      model: result.model,
      fallbackUsed: result.fallbackUsed,
      promptVersion: result.promptVersion,
      latencyMs: result.latencyMs,
      costUsd: result.costUsd,
      requestId: result.requestId,
    );
  }
}
