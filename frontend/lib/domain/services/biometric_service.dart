/// Порт биометрической аутентификации (Face ID / Touch ID / отпечаток).
abstract interface class BiometricService {
  /// Доступна ли биометрия на устройстве и настроена ли она.
  Future<bool> isAvailable();

  /// Запрашивает биометрическую аутентификацию.
  ///
  /// Возвращает `true`, если пользователь успешно подтвердил личность.
  Future<bool> authenticate({required String reason});
}
