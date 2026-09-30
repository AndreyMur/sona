import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Генерирует и хранит ключ шифрования локальной БД (SQLCipher).
class DatabaseKeyProvider {
  DatabaseKeyProvider(this._storage);

  static const String _keyName = 'sona.db_key';

  final FlutterSecureStorage _storage;

  /// Возвращает существующий ключ или создаёт новый (256 бит).
  Future<String> getOrCreate() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final key = base64UrlEncode(bytes);
    await _storage.write(key: _keyName, value: key);
    return key;
  }
}
