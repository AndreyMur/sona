/// Порт отслеживания доступности сети.
abstract interface class ConnectivityService {
  /// Есть ли сейчас подключение.
  Future<bool> get isOnline;

  /// Поток изменений статуса сети (`true` — есть подключение).
  Stream<bool> get onStatusChange;
}
