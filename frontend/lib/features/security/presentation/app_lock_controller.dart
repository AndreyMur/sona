import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/pin_hasher.dart';

/// Состояние защиты входа.
@immutable
class AppLockState {
  const AppLockState({
    this.enabled = false,
    this.locked = false,
    this.biometricEnabled = false,
    this.busy = false,
    this.error,
  });

  /// Включена ли защита входа.
  final bool enabled;

  /// Заблокировано ли приложение прямо сейчас.
  final bool locked;

  /// Разрешён ли вход по биометрии.
  final bool biometricEnabled;

  /// Идёт ли биометрическая аутентификация.
  final bool busy;

  /// Текст последней ошибки ввода.
  final String? error;

  AppLockState copyWith({
    bool? enabled,
    bool? locked,
    bool? biometricEnabled,
    bool? busy,
    Object? error = _unset,
  }) {
    return AppLockState(
      enabled: enabled ?? this.enabled,
      locked: locked ?? this.locked,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      busy: busy ?? this.busy,
      error: error == _unset ? this.error : error as String?,
    );
  }

  static const Object _unset = Object();
}

/// Управляет защитой входа: блокировкой, PIN и биометрией.
class AppLockController extends Notifier<AppLockState> {
  @override
  AppLockState build() {
    final settings = ref.read(appSettingsProvider).value;
    final enabled = settings?.appLockEnabled ?? false;

    // Настройки загружаются асинхронно: как только защита включена (или
    // выключена), синхронизируем состояние и запираем приложение.
    ref.listen(appSettingsProvider, (previous, next) {
      final wasEnabled = previous?.value?.appLockEnabled ?? false;
      final isEnabled = next.value?.appLockEnabled ?? false;
      if (isEnabled != wasEnabled) {
        state = state.copyWith(
          enabled: isEnabled,
          locked: isEnabled,
          error: null,
          busy: false,
        );
        return;
      }
      final biometric = next.value?.biometricEnabled ?? false;
      if (biometric != state.biometricEnabled) {
        state = state.copyWith(biometricEnabled: biometric);
      }
    });

    return AppLockState(
      enabled: enabled,
      locked: enabled,
      biometricEnabled: settings?.biometricEnabled ?? false,
    );
  }

  /// Включает защиту входа и задаёт PIN.
  Future<bool> enableWithPin(String pin) async {
    if (!PinHasher.isValid(pin)) {
      state = state.copyWith(error: 'PIN должен состоять из 4 цифр');
      return false;
    }
    await ref
        .read(appSettingsProvider.notifier)
        .enableAppLock(PinHasher.hash(pin));
    state = state.copyWith(enabled: true, locked: true, error: null);
    return true;
  }

  /// Меняет PIN-код.
  Future<bool> changePin(String pin) async {
    if (!PinHasher.isValid(pin)) {
      state = state.copyWith(error: 'PIN должен состоять из 4 цифр');
      return false;
    }
    await ref.read(appSettingsProvider.notifier).setPinHash(PinHasher.hash(pin));
    state = state.copyWith(error: null);
    return true;
  }

  /// Полностью выключает защиту входа.
  Future<void> disable() async {
    await ref.read(appSettingsProvider.notifier).disableAppLock();
    state = state.copyWith(
      enabled: false,
      locked: false,
      biometricEnabled: false,
      error: null,
    );
  }

  /// Пытается разблокировать приложение по PIN.
  Future<bool> unlockWithPin(String pin) async {
    final settings = ref.read(appSettingsProvider).value;
    if (PinHasher.verify(pin, settings?.pinHash)) {
      state = state.copyWith(locked: false, error: null);
      return true;
    }
    state = state.copyWith(error: 'Неверный PIN');
    return false;
  }

  /// Пытается разблокировать приложение по биометрии.
  Future<bool> unlockWithBiometrics() async {
    final settings = ref.read(appSettingsProvider).value;
    if (settings?.biometricEnabled != true) return false;

    state = state.copyWith(busy: true, error: null);
    final granted = await ref
        .read(biometricServiceProvider)
        .authenticate(reason: 'Вход в Sona');
    state = state.copyWith(
      busy: false,
      locked: !granted,
      error: granted ? null : 'Биометрия не подтверждена',
    );
    return granted;
  }

  /// Включает или выключает вход по биометрии.
  Future<bool> setBiometric(bool value) async {
    if (value) {
      final available = await ref.read(biometricServiceProvider).isAvailable();
      if (!available) {
        state = state.copyWith(error: 'Биометрия недоступна на устройстве');
        return false;
      }
    }
    await ref.read(appSettingsProvider.notifier).setBiometricEnabled(value);
    state = state.copyWith(biometricEnabled: value, error: null);
    return true;
  }

  /// Задаёт задержку автоблокировки.
  Future<void> setAutoLockSeconds(int seconds) async {
    await ref.read(appSettingsProvider.notifier).setAutoLockSeconds(seconds);
  }

  /// Блокирует приложение (автоблокировка).
  void lock() {
    if (!state.enabled || state.locked) return;
    state = state.copyWith(locked: true, error: null);
  }

  /// Сбрасывает текст ошибки.
  void clearError() {
    if (state.error == null) return;
    state = state.copyWith(error: null);
  }
}

/// Провайдер защиты входа.
final appLockProvider =
    NotifierProvider<AppLockController, AppLockState>(AppLockController.new);
