import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../../domain/models/subscription.dart';
import '../../domain/services/purchase_service.dart';

/// Интеграция `in_app_purchase`: оформление и восстановление Sona Pro.
///
/// Подписки покупаются как non-consumable продукты (`sona_pro_monthly`,
/// `sona_pro_annual`). Результат покупки приходит в [InAppPurchase.purchaseStream];
/// обёртка дожидается терминального события и маппит его в [PurchaseResult].
class InAppPurchaseService implements PurchaseService {
  InAppPurchaseService({InAppPurchase? iap})
    : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;
  final StreamController<PurchaseDetails> _events =
      StreamController<PurchaseDetails>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  void _ensureListening() {
    _subscription ??= _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (_) {},
    );
  }

  void _onPurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.pendingCompletePurchase) {
        unawaited(_iap.completePurchase(purchase));
      }
      _events.add(purchase);
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      return await _iap.isAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<SubscriptionOffer>> offers() async {
    if (!await isAvailable()) return const [];
    final ids = SubscriptionPlan.values.map((plan) => plan.productId).toSet();
    final response = await _iap.queryProductDetails(ids);
    return [
      for (final plan in SubscriptionPlan.values)
        SubscriptionOffer(
          plan: plan,
          productId: plan.productId,
          priceLabel: _priceFor(response, plan) ?? plan.priceLabel,
        ),
    ];
  }

  String? _priceFor(ProductDetailsResponse response, SubscriptionPlan plan) {
    for (final details in response.productDetails) {
      if (details.id == plan.productId) return details.price;
    }
    return null;
  }

  @override
  Future<PurchaseResult> buy(SubscriptionPlan plan) async {
    if (!await isAvailable()) return PurchaseResult.unavailable;

    final response = await _iap.queryProductDetails({plan.productId});
    final details = _detailsFor(response, plan.productId);
    if (details == null) {
      return PurchaseResult(
        outcome: PurchaseOutcome.error,
        message: 'Товар недоступен: ${plan.productId}',
      );
    }

    _ensureListening();
    final waiter = _waitForPurchase(plan.productId);
    final started = await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
    if (!started) {
      return const PurchaseResult(
        outcome: PurchaseOutcome.error,
        message: 'Не удалось начать покупку',
      );
    }
    return waiter;
  }

  @override
  Future<PurchaseResult> restore() async {
    if (!await isAvailable()) return PurchaseResult.unavailable;
    _ensureListening();

    final restored = <PurchaseDetails>[];
    late StreamSubscription<PurchaseDetails> subscription;
    subscription = _events.stream.listen((purchase) {
      if (purchase.status == PurchaseStatus.restored ||
          purchase.status == PurchaseStatus.purchased) {
        restored.add(purchase);
      }
    });

    await _iap.restorePurchases();
    await Future<void>.delayed(const Duration(seconds: 5));
    await subscription.cancel();

    if (restored.isEmpty) return PurchaseResult.nothingToRestore;
    final purchase = restored.first;
    return PurchaseResult(
      outcome: PurchaseOutcome.restored,
      plan: SubscriptionPlan.fromId(purchase.productID),
      purchaseToken: purchase.verificationData.serverVerificationData,
    );
  }

  Future<PurchaseResult> _waitForPurchase(String productId) {
    final completer = Completer<PurchaseResult>();
    late StreamSubscription<PurchaseDetails> subscription;
    subscription = _events.stream.listen((purchase) {
      if (purchase.productID != productId) return;
      final result = _mapPurchase(purchase);
      if (result == null) return;
      subscription.cancel();
      if (!completer.isCompleted) completer.complete(result);
    });
    return completer.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () {
        subscription.cancel();
        return const PurchaseResult(
          outcome: PurchaseOutcome.error,
          message: 'Покупка не завершена',
        );
      },
    );
  }

  PurchaseResult? _mapPurchase(PurchaseDetails purchase) {
    switch (purchase.status) {
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        return PurchaseResult(
          outcome: purchase.status == PurchaseStatus.restored
              ? PurchaseOutcome.restored
              : PurchaseOutcome.success,
          plan: SubscriptionPlan.fromId(purchase.productID),
          purchaseToken: purchase.verificationData.serverVerificationData,
        );
      case PurchaseStatus.pending:
        return const PurchaseResult(
          outcome: PurchaseOutcome.pending,
          message: 'Покупка обрабатывается',
        );
      case PurchaseStatus.canceled:
        return PurchaseResult.canceled;
      case PurchaseStatus.error:
        return PurchaseResult(
          outcome: PurchaseOutcome.error,
          message: purchase.error?.message,
        );
    }
  }

  ProductDetails? _detailsFor(ProductDetailsResponse response, String productId) {
    for (final details in response.productDetails) {
      if (details.id == productId) return details;
    }
    return null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _events.close();
  }
}
