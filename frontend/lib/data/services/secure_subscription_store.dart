import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/models/subscription.dart';
import '../../domain/services/subscription_store.dart';

/// Хранит состояние подписки в защищённом хранилище в виде JSON.
class SecureSubscriptionStore implements SubscriptionStore {
  SecureSubscriptionStore(this._storage);

  static const String _key = 'sona.subscription';

  final FlutterSecureStorage _storage;

  @override
  Future<SubscriptionState> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return const SubscriptionState();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return SubscriptionState.fromJson(json);
    } catch (_) {
      return const SubscriptionState();
    }
  }

  @override
  Future<void> save(SubscriptionState state) {
    return _storage.write(key: _key, value: jsonEncode(state.toJson()));
  }
}
