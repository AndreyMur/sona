import 'package:flutter/foundation.dart';

import '../models/subscription.dart';

/// Итог операции покупки или восстановления подписки.
enum PurchaseOutcome { success, restored, canceled, pending, unavailable, error }

/// Результат покупки/восстановления, пригодный для синхронизации с прокси.
@immutable
class PurchaseResult {
  const PurchaseResult({
    required this.outcome,
    this.plan,
    this.purchaseToken,
    this.expiresAt,
    this.trial = false,
    this.message,
  });

  final PurchaseOutcome outcome;
  final SubscriptionPlan? plan;
  final String? purchaseToken;
  final DateTime? expiresAt;
  final bool trial;
  final String? message;

  /// Успешна ли покупка (включая восстановление).
  bool get isSuccess =>
      outcome == PurchaseOutcome.success || outcome == PurchaseOutcome.restored;

  static const PurchaseResult canceled = PurchaseResult(
    outcome: PurchaseOutcome.canceled,
  );

  static const PurchaseResult unavailable = PurchaseResult(
    outcome: PurchaseOutcome.unavailable,
    message: 'Покупки недоступны на этом устройстве',
  );

  static const PurchaseResult nothingToRestore = PurchaseResult(
    outcome: PurchaseOutcome.error,
    message: 'Активных подписок не найдено',
  );
}

/// Порт покупок внутри приложения (in_app_purchase).
abstract interface class PurchaseService {
  /// Доступны ли покупки на текущей платформе.
  Future<bool> isAvailable();

  /// Возвращает актуальные предложения магазина.
  Future<List<SubscriptionOffer>> offers();

  /// Запускает покупку подписки [plan].
  Future<PurchaseResult> buy(SubscriptionPlan plan);

  /// Восстанавливает ранее оформленные покупки.
  Future<PurchaseResult> restore();

  /// Освобождает ресурсы (подписки на поток покупок).
  void dispose();
}
