import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/models/app_settings.dart';
import '../../domain/services/app_settings_store.dart';

/// Хранит настройки в защищённом хранилище в виде JSON.
class SecureAppSettingsStore implements AppSettingsStore {
  SecureAppSettingsStore(this._storage);

  static const String _key = 'sona.app_settings';

  final FlutterSecureStorage _storage;

  @override
  Future<AppSettings> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return const AppSettings();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (_) {
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) {
    return _storage.write(key: _key, value: jsonEncode(settings.toJson()));
  }
}
