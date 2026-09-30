import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../remote/api_exception.dart';

/// Идентичность устройства на прокси Sona.
class DeviceIdentity {
  const DeviceIdentity({
    required this.deviceId,
    required this.token,
    required this.tier,
  });

  final String deviceId;
  final String token;
  final String tier;

  bool get isPro => tier == 'pro';
}

/// Хранит токен устройства в защищённом хранилище и регистрирует новое
/// устройство при первом обращении (анонимная регистрация).
class DeviceIdentityStore {
  DeviceIdentityStore(this._dio, this._storage);

  static const String _tokenKey = 'sona.device_token';
  static const String _deviceIdKey = 'sona.device_id';
  static const String _tierKey = 'sona.device_tier';

  final Dio _dio;
  final FlutterSecureStorage _storage;
  Future<DeviceIdentity>? _pending;

  /// Возвращает токен устройства, регистрируя его при необходимости.
  Future<String> ensureToken() async => (await ensureIdentity()).token;

  /// Возвращает полную идентичность устройства.
  Future<DeviceIdentity> ensureIdentity() {
    final pending = _pending;
    if (pending != null) return pending;

    final future = _loadOrRegister();
    _pending = future;
    return future.whenComplete(() {
      if (identical(_pending, future)) _pending = null;
    });
  }

  /// Сохраняет обновлённый тариф (например, после апгрейда до Pro).
  Future<void> updateTier(String tier) => _storage.write(key: _tierKey, value: tier);

  /// Сбрасывает сохранённый токен (например, при 401).
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _deviceIdKey);
    await _storage.delete(key: _tierKey);
  }

  Future<DeviceIdentity> _loadOrRegister() async {
    final token = await _storage.read(key: _tokenKey);
    final deviceId = await _storage.read(key: _deviceIdKey);
    final tier = await _storage.read(key: _tierKey);
    if (token != null && token.isNotEmpty && deviceId != null) {
      return DeviceIdentity(deviceId: deviceId, token: token, tier: tier ?? 'free');
    }
    return _register();
  }

  Future<DeviceIdentity> _register() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/devices/register',
      );
      final data = response.data!;
      final identity = DeviceIdentity(
        deviceId: data['device_id'] as String,
        token: data['device_token'] as String,
        tier: (data['tier'] as String?) ?? 'free',
      );
      await _storage.write(key: _tokenKey, value: identity.token);
      await _storage.write(key: _deviceIdKey, value: identity.deviceId);
      await _storage.write(key: _tierKey, value: identity.tier);
      return identity;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}
