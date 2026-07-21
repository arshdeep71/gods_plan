import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'database_service.dart';
import '../models/reminder_model.dart';
import '../models/notification_history_model.dart';
import 'package:uuid/uuid.dart';

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
    
    // Phase 4: Process missed notifications for accurate history
    _processMissedNotifications();
    
    // Clear badges on launch
    await clearAppBadge();
  }

  Future<void> clearAppBadge() async {
    try {
      if (await FlutterAppBadger.isAppBadgeSupported()) {
        await FlutterAppBadger.removeBadge();
      }
    } catch (_) {}
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
        await scheduleReminder(stableId, reminder);
        restoreCount++;
      } else if (reminder.isSnoozed && reminder.snoozeUntil != null && reminder.snoozeUntil!.isAfter(now)) {
        final int stableId = reminder.id.hashCode & 0x7FFFFFFF;
        await _snoozeNotification(stableId, reminder.taskId, reminder.id, reminder.snoozeUntil!.difference(now).inMinutes);
        restoreCount++;
      }
    }
    print('[RESTORE] Successfully rebuilt \$restoreCount local notifications from Reminder definitions.');
  }

  Future<void> _processMissedNotifications() async {
    try {
      final db = DatabaseService();
      final userId = db.currentUserId;
      if (userId == null) return;

      final reminders = await db.getLocalReminders(userId);
      final now = DateTime.now();
      int missedCount = 0;

      for (final reminder in reminders) {
        if (!reminder.isCompleted && reminder.scheduledTime.isBefore(now)) {
          // Check if this history record already exists to avoid duplicates
          final historyList = await db.getLocalNotificationHistory(userId);
          final exists = historyList.any((h) => h.relatedId == reminder.taskId && h.timestamp.isAtSameMomentAs(reminder.scheduledTime));
          
          if (!exists) {
            final history = NotificationHistoryModel(
              id: const Uuid().v4(),
              title: reminder.title,
              body: reminder.body,
              timestamp: reminder.scheduledTime,
              type: reminder.type,
              status: 'MISSED',
              relatedId: reminder.taskId,
              category: reminder.category,
              userId: userId,
            );
            await db.insertLocalNotificationHistory(history);
            missedCount++;
          }
        }
      }
      
      if (missedCount > 0) {
        print('[HISTORY] Processed \$missedCount missed notifications into history.');
      }
    } catch (e) {
      print('Failed to process missed notifications: \$e');
    }
  }

  void _handleNotificationAction(NotificationResponse response) {
    final payloadStr = response.payload;
    if (payloadStr == null) return;
    
    final parts = payloadStr.split('|');
    final taskId = parts[0];
    final reminderId = parts.length > 1 ? parts[1] : null;
    
    // Log interaction to history
    _logActionToHistory(taskId, reminderId, response.actionId);

    if (response.actionId == 'snooze_10') {
      _snoozeNotification(response.id, taskId, reminderId, 10);
    } else if (response.actionId == 'snooze_30') {
      _snoozeNotification(response.id, taskId, reminderId, 30);
    } else if (response.actionId == 'mark_complete') {
      // Handled by providers later
      print("Task $taskId marked complete via notification.");
    }
  }

  Future<void> _logActionToHistory(String taskId, String? reminderId, String? actionId) async {
    try {
      final db = DatabaseService();
      final userId = db.currentUserId;
      if (userId == null) return;

      final history = NotificationHistoryModel(
        id: const Uuid().v4(),
        title: 'Interaction',
        body: actionId == 'mark_complete' ? 'Marked complete from notification' : 'Snoozed from notification',
        timestamp: DateTime.now(),
        type: 'ACTION',
        status: 'DELIVERED',
        relatedId: taskId,
        userId: userId,
      );
      await db.insertLocalNotificationHistory(history);
      
      // Update badge count
      if (await FlutterAppBadger.isAppBadgeSupported()) {
        FlutterAppBadger.updateBadgeCount(1);
      }
    } catch (_) {}
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

  Future<void> _snoozeNotification(int? id, String? taskId, String? reminderId, int minutes) async {
    if (id == null) return;
    
    // Cancel original escalations
    await cancelReminder(id);

    final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));
    final scheduledDateUtc = scheduledDate.toUtc();

    // Update reminder state in database if reminderId is provided
    if (reminderId != null) {
      try {
        final db = DatabaseService();
        final userId = db.currentUserId;
        if (userId != null) {
          final reminders = await db.getLocalReminders(userId);
          final match = reminders.firstWhere((r) => r.id == reminderId);
          final updatedReminder = match.copyWith(
            isSnoozed: true,
            snoozeUntil: scheduledDateUtc,
            updatedAt: DateTime.now(),
          );
          await db.upsertLocalReminder(updatedReminder);
        }
      } catch (e) {
        print("Failed to update reminder snooze state in DB: $e");
      }
    }

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
      payload: "$taskId|$reminderId",
    );

    // Schedule snoozed escalation reminders
    final prefs = await SharedPreferences.getInstance();
    final bool enableEscalation = prefs.getBool('smart_escalation_enabled') ?? true;
    if (enableEscalation) {
      final List<String> intervalStrings = prefs.getStringList('smart_escalation_intervals') ?? ['10', '30'];
      final List<int> intervals = intervalStrings.map((s) => int.tryParse(s) ?? 0).where((i) => i > 0).toList();

      for (int i = 0; i < intervals.length; i++) {
        final minutesEsc = intervals[i];
        final tzEsc = scheduledDate.add(Duration(minutes: minutesEsc));
        final escalationId = id + (i + 1) * 1000000;

        await flutterLocalNotificationsPlugin.zonedSchedule(
          escalationId,
          i == 0 ? 'Snooze Friendly Reminder' : 'Snooze Final Reminder',
          i == 0 ? 'Have you completed your snoozed task?' : 'Last call to complete your snoozed task!',
          tzEsc,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'escalation_reminders',
              'Escalation Reminders',
              channelDescription: 'Follow-ups for missed tasks',
              importance: i == 0 ? Importance.high : Importance.max,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
              categoryIdentifier: 'task_reminder_category',
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: "$taskId|$reminderId",
        );
      }
    }
  }

  Future<void> scheduleReminder(int id, ReminderModel reminder) async {
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
      payload: "${reminder.taskId}|${reminder.id}",
      matchDateTimeComponents: reminder.repeatPattern == 'DAILY' ? DateTimeComponents.time : 
                               reminder.repeatPattern == 'WEEKLY' ? DateTimeComponents.dayOfWeekAndTime : null,
    );

    // Phase 3: Smart Reminder Escalation (Schedule dynamic follow-ups)
    final prefs = await SharedPreferences.getInstance();
    final bool enableEscalation = prefs.getBool('smart_escalation_enabled') ?? true;
    if (enableEscalation) {
      final List<String> intervalStrings = prefs.getStringList('smart_escalation_intervals') ?? ['10', '30'];
      final List<int> intervals = intervalStrings.map((s) => int.tryParse(s) ?? 0).where((i) => i > 0).toList();

      for (int i = 0; i < intervals.length; i++) {
        final minutesEsc = intervals[i];
        tz.TZDateTime tzEsc = tzScheduledTime.add(Duration(minutes: minutesEsc));
        tzEsc = await _applyQuietHours(tzEsc);
        final escalationId = id + (i + 1) * 1000000;

        await flutterLocalNotificationsPlugin.zonedSchedule(
          escalationId,
          i == 0 ? 'Friendly Reminder' : 'Final Reminder',
          i == 0 ? 'Have you completed "${reminder.title}"?' : 'Last call to complete "${reminder.title}"!',
          tzEsc,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'escalation_reminders',
              'Escalation Reminders',
              channelDescription: 'Follow-ups for missed tasks',
              importance: i == 0 ? Importance.high : Importance.max,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
              categoryIdentifier: 'task_reminder_category',
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: "${reminder.taskId}|${reminder.id}",
        );
      }
    }
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
    await scheduleReminder(id, reminder);
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
    // Cancel up to 5 levels of smart escalations
    for (int i = 1; i <= 5; i++) {
      await flutterLocalNotificationsPlugin.cancel(id + i * 1000000);
    }
  }
}
