import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Хеширование PIN-кода приложения.
///
/// Сам PIN в открытом виде нигде не хранится: в защищённом хранилище лежит
/// только его соль-хеш. Значение соли фиксировано в коде и служит
/// дополнительным «перчиком» поверх шифрования хранилища.
abstract final class PinHasher {
  const PinHasher._();

  static const String _pepper = 'sona::app-lock::v1';

  /// Допустимая длина PIN-кода.
  static const int pinLength = 4;

  /// Проверяет, что строка — корректный PIN (ровно [pinLength] цифр).
  static bool isValid(String pin) =>
      RegExp(r'^\d{4}$').hasMatch(pin);

  /// Возвращает хеш PIN-кода.
  static String hash(String pin) {
    final digest = sha256.convert(utf8.encode('$_pepper::$pin'));
    return digest.toString();
  }

  /// Сверяет введённый PIN с сохранённым хешем.
  static bool verify(String pin, String? hash) {
    if (hash == null || hash.isEmpty) return false;
    return hash == PinHasher.hash(pin);
  }
}
