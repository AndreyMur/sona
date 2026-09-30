import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/data/remote/api_exception.dart';
import 'package:sona/data/remote/odirouter_client.dart';
import 'package:sona/domain/models/operation.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(ResponseBody Function(RequestOptions options) handler) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.httpClientAdapter = _FakeAdapter(handler);
  return dio;
}

void main() {
  test('transcribe разбирает ответ STT', () async {
    final dio = _dioWith(
      (_) => ResponseBody.fromString(
        '{"request_id":"r1","text":"такси 400",'
        '"model":"openai/gpt-4o-mini-transcribe","fallback_used":false,'
        '"duration_seconds":1.2,"latency_ms":500,"cost_usd":0.0001}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final client = OdiRouterClient(dio);

    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}sona_stt.m4a',
    );
    await file.writeAsBytes([0, 1, 2, 3]);
    addTearDown(() async {
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // Файл ещё удерживается платформой — временный каталог очистит ОС.
      }
    });

    final result = await client.transcribe(file.path);

    expect(result.text, 'такси 400');
    expect(result.model, 'openai/gpt-4o-mini-transcribe');
    expect(result.durationSeconds, 1.2);
  });

  test('parse разбирает несколько операций', () async {
    final dio = _dioWith(
      (_) => ResponseBody.fromString(
        '{"request_id":"r2","operations":['
        '{"type":"expense","amount":2300,"category":"Продукты",'
        '"subcategory":"Супермаркет","date":"2026-09-29","confidence":0.95},'
        '{"type":"expense","amount":600,"category":"Транспорт",'
        '"subcategory":"Такси","date":"2026-09-29","confidence":0.92}],'
        '"overall_confidence":0.94,"model":"google/gemini-3.8-flash",'
        '"fallback_used":false,"prompt_version":"1.0.0",'
        '"latency_ms":640,"cost_usd":0.00021}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final client = OdiRouterClient(dio);

    final result = await client.parse('продукты 2300 и такси 600');

    expect(result.operations, hasLength(2));
    expect(result.operations.first.category, 'Продукты');
    expect(result.operations.first.type, OperationType.expense);
    expect(result.operations[1].amount, 600);
    expect(result.overallConfidence, 0.94);
    expect(result.promptVersion, '1.0.0');
  });

  test('ошибка 402 маппится в quotaExceeded', () async {
    final dio = _dioWith(
      (_) => ResponseBody.fromString(
        '{"error":"free_limit_reached","message":"Лимит","request_id":"r3"}',
        402,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final client = OdiRouterClient(dio);

    await expectLater(
      client.parse('такси 400'),
      throwsA(
        isA<SonaApiException>().having(
          (e) => e.kind,
          'kind',
          SonaErrorKind.quotaExceeded,
        ),
      ),
    );
  });
}
