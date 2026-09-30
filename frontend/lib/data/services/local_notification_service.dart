import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../core/utils/budget_alerts.dart';
import '../../domain/services/notification_service.dart';

/// Реализация [SonaNotifications] на плагине flutter_local_notifications.
///
/// Ежедневное напоминание планируем неточным будильником
/// (не требует разрешения на точные alarm'ы).
class LocalNotificationsService implements SonaNotifications {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String _channelId = 'budget_alerts';
  static const String _channelName = 'Бюджет и лимиты';

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(_guessLocalLocation());
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    await initialize();
    final now = tz.TZDateTime.now(tz.local);
    var moment = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!moment.isAfter(now)) {
      moment = moment.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      BudgetAlerts.idDailyReminder,
      BudgetAlerts.dailyReminderTitle,
      BudgetAlerts.dailyReminderBody,
      moment,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.low,
          priority: Priority.low,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancelDailyReminder() async {
    await initialize();
    await _plugin.cancel(BudgetAlerts.idDailyReminder);
  }

  /// Часовой пояс устройства: подбираем город с тем же смещением UTC,
  /// при неудаче — Европа/Москва (RU-ориентированное приложение).
  tz.Location _guessLocalLocation() {
    final offset = DateTime.now().timeZoneOffset;
    const candidates = [
      'Europe/Moscow',
      'Europe/Kaliningrad',
      'Europe/Samara',
      'Asia/Yekaterinburg',
      'Asia/Novosibirsk',
      'Asia/Krasnoyarsk',
      'Asia/Irkutsk',
      'Asia/Vladivostok',
      'UTC',
    ];
    for (final name in candidates) {
      final location = tz.getLocation(name);
      if (location.currentTimeZone.offset == offset.inSeconds) {
        return location;
      }
    }
    return tz.getLocation('Europe/Moscow');
  }
}
