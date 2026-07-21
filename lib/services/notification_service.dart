import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

import 'package:flutter_timezone/flutter_timezone.dart';
import 'database_service.dart';
import '../models/reminder_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Define iOS actions
    final DarwinNotificationCategory category = DarwinNotificationCategory(
      'task_reminder_category',
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.plain('snooze_10', 'Snooze 10 min'),
        DarwinNotificationAction.plain('snooze_30', 'Snooze 30 min'),
        DarwinNotificationAction.plain('mark_complete', 'Mark Complete', options: <DarwinNotificationActionOption>{
          DarwinNotificationActionOption.destructive,
        }),
      ],
      options: <DarwinNotificationCategoryOption>{
        DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
      },
    );

    final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [category],
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationAction(response);
      },
    );

    // Phase 2: Time-zone detection and DST correction
    _checkAndHandleTimezoneChange();
  }

  Future<void> _checkAndHandleTimezoneChange() async {
    try {
      final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
      final prefs = await SharedPreferences.getInstance();
      final String? savedTimeZone = prefs.getString('saved_timezone');

      if (savedTimeZone != null && savedTimeZone != currentTimeZone) {
        print('[TIMEZONE] Timezone changed from \$savedTimeZone to \$currentTimeZone. Restoring alarms...');
        await restoreScheduledNotifications();
      }
      
      await prefs.setString('saved_timezone', currentTimeZone);
    } catch (e) {
      print('Failed to check timezone: \$e');
    }
  }

  // Phase 2: Automatic Restorer (For fresh installs or timezone changes)
  Future<void> restoreScheduledNotifications() async {
    // 1. Cancel all existing (to prevent duplicates)
    await flutterLocalNotificationsPlugin.cancelAll();

    // 2. Fetch all active local reminders from SQLite
    final db = DatabaseService();
    final String? userId = db.currentUserId;
    if (userId == null) return;

    final reminders = await db.getLocalReminders(userId);
    int restoreCount = 0;
    final now = DateTime.now();

    for (final reminder in reminders) {
      if (!reminder.isCompleted && !reminder.isSnoozed && reminder.scheduledTime.isAfter(now)) {
        final int stableId = reminder.id.hashCode & 0x7FFFFFFF;
        await _scheduleReminder(stableId, reminder);
        restoreCount++;
      } else if (reminder.isSnoozed && reminder.snoozeUntil != null && reminder.snoozeUntil!.isAfter(now)) {
        final int stableId = reminder.id.hashCode & 0x7FFFFFFF;
        await _snoozeNotification(stableId, reminder.taskId, reminder.snoozeUntil!.difference(now).inMinutes);
        restoreCount++;
      }
    }
    print('[RESTORE] Successfully rebuilt \$restoreCount local notifications from Reminder definitions.');
  }

  void _handleNotificationAction(NotificationResponse response) {
    if (response.actionId == 'snooze_10') {
      _snoozeNotification(response.id, response.payload, 10);
    } else if (response.actionId == 'snooze_30') {
      _snoozeNotification(response.id, response.payload, 30);
    } else if (response.actionId == 'mark_complete') {
      // Handled by providers later
      print("Task ${response.payload} marked complete via notification.");
    }
  }

  // --- Phase 2: Quiet Hours Logic ---
  Future<tz.TZDateTime> _applyQuietHours(tz.TZDateTime scheduledDate) async {
    final prefs = await SharedPreferences.getInstance();
    final bool quietHoursEnabled = prefs.getBool('quiet_hours_enabled') ?? false;
    if (!quietHoursEnabled) return scheduledDate;

    // Default quiet hours: 10 PM (22:00) to 7 AM (07:00)
    final int quietStart = prefs.getInt('quiet_hours_start_hour') ?? 22;
    final int quietEnd = prefs.getInt('quiet_hours_end_hour') ?? 7;
    
    final int hour = scheduledDate.hour;

    // Check if time falls within quiet hours (cross-midnight check)
    bool isInQuietHours = false;
    if (quietStart > quietEnd) {
      isInQuietHours = hour >= quietStart || hour < quietEnd;
    } else {
      isInQuietHours = hour >= quietStart && hour < quietEnd;
    }

    if (isInQuietHours) {
      // Delay to quietEnd time
      int daysToAdd = (hour >= quietStart && quietStart > quietEnd) ? 1 : 0;
      return tz.TZDateTime(
        tz.local,
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day + daysToAdd,
        quietEnd,
        0,
      );
    }
    return scheduledDate;
  }

  Future<void> _snoozeNotification(int? id, String? payload, int minutes) async {
    if (id == null) return;
    
    final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));
    
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'Snoozed Reminder',
      'You snoozed this task. Time to get to it!',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Task Reminders',
          channelDescription: 'Reminders for your daily tasks',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'task_reminder_category',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> _scheduleReminder(int id, ReminderModel reminder) async {
    if (reminder.scheduledTime.isBefore(DateTime.now())) return;

    tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(reminder.scheduledTime, tz.local);
    tzScheduledTime = await _applyQuietHours(tzScheduledTime);

    // Determine sound file based on reminder type
    String soundFile = 'reminder.wav';
    if (reminder.type == 'ACHIEVEMENT') soundFile = 'achievement.wav';
    else if (reminder.type == 'STREAK') soundFile = 'streak.wav';

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      reminder.title,
      reminder.body,
      tzScheduledTime,
      NotificationDetails(
        android: const AndroidNotificationDetails(
          'task_reminders',
          'Task Reminders',
          channelDescription: 'Reminders for your daily tasks',
          importance: Importance.max,
          priority: Priority.high,
          // Custom sound not yet defined in Android raw
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'task_reminder_category',
          sound: soundFile,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: reminder.deepLink ?? reminder.taskId,
      matchDateTimeComponents: reminder.repeatPattern == 'DAILY' ? DateTimeComponents.time : 
                               reminder.repeatPattern == 'WEEKLY' ? DateTimeComponents.dayOfWeekAndTime : null,
    );
  }

  // Legacy wrapper
  Future<void> scheduleTaskReminder(int id, String title, DateTime scheduledTime, String taskId) async {
    final reminder = ReminderModel(
      id: id.toString(),
      taskId: taskId,
      scheduledTime: scheduledTime,
      type: 'REMINDER',
      title: 'Task Reminder',
      body: title,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _scheduleReminder(id, reminder);
  }

  Future<void> scheduleDailyReminder(int id, String title, TimeOfDay time, String taskId) async {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    scheduledDate = await _applyQuietHours(scheduledDate);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'Daily Habit Reminder',
      title,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Task Reminders',
          channelDescription: 'Reminders for your daily tasks',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'task_reminder_category',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: taskId,
    );
  }

  Future<void> cancelReminder(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
    // Cancel the smart escalation automatically too
    await flutterLocalNotificationsPlugin.cancel(id + 1000000);
  }
}
