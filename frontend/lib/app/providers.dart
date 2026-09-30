import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/config/app_config.dart';
import '../data/local/app_database.dart';
import '../data/remote/interceptors.dart';
import '../data/remote/odirouter_client.dart';
import '../data/repositories/category_repository_impl.dart';
import '../data/repositories/operation_repository_impl.dart';
import '../data/services/audio_recorder_service.dart';
import '../data/services/connectivity_service_impl.dart';
import '../data/services/device_identity_store.dart';
import '../data/services/local_text_parser.dart';
import '../data/services/recording_file_store.dart';
import '../domain/repositories/operation_repository.dart';
import '../domain/models/category.dart';
import '../domain/models/operation.dart';
import '../domain/services/audio_recorder.dart';
import '../domain/services/connectivity_service.dart';
import '../domain/services/recognition_service.dart';
import '../domain/services/recording_file_store.dart';

/// Защищённое хранилище секретов приложения.
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

/// Базовый URL прокси.
final apiBaseUrlProvider = Provider<String>((ref) => AppConfig.apiBaseUrl);

BaseOptions _baseOptions(String baseUrl) => BaseOptions(
  baseUrl: baseUrl,
  connectTimeout: AppConfig.connectTimeout,
  receiveTimeout: AppConfig.receiveTimeout,
);

/// Dio без авторизации (регистрация устройства).
final registrationDioProvider = Provider<Dio>(
  (ref) => Dio(_baseOptions(ref.watch(apiBaseUrlProvider))),
);

/// Идентичность устройства (токен в secure storage).
final deviceIdentityProvider = Provider<DeviceIdentityStore>(
  (ref) => DeviceIdentityStore(
    ref.watch(registrationDioProvider),
    ref.watch(secureStorageProvider),
  ),
);

/// Основной Dio с interceptors: авторизация, retry, логирование.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(_baseOptions(ref.watch(apiBaseUrlProvider)));
  dio.interceptors.addAll([
    DeviceAuthInterceptor(
      ref.watch(deviceIdentityProvider),
      ref.watch(registrationDioProvider),
    ),
    RetryInterceptor(dio),
    if (kDebugMode)
      LogInterceptor(requestBody: false, responseBody: false),
  ]);
  return dio;
});

/// Клиент прокси OdiRouter.
final odiRouterClientProvider = Provider<OdiRouterClient>(
  (ref) => OdiRouterClient(ref.watch(dioProvider)),
);

/// Распознавание речи.
final speechRecognitionProvider = Provider<SpeechRecognitionService>(
  (ref) => ref.watch(odiRouterClientProvider),
);

/// Разбор текста в операции.
final textParsingProvider = Provider<TextParsingService>(
  (ref) => ref.watch(odiRouterClientProvider),
);

/// Локальный офлайн-разбор текста (регулярки + словарь категорий).
final localTextParserProvider = Provider<TextParsingService>(
  (ref) => const LocalTextParser(),
);

/// Отслеживание доступности сети.
final connectivityProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityPlusService(),
);

/// Запись аудио.
final audioRecorderProvider = Provider<AudioRecorderPort>((ref) {
  final recorder = RecordAudioRecorderService();
  ref.onDispose(recorder.dispose);
  return recorder;
});

/// Файловое хранилище аудиозаписей.
final recordingFileStoreProvider = Provider<RecordingFileStore>(
  (ref) => TemporaryRecordingFileStore(),
);

/// Локальная БД. Переопределяется в `main()` и в тестах.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider must be overridden'),
);

/// Репозиторий операций.
final operationRepositoryProvider = Provider<OperationRepository>(
  (ref) => DriftOperationRepository(ref.watch(appDatabaseProvider)),
);

/// Репозиторий категорий.
final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => DriftCategoryRepository(ref.watch(appDatabaseProvider)),
);

/// Категории с подкатегориями для UI.
final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).all(),
);

/// Последние операции для главной (и для проверки сохранения).
final recentOperationsProvider = StreamProvider<List<Operation>>(
  (ref) => ref.watch(operationRepositoryProvider).watchRecent(limit: 20),
);
