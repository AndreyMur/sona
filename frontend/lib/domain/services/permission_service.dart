/// Результат запроса системного разрешения.
enum SonaPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

/// Запрос системных разрешений (микрофон, уведомления).
abstract interface class PermissionService {
  /// Текущий статус доступа к микрофону без показа диалога.
  Future<SonaPermissionStatus> microphoneStatus();

  /// Запрашивает доступ к микрофону (может показать системный диалог).
  Future<SonaPermissionStatus> requestMicrophone();

  /// Текущий статус разрешения на уведомления.
  Future<SonaPermissionStatus> notificationStatus();

  /// Запрашивает разрешение на уведомления.
  Future<SonaPermissionStatus> requestNotifications();
}
