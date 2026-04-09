import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/expense.dart';
import 'analytics_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    await Permission.notification.request();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: darwin);
    await _notifications.initialize(settings);
  }

  static Future<void> scheduleRecurringReminder(Expense exp, List<Expense> history) async {
    final predictions = AnalyticsService.predictNext(exp, history);
    for (var entry in predictions.entries) {
      final scheduled = entry.value!;
      final scheduledTZ = tz.TZDateTime.from(scheduled, tz.local);
      await _notifications.zonedSchedule(
        entry.key.hashCode,
        'Bill Reminder',
        'Your ${entry.key} bill may be due around ${DateFormat('dd MMM').format(scheduled)}',
        scheduledTZ,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'recurring_bills',
            'Recurring Bills',
            channelDescription: 'Reminders for expected bills',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  static Future<void> showDuplicateWarning(String merchant) async {
    await _notifications.show(
      'duplicate'.hashCode,
      'Possible Duplicate',
      'Similar bill from $merchant already exists. Review before saving.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'duplicates',
          'Duplicates',
          channelDescription: 'Duplicate bill warnings',
          importance: Importance.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// General purpose immediate notification used as a fallback for alerts.
  static Future<void> show(String title, String body) async {
    await _notifications.show(
      title.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'general_alerts',
          'General Alerts',
          channelDescription: 'General application alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}

