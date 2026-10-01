import '../models/subscription.dart';

/// Синхронизирует тариф подписки с прокси Sona.
///
/// Лимит бесплатного тарифа проверяется на стороне прокси, поэтому после
/// покупки приложение сообщает ему о переходе на Pro (и обратно).
abstract interface class SubscriptionGateway {
  /// Сообщает прокси об активации Pro.
  Future<void> activate({
    required SubscriptionPlan plan,
    String? platform,
    String? purchaseToken,
    bool trial = false,
    DateTime? expiresAt,
  });

  /// Возвращает устройство на бесплатный тариф.
  Future<void> deactivate();
}
