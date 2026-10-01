import '../models/subscription.dart';

/// Хранилище состояния подписки Sona Pro.
abstract interface class SubscriptionStore {
  /// Загружает сохранённое состояние (или бесплатный тариф).
  Future<SubscriptionState> load();

  /// Полностью перезаписывает состояние подписки.
  Future<void> save(SubscriptionState state);
}
