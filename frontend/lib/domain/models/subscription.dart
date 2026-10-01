import 'package:flutter/foundation.dart';

/// Длительность пробного периода Sona Pro (дни).
const int kProTrialDays = 7;

/// Лимит бесплатного тарифа: операций в месяц.
const int kFreeMonthlyOperations = 30;

/// Тариф устройства на прокси Sona.
enum SubscriptionTier { free, pro }

/// Планы подписки Sona Pro (ТЗ, раздел 10 «Монетизация»).
enum SubscriptionPlan {
  monthly(
    id: 'monthly',
    productId: 'sona_pro_monthly',
    title: 'Месяц',
    priceLabel: '349 ₽/мес',
    description: 'Списание раз в месяц',
  ),
  annual(
    id: 'annual',
    productId: 'sona_pro_annual',
    title: 'Год',
    priceLabel: '2 490 ₽/год',
    description: 'Выгоднее на 40%',
  );

  const SubscriptionPlan({
    required this.id,
    required this.productId,
    required this.title,
    required this.priceLabel,
    required this.description,
  });

  /// Идентификатор плана для прокси (`monthly` / `annual`).
  final String id;

  /// Идентификатор продукта в магазине приложения.
  final String productId;

  /// Короткое название плана.
  final String title;

  /// Отображаемая цена.
  final String priceLabel;

  /// Пояснение к плану.
  final String description;

  /// Находит план по идентификатору прокси или продукта.
  static SubscriptionPlan? fromId(String? id) {
    if (id == null) return null;
    for (final plan in SubscriptionPlan.values) {
      if (plan.id == id || plan.productId == id) return plan;
    }
    return null;
  }
}

/// Качество распознавания речи (ТЗ: «Стандарт / Максимум (Pro)»).
enum RecognitionQuality {
  standard(
    wire: 'standard',
    label: 'Стандарт',
    description: 'Быстро и экономно, подходит для большинства фраз',
  ),
  max(
    wire: 'max',
    label: 'Максимум',
    description: 'Точнее распознаёт сложные и длинные фразы (Pro)',
  );

  const RecognitionQuality({
    required this.wire,
    required this.label,
    required this.description,
  });

  /// Значение, передаваемое прокси (`standard` / `max`).
  final String wire;

  /// Отображаемое название.
  final String label;

  /// Пояснение.
  final String description;

  /// Находит качество по значению прокси.
  static RecognitionQuality fromWire(String? wire) {
    for (final quality in RecognitionQuality.values) {
      if (quality.wire == wire) return quality;
    }
    return RecognitionQuality.standard;
  }
}

/// Предложение подписки из магазина приложения.
@immutable
class SubscriptionOffer {
  const SubscriptionOffer({
    required this.plan,
    required this.productId,
    required this.priceLabel,
    this.trialDays = 0,
  });

  /// План, к которому относится предложение.
  final SubscriptionPlan plan;

  /// Идентификатор продукта в магазине.
  final String productId;

  /// Локализованная цена из магазина.
  final String priceLabel;

  /// Длительность пробного периода предложения.
  final int trialDays;
}

/// Состояние подписки Sona Pro, сохраняемое на устройстве.
@immutable
class SubscriptionState {
  const SubscriptionState({
    this.tier = SubscriptionTier.free,
    this.plan,
    this.trial = false,
    this.trialEndsAt,
    this.expiresAt,
    this.trialUsed = false,
    this.purchaseToken,
  });

  /// Текущий тариф.
  final SubscriptionTier tier;

  /// Оформленный план (`null` для бесплатного тарифа).
  final SubscriptionPlan? plan;

  /// Активна ли подписка как пробный период.
  final bool trial;

  /// Когда заканчивается пробный период.
  final DateTime? trialEndsAt;

  /// Когда заканчивается оплаченная подписка.
  final DateTime? expiresAt;

  /// Использовал ли пользователь пробный период ранее.
  final bool trialUsed;

  /// Токен покупки для синхронизации с прокси.
  final String? purchaseToken;

  /// Активен ли Pro прямо сейчас.
  bool get isPro => tier == SubscriptionTier.pro;

  /// Активен ли Pro на момент [now] (учитывает срок действия).
  bool isProAt(DateTime now) {
    if (tier != SubscriptionTier.pro) return false;
    final expires = expiresAt;
    if (expires == null) return true;
    return expires.isAfter(now);
  }

  /// Идёт ли пробный период на момент [now].
  bool isTrialAt(DateTime now) => trial && isProAt(now);

  /// Сколько дней пробного периода осталось на момент [now].
  int trialDaysLeft(DateTime now) {
    final end = trialEndsAt;
    if (end == null || !isTrialAt(now)) return 0;
    final diff = end.difference(now);
    if (diff.isNegative) return 0;
    final days = (diff.inHours / 24).ceil();
    return days < 0 ? 0 : days;
  }

  /// Доступен ли запуск пробного периода.
  bool get canStartTrial => !trialUsed && !isPro;

  SubscriptionState copyWith({
    SubscriptionTier? tier,
    Object? plan = _unset,
    bool? trial,
    Object? trialEndsAt = _unset,
    Object? expiresAt = _unset,
    bool? trialUsed,
    Object? purchaseToken = _unset,
  }) {
    return SubscriptionState(
      tier: tier ?? this.tier,
      plan: plan == _unset ? this.plan : plan as SubscriptionPlan?,
      trial: trial ?? this.trial,
      trialEndsAt: trialEndsAt == _unset
          ? this.trialEndsAt
          : trialEndsAt as DateTime?,
      expiresAt: expiresAt == _unset ? this.expiresAt : expiresAt as DateTime?,
      trialUsed: trialUsed ?? this.trialUsed,
      purchaseToken: purchaseToken == _unset
          ? this.purchaseToken
          : purchaseToken as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'tier': tier.name,
    'plan': plan?.id,
    'trial': trial,
    'trialEndsAt': trialEndsAt?.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'trialUsed': trialUsed,
    'purchaseToken': purchaseToken,
  };

  factory SubscriptionState.fromJson(Map<String, dynamic> json) {
    return SubscriptionState(
      tier: json['tier'] == SubscriptionTier.pro.name
          ? SubscriptionTier.pro
          : SubscriptionTier.free,
      plan: SubscriptionPlan.fromId(json['plan'] as String?),
      trial: json['trial'] as bool? ?? false,
      trialEndsAt: _parseDate(json['trialEndsAt']),
      expiresAt: _parseDate(json['expiresAt']),
      trialUsed: json['trialUsed'] as bool? ?? false,
      purchaseToken: json['purchaseToken'] as String?,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static const Object _unset = Object();
}
