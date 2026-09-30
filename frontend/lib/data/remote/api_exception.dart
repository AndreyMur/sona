import 'package:dio/dio.dart';

/// Категория ошибки обращения к прокси Sona.
enum SonaErrorKind {
  network,
  timeout,
  unauthorized,
  quotaExceeded,
  rateLimited,
  server,
  badRequest,
  unknown,
}

/// Типизированная ошибка API, пригодная для показа пользователю.
class SonaApiException implements Exception {
  const SonaApiException({
    required this.kind,
    required this.message,
    this.code = 'unknown',
    this.statusCode,
    this.requestId,
  });

  final SonaErrorKind kind;
  final String message;
  final String code;
  final int? statusCode;
  final String? requestId;

  bool get isRetryable =>
      kind == SonaErrorKind.network ||
      kind == SonaErrorKind.timeout ||
      kind == SonaErrorKind.server ||
      kind == SonaErrorKind.rateLimited;

  @override
  String toString() => 'SonaApiException($code, $statusCode): $message';
}

/// Преобразует [DioException] в [SonaApiException].
SonaApiException mapDioException(DioException error) {
  final response = error.response;
  final data = response?.data;
  final backendCode = data is Map ? data['error'] as String? : null;
  final backendMessage = data is Map ? data['message'] as String? : null;
  final requestId = data is Map ? data['request_id'] as String? : null;
  final status = response?.statusCode;

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return SonaApiException(
        kind: SonaErrorKind.timeout,
        message: 'Сервис не ответил вовремя. Попробуйте ещё раз.',
        code: 'timeout',
      );
    case DioExceptionType.connectionError:
      return SonaApiException(
        kind: SonaErrorKind.network,
        message: 'Нет соединения. Проверьте интернет.',
        code: 'network',
      );
    case DioExceptionType.badResponse:
      return _mapStatus(status, backendCode, backendMessage, requestId);
    case DioExceptionType.cancel:
      return const SonaApiException(
        kind: SonaErrorKind.unknown,
        message: 'Запрос отменён.',
        code: 'cancelled',
      );
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return SonaApiException(
        kind: SonaErrorKind.network,
        message: 'Не удалось связаться с сервисом.',
        code: backendCode ?? 'network',
        requestId: requestId,
      );
  }
}

SonaApiException _mapStatus(
  int? status,
  String? code,
  String? message,
  String? requestId,
) {
  switch (status) {
    case 400:
    case 415:
      return SonaApiException(
        kind: SonaErrorKind.badRequest,
        message: message ?? 'Некорректный запрос.',
        code: code ?? 'bad_request',
        statusCode: status,
        requestId: requestId,
      );
    case 401:
      return SonaApiException(
        kind: SonaErrorKind.unauthorized,
        message: 'Устройство не авторизовано.',
        code: code ?? 'unauthorized',
        statusCode: status,
        requestId: requestId,
      );
    case 402:
      return SonaApiException(
        kind: SonaErrorKind.quotaExceeded,
        message: message ?? 'Лимит бесплатных операций исчерпан.',
        code: code ?? 'quota_exceeded',
        statusCode: status,
        requestId: requestId,
      );
    case 429:
      return SonaApiException(
        kind: SonaErrorKind.rateLimited,
        message: 'Слишком много запросов. Подождите немного.',
        code: code ?? 'rate_limited',
        statusCode: status,
        requestId: requestId,
      );
    default:
      if (status != null && status >= 500) {
        return SonaApiException(
          kind: SonaErrorKind.server,
          message: 'Сервис временно недоступен.',
          code: code ?? 'server_error',
          statusCode: status,
          requestId: requestId,
        );
      }
      return SonaApiException(
        kind: SonaErrorKind.unknown,
        message: message ?? 'Неизвестная ошибка.',
        code: code ?? 'unknown',
        statusCode: status,
        requestId: requestId,
      );
  }
}
