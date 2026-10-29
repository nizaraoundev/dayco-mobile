import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'client_annotations_service.dart';

/// Schedules the device notification that fires when a reminder falls due.
///
/// Scheduling is deliberately inexact: exact alarms need the
/// SCHEDULE_EXACT_ALARM permission on Android 12+, which the user has to grant
/// by hand and Google restricts to alarm-style apps. A reminder arriving within
/// a few minutes of its time is fine, and costs no extra permission.
class ReminderNotificationService {
  ReminderNotificationService._();

  static final ReminderNotificationService instance =
      ReminderNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
        'client_reminders',
        'Rappels clients',
        channelDescription: 'Rappels programmés sur les fiches clients',
        importance: Importance.high,
        priority: Priority.high,
      );

  bool _ready = false;

  /// Safe to call more than once; only the first call does the work.
  Future<void> init() async {
    if (_ready) return;

    try {
      tz_data.initializeTimeZones();

      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/launcher_icon'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      // Android 13+ only shows notifications once the user has agreed.
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();

      _ready = true;
    } catch (error) {
      debugPrint('Reminder notifications unavailable: $error');
    }
  }

  /// (Re)schedules one reminder. A reminder that is done, or already past, is
  /// cancelled rather than scheduled.
  Future<void> schedule(ClientReminder reminder) async {
    await init();
    if (!_ready) return;

    await cancel(reminder.id);
    if (reminder.done || !reminder.dueAt.isAfter(DateTime.now())) return;

    try {
      await _plugin.zonedSchedule(
        _notificationId(reminder.id),
        reminder.title.isEmpty ? 'Rappel client' : reminder.title,
        _body(reminder),
        tz.TZDateTime.from(reminder.dueAt, tz.local),
        const NotificationDetails(
          android: _androidDetails,
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // The due time is a wall-clock time the commercial chose, so it should
        // mean the same thing if they cross a timezone.
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: reminder.clientId,
      );
    } catch (error) {
      debugPrint('Could not schedule reminder ${reminder.id}: $error');
    }
  }

  Future<void> cancel(String reminderId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(_notificationId(reminderId));
    } catch (_) {
      // Cancelling something that was never scheduled is not an error.
    }
  }

  /// Re-arms everything on launch: Android drops pending alarms when the app
  /// is force-stopped or the device reboots.
  Future<void> rescheduleAll(List<ClientReminder> reminders) async {
    await init();
    if (!_ready) return;

    for (final reminder in reminders) {
      await schedule(reminder);
    }
  }

  String _body(ClientReminder reminder) {
    if (reminder.context.isNotEmpty) {
      return '${reminder.clientName} — ${reminder.context}';
    }
    return reminder.clientName;
  }

  /// Android notification ids are 32-bit ints, but reminder ids are timestamp
  /// strings, so they are hashed into range.
  int _notificationId(String reminderId) => reminderId.hashCode & 0x7fffffff;
}
