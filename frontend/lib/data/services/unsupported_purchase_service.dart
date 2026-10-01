import '../../domain/models/subscription.dart';
import '../../domain/services/purchase_service.dart';

/// Заглушка покупок для платформ без магазина приложений (веб-демо).
class UnsupportedPurchaseService implements PurchaseService {
  const UnsupportedPurchaseService();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<List<SubscriptionOffer>> offers() async => const [];

  @override
  Future<PurchaseResult> buy(SubscriptionPlan plan) async =>
      PurchaseResult.unavailable;

  @override
  Future<PurchaseResult> restore() async => PurchaseResult.unavailable;

  @override
  void dispose() {}
}
