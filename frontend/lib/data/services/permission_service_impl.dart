import 'package:permission_handler/permission_handler.dart';

import '../../domain/services/permission_service.dart';

/// Запрос разрешений через пакет `permission_handler`.
class PermissionHandlerService implements PermissionService {
  const PermissionHandlerService();

  @override
  Future<SonaPermissionStatus> microphoneStatus() =>
      _status(Permission.microphone);

  @override
  Future<SonaPermissionStatus> requestMicrophone() =>
      _request(Permission.microphone);

  @override
  Future<SonaPermissionStatus> notificationStatus() =>
      _status(Permission.notification);

  @override
  Future<SonaPermissionStatus> requestNotifications() =>
      _request(Permission.notification);

  Future<SonaPermissionStatus> _status(Permission permission) async {
    try {
      return _map(await permission.status);
    } catch (_) {
      return SonaPermissionStatus.denied;
    }
  }

  Future<SonaPermissionStatus> _request(Permission permission) async {
    try {
      return _map(await permission.request());
    } catch (_) {
      return SonaPermissionStatus.denied;
    }
  }

  SonaPermissionStatus _map(PermissionStatus status) {
    return switch (status) {
      PermissionStatus.granted || PermissionStatus.limited ||
      PermissionStatus.provisional => SonaPermissionStatus.granted,
      PermissionStatus.permanentlyDenied =>
        SonaPermissionStatus.permanentlyDenied,
      PermissionStatus.restricted => SonaPermissionStatus.restricted,
      _ => SonaPermissionStatus.denied,
    };
  }
}
