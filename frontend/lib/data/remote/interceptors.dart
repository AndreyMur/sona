import 'dart:math';

import 'package:dio/dio.dart';

import '../services/device_identity_store.dart';

/// Подставляет `Authorization: Bearer <device_token>` и один раз
/// перерегистрирует устройство при 401.
class DeviceAuthInterceptor extends Interceptor {
  DeviceAuthInterceptor(this._identity, this._retryClient);

  final DeviceIdentityStore _identity;
  final Dio _retryClient;

  static const String _retriedKey = 'sona.auth_retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _identity.ensureToken();
      options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    } catch (error) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra[_retriedKey] == true;
    if (!isUnauthorized || alreadyRetried) {
      handler.next(err);
      return;
    }

    await _identity.clear();
    try {
      final token = await _identity.ensureToken();
      final options = err.requestOptions
        ..headers['Authorization'] = 'Bearer $token'
        ..extra[_retriedKey] = true;
      final response = await _retryClient.fetch(options);
      handler.resolve(response);
    } catch (_) {
      handler.next(err);
    }
  }
}

/// Повторяет идемпотентные и сетевые сбои с экспоненциальной задержкой.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(
    this._client, {
    this.maxRetries = 2,
    this.baseDelay = const Duration(milliseconds: 300),
  });

  final Dio _client;
  final int maxRetries;
  final Duration baseDelay;

  static const String _attemptKey = 'sona.retry_attempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = (err.requestOptions.extra[_attemptKey] as int?) ?? 0;
    if (attempt >= maxRetries || !_isRetryable(err)) {
      handler.next(err);
      return;
    }

    final delay = baseDelay * pow(2, attempt).toDouble();
    await Future<void>.delayed(delay);

    try {
      final options = err.requestOptions
        ..extra[_attemptKey] = attempt + 1;
      final response = await _client.fetch(options);
      handler.resolve(response);
    } catch (error) {
      handler.next(error is DioException ? error : err);
    }
  }

  bool _isRetryable(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return true;
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode ?? 0;
        return status == 408 || status == 429 || status >= 500;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return false;
    }
  }
}
