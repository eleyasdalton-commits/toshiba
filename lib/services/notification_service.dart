import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import 'database_service.dart';

/// Wraps flutter_local_notifications for all app alarms/notifications:
/// task/habit/challenge reminders, and the SRS "empty list at 8:00 AM"
/// daily check. All scheduling works fully offline.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _emptyListNotificationId = 999999;

  Future<void> init() async {
    tz_data.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    await _createChannel();
    await scheduleEmptyListCheck();
  }

  Future<void> _createChannel() async {
    const channel = AndroidNotificationChannel(
      'core_reminders',
      'Task & Habit Reminders',
      description: 'Alarms and reminders for tasks, habits and challenges',
      importance: Importance.max,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  NotificationDetails _details({String? sound}) => NotificationDetails(
        android: AndroidNotificationDetails(
          'core_reminders',
          'Task & Habit Reminders',
          importance: Importance.max,
          priority: Priority.high,
          sound: sound != null
              ? RawResourceAndroidNotificationSound(sound)
              : null,
          enableVibration: true,
        ),
      );

  /// Schedules a one-off alarm for a task, habit, or challenge. `id` should
  /// be a stable hash of the record's id so re-scheduling replaces it
  /// instead of duplicating it.
  Future<void> scheduleAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? sound,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      _details(sound: sound),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: null,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  Future<void> cancelAlarm(int id) => _plugin.cancel(id);

  /// SRS section 5, "Empty List Trigger": every morning at 8:00 AM, check
  /// whether any task has been logged for the day; if not, fire a
  /// notification prompting the user to plan their day.
  Future<void> scheduleEmptyListCheck() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 8, 0);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

   await _plugin.zonedSchedule(
      _emptyListNotificationId,
      'የዛሬ እቅድ',
      'የዛሬ እቅድ አልተመዘገበም! እባክዎ እቅድዎን ያስገቡ።',
      scheduled,
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  /// Call this from the notification's tap handler (or a background task)
  /// to suppress the reminder on days the user already planned ahead.
  Future<bool> shouldShowEmptyListReminder() async {
    return !(await DatabaseService.instance.hasAnyTaskToday());
  }
}
