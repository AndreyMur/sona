import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../domain/models/operation.dart';
import '../../domain/models/recognition.dart';
import '../../domain/models/subscription.dart';
import '../../domain/services/recognition_service.dart';
import '../../domain/services/subscription_gateway.dart';
import 'api_exception.dart';

/// Клиент self-hosted прокси к OdiRouter.
///
/// Реализует распознавание речи (STT) и разбор текста (NLU). Ключ OdiRouter
/// хранится на сервере и в приложение не попадает.
class OdiRouterClient
    implements SpeechRecognitionService, TextParsingService, SubscriptionGateway {
  OdiRouterClient(this._dio);

  final Dio _dio;

  @override
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    String quality = 'standard',
    String language = 'ru',
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        audioPath,
        filename: p.basename(audioPath),
      ),
      'quality': quality,
      'language': language,
    });

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/audio/transcriptions',
        data: form,
      );
      final data = response.data ?? const {};
      return TranscriptionResult(
        text: (data['text'] as String?) ?? '',
        model: (data['model'] as String?) ?? '',
        fallbackUsed: (data['fallback_used'] as bool?) ?? false,
        durationSeconds: (data['duration_seconds'] as num?)?.toDouble() ?? 0,
        latencyMs: (data['latency_ms'] as num?)?.toInt() ?? 0,
        costUsd: (data['cost_usd'] as num?)?.toDouble() ?? 0,
        requestId: (data['request_id'] as String?) ?? '',
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<ParseResult> parse(String text) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/parse',
        data: {'text': text},
      );
      final data = response.data ?? const {};
      final rawOperations = (data['operations'] as List?) ?? const [];
      return ParseResult(
        operations: rawOperations
            .whereType<Map>()
            .map((json) => _parsedFromJson(json.cast<String, dynamic>()))
            .toList(),
        overallConfidence:
            (data['overall_confidence'] as num?)?.toDouble() ?? 0,
        model: (data['model'] as String?) ?? '',
        fallbackUsed: (data['fallback_used'] as bool?) ?? false,
        promptVersion: (data['prompt_version'] as String?) ?? '',
        latencyMs: (data['latency_ms'] as num?)?.toInt() ?? 0,
        costUsd: (data['cost_usd'] as num?)?.toDouble() ?? 0,
        requestId: (data['request_id'] as String?) ?? '',
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  /// Забирает категории из remote config прокси.
  Future<Map<String, List<String>>> fetchCategories() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/v1/config');
      final raw = (response.data?['categories'] as Map?) ?? const {};
      return raw.map(
        (key, value) => MapEntry(
          key.toString(),
          (value as List?)?.map((e) => e.toString()).toList() ?? const [],
        ),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  /// Сообщает прокси об активации Sona Pro.
  @override
  Future<void> activate({
    required SubscriptionPlan plan,
    String? platform,
    String? purchaseToken,
    bool trial = false,
    DateTime? expiresAt,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/v1/subscription',
        data: {
          'plan': plan.id,
          'platform': ?platform,
          'purchase_token': ?purchaseToken,
          'trial': trial,
          if (expiresAt != null)
            'expires_at': expiresAt.toUtc().toIso8601String(),
        },
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  /// Возвращает устройство на бесплатный тариф.
  @override
  Future<void> deactivate() async {
    try {
      await _dio.delete<Map<String, dynamic>>('/v1/subscription');
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  ParsedOperation _parsedFromJson(Map<String, dynamic> json) {
    return ParsedOperation(
      type: OperationType.fromWire((json['type'] as String?) ?? 'expense'),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      category: (json['category'] as String?) ?? 'Другое',
      subcategory: json['subcategory'] as String?,
      date: _parseDate(json['date'] as String?),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1,
    );
  }

  DateTime _parseDate(String? value) {
    if (value == null || value.isEmpty) return DateTime.now();
    return DateTime.tryParse(value) ?? DateTime.now();
  }
}
