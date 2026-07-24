import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:intl/intl.dart';
import 'database_service.dart';
import 'live_activity_service.dart';
import '../models/reminder_model.dart';
import '../models/notification_history_model.dart';
import '../utils/notification_templates.dart';
import 'package:uuid/uuid.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) return;
    try {
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
    } catch (e) {
      debugPrint("NotificationService init error (continuing startup): $e");
    }
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
    if (kIsWeb) return;
    debugPrint("START: restoreScheduledNotifications()");

    try {
      // STATEMENT A: flutterLocalNotificationsPlugin.cancelAll()
      try {
        debugPrint("STATEMENT A: cancelAll()");
        await flutterLocalNotificationsPlugin.cancelAll();
        debugPrint("STATEMENT A OK");
      } catch (e, st) {
        debugPrint("STATEMENT A FAILED (handled): $e");
        debugPrintStack(stackTrace: st);
      }

      // STATEMENT B: DatabaseService() & db.currentUserId
      final db = DatabaseService();
      String? userId;
      try {
        debugPrint("STATEMENT B: db.currentUserId");
        userId = db.currentUserId;
        debugPrint("STATEMENT B OK: userId=$userId");
      } catch (e, st) {
        debugPrint("STATEMENT B FAILED (handled): $e");
        debugPrintStack(stackTrace: st);
        return;
      }

      if (userId == null || userId.isEmpty) {
        debugPrint("STATEMENT B RETURN: userId is null or empty, returning early.");
        return;
      }

      // STATEMENT C: db.getLocalReminders(userId)
      List<ReminderModel> reminders = [];
      try {
        debugPrint("STATEMENT C: db.getLocalReminders(userId)");
        reminders = await db.getLocalReminders(userId);
        debugPrint("STATEMENT C OK: count=${reminders.length}");
      } catch (e, st) {
        debugPrint("STATEMENT C FAILED (handled): $e");
        debugPrintStack(stackTrace: st);
        return;
      }

      int restoreCount = 0;
      final now = DateTime.now();
      debugPrint("STATEMENT D: Loop over ${reminders.length} reminders (now=$now)");

      for (final reminder in reminders) {
        try {
          debugPrint("STATEMENT D-ITEM: Processing reminder id=${reminder.id}");
          if (!reminder.isCompleted && !reminder.isSnoozed && reminder.scheduledTime.isAfter(now)) {
            final int stableId = reminder.id.hashCode & 0x7FFFFFFF;
            debugPrint("STATEMENT D-SCHEDULE: Calling scheduleReminder for id=${reminder.id}");
            await scheduleReminder(stableId, reminder);
            restoreCount++;
            debugPrint("STATEMENT D-SCHEDULE OK: Finished id=${reminder.id}");
          } else if (reminder.isSnoozed && reminder.snoozeUntil != null && reminder.snoozeUntil!.isAfter(now)) {
            final int stableId = reminder.id.hashCode & 0x7FFFFFFF;
            debugPrint("STATEMENT D-SNOOZE: Calling _snoozeNotification for id=${reminder.id}");
            await _snoozeNotification(stableId, reminder.taskId, reminder.id, reminder.snoozeUntil!.difference(now).inMinutes);
            restoreCount++;
            debugPrint("STATEMENT D-SNOOZE OK: Finished id=${reminder.id}");
          } else {
            debugPrint("STATEMENT D-SKIP: Skipping reminder id=${reminder.id}");
          }
        } catch (e, st) {
          debugPrint("STATEMENT D-ITEM FAILED (handled): reminder id=${reminder.id}: $e");
          debugPrintStack(stackTrace: st);
        }
      }
      debugPrint("END: restoreScheduledNotifications() OK - Total restored: $restoreCount");
    } catch (e, st) {
      debugPrint("restoreScheduledNotifications caught outer error (continuing startup): $e");
    }
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
        print('[HISTORY] Processed $missedCount missed notifications into history.');
      }
    } catch (e) {
      print('Failed to process missed notifications: $e');
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
    try {
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
    } catch (e, st) {
      debugPrint('[QUIET_HOURS] ERROR: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
    return scheduledDate;
  }

  Future<void> _snoozeNotification(int? id, String? taskId, String? reminderId, int minutes) async {
    debugPrint('[SNOOZE_NOTIF] Start: id=$id, taskId=$taskId, reminderId=$reminderId, minutes=$minutes');
    if (id == null) return;
    
    // Cancel original escalations
    try {
      debugPrint('[SNOOZE_NOTIF] Calling cancelReminder($id)');
      await cancelReminder(id);
      debugPrint('[SNOOZE_NOTIF] cancelReminder finished');
    } catch (e, st) {
      debugPrint('[SNOOZE_NOTIF] ERROR cancelling reminder: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }

    final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));
    final scheduledDateUtc = scheduledDate.toUtc();

    // Update reminder state in database if reminderId is provided
    if (reminderId != null) {
      try {
        debugPrint('[SNOOZE_NOTIF] Updating DB snooze state for reminderId=$reminderId');
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
          debugPrint('[SNOOZE_NOTIF] DB update complete');
        }
      } catch (e, st) {
        debugPrint('[SNOOZE_NOTIF] ERROR updating reminder snooze state in DB: $e');
        debugPrintStack(stackTrace: st);
        rethrow;
      }
    }

    try {
      debugPrint('[SNOOZE_NOTIF] Calling zonedSchedule for snoozed notification id=$id');
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
      debugPrint('[SNOOZE_NOTIF] zonedSchedule finished for id=$id');
    } catch (e, st) {
      debugPrint('[SNOOZE_NOTIF] ERROR scheduling snoozed zonedSchedule: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }

    // Schedule snoozed escalation reminders
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool enableEscalation = prefs.getBool('smart_escalation_enabled') ?? true;
      if (enableEscalation) {
        final List<String> intervalStrings = prefs.getStringList('smart_escalation_intervals') ?? ['10', '30'];
        final List<int> intervals = intervalStrings.map((s) => int.tryParse(s) ?? 0).where((i) => i > 0).toList();

        for (int i = 0; i < intervals.length; i++) {
          final minutesEsc = intervals[i];
          final tzEsc = scheduledDate.add(Duration(minutes: minutesEsc));
          final escalationId = id + (i + 1) * 1000000;

          debugPrint('[SNOOZE_NOTIF] Scheduling snooze escalation $i (id=$escalationId) at $tzEsc');
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
          debugPrint('[SNOOZE_NOTIF] Snooze escalation $i finished');
        }
      }
    } catch (e, st) {
      debugPrint('[SNOOZE_NOTIF] ERROR scheduling snooze escalation: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  Future<void> scheduleReminder(int id, ReminderModel reminder) async {
    debugPrint("START: scheduleReminder(id=$id, title='${reminder.title}')");

    // S-STATEMENT 1: Date check
    if (reminder.scheduledTime.isBefore(DateTime.now())) {
      debugPrint("S-STATEMENT 1: Scheduled time is in the past, skipping.");
      return;
    }

    // S-STATEMENT 2: Timezone conversion
    tz.TZDateTime tzScheduledTime;
    try {
      debugPrint("S-STATEMENT 2: tz.TZDateTime.from(scheduledTime, tz.local)");
      tzScheduledTime = tz.TZDateTime.from(reminder.scheduledTime, tz.local);
      debugPrint("S-STATEMENT 2 OK: tzScheduledTime=$tzScheduledTime");
    } catch (e, st) {
      debugPrint("S-STATEMENT 2 FAILED");
      debugPrint(e.toString());
      debugPrintStack(stackTrace: st);
      rethrow;
    }

    // S-STATEMENT 3: Quiet hours application
    try {
      debugPrint("S-STATEMENT 3: _applyQuietHours(tzScheduledTime)");
      tzScheduledTime = await _applyQuietHours(tzScheduledTime);
      debugPrint("S-STATEMENT 3 OK: tzScheduledTime=$tzScheduledTime");
    } catch (e, st) {
      debugPrint("S-STATEMENT 3 FAILED");
      debugPrint(e.toString());
      debugPrintStack(stackTrace: st);
      rethrow;
    }

    String soundFile = 'reminder.wav';
    if (reminder.type == 'ACHIEVEMENT') soundFile = 'achievement.wav';
    else if (reminder.type == 'STREAK') soundFile = 'streak.wav';

    // S-STATEMENT 4: flutterLocalNotificationsPlugin.zonedSchedule(...)
    try {
      debugPrint("S-STATEMENT 4: flutterLocalNotificationsPlugin.zonedSchedule(id=$id)");
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
      debugPrint("S-STATEMENT 4 OK: zonedSchedule for id=$id completed");
    } catch (e, st) {
      debugPrint("S-STATEMENT 4 FAILED");
      debugPrint(e.toString());
      debugPrintStack(stackTrace: st);
      rethrow;
    }

    // S-STATEMENT 5: Smart Escalation
    try {
      debugPrint("S-STATEMENT 5: Escalation schedule setup");
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

          debugPrint("S-STATEMENT 5-ITEM: zonedSchedule escalation $i (id=$escalationId)");
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
                interruptionLevel: InterruptionLevel.timeSensitive,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            payload: "${reminder.taskId}|${reminder.id}",
          );
          debugPrint("S-STATEMENT 5-ITEM OK: escalation $i (id=$escalationId)");
        }
      }
      debugPrint("S-STATEMENT 5 OK");
    } catch (e, st) {
      debugPrint("S-STATEMENT 5 FAILED");
      debugPrint(e.toString());
      debugPrintStack(stackTrace: st);
      rethrow;
    }

    debugPrint("END: scheduleReminder(id=$id) OK");
  }

  // Deduplication set to track scheduled task occurrences per session
  final Set<String> _scheduledOccurrenceIds = {};

  void _logScheduledNotification({
    required String taskId,
    required int id,
    required String taskTitle,
    required String type,
    required DateTime fireTime,
    required String caller,
    required String reason,
  }) {
    final formattedFireTime = DateFormat('d MMM h:mm a').format(fireTime.toLocal());
    debugPrint("----------------------------------------");
    debugPrint("[NOTIFICATION_SCHEDULED]");
    debugPrint("Task ID: $taskId");
    debugPrint("Notification ID: $id");
    debugPrint("Task Name: $taskTitle");
    debugPrint("Notification Type: $type");
    debugPrint("Scheduled Time: $formattedFireTime");
    debugPrint("Reason: $reason");
    debugPrint("Caller: $caller");
    debugPrint("----------------------------------------");
  }

  Future<void> logPendingNotifications() async {
    if (kIsWeb) return;
    try {
      final List<PendingNotificationRequest> pending = await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      debugPrint("=== PENDING NOTIFICATIONS CHECK (${pending.length} active) ===");
      for (final req in pending) {
        debugPrint("ID: ${req.id} | Title: '${req.title}' | Payload: ${req.payload}");
      }
      debugPrint("=================================================");
    } catch (e) {
      debugPrint("Failed to dump pending notifications: $e");
    }
  }

  /// Smart Countdown Scheduling Algorithm (Duolingo / Apple Reminders style)
  /// Prevents duplicates, cancels old IDs, logs caller/reason context, and uses human premium copy.
  Future<void> scheduleTaskSmartCountdown({
    required String taskId,
    required String taskTitle,
    required DateTime taskScheduledTime,
    required String userId,
    String caller = 'UnknownCaller',
    String reason = 'Task created/synced',
  }) async {
    if (kIsWeb) return;

    final occurrenceKey = "${taskId}_${taskScheduledTime.toIso8601String()}";
    
    // 1. Cancel old notifications for this task to guarantee no duplicates
    await cancelTaskNotifications(taskId);

    final now = DateTime.now();
    final remainingMinutes = taskScheduledTime.difference(now).inMinutes;

    // Do not schedule reminders if the task start time is already in the past
    if (taskScheduledTime.isBefore(now.subtract(const Duration(minutes: 1)))) {
      debugPrint("[SMART_COUNTDOWN] Skipping task '$taskTitle' ($taskId) as taskScheduledTime is in the past.");
      return;
    }

    _scheduledOccurrenceIds.add(occurrenceKey);

    final baseId = taskId.hashCode & 0x1FFFFFFF;

    // 2. Instant Confirmation for tasks 0–20 mins away
    if (remainingMinutes <= 3 && remainingMinutes >= 0) {
      _scheduleInstantConfirmation(baseId, taskId, taskTitle, remainingMinutes, caller, reason);
    } else if (remainingMinutes > 3 && remainingMinutes <= 20) {
      _scheduleInstantConfirmation(baseId, taskId, taskTitle, remainingMinutes, caller, reason);
      LiveActivityService().startTaskActivity(taskTitle, taskScheduledTime);
    }

    // 3. Schedule remaining valid countdown alarms
    List<int> offsets = [];
    if (remainingMinutes > 15) {
      offsets = [15, 5, 1, 0];
    } else if (remainingMinutes > 5) {
      offsets = [5, 1, 0];
    } else if (remainingMinutes > 1) {
      offsets = [1, 0];
    } else if (remainingMinutes >= 0) {
      offsets = [0];
    }

    for (final offset in offsets) {
      try {
        final reminderTime = taskScheduledTime.subtract(Duration(minutes: offset));
        if (reminderTime.isBefore(now)) continue;

        final int notifId = (baseId + offset * 100) & 0x7FFFFFFF;
        final template = NotificationTemplates.getCountdownTemplate(offset, taskTitle);
        final tzTime = tz.TZDateTime.from(reminderTime, tz.local);

        await flutterLocalNotificationsPlugin.zonedSchedule(
          notifId,
          template.title,
          template.body,
          tzTime,
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
          payload: "$taskId|countdown_$offset",
        );

        _logScheduledNotification(
          taskId: taskId,
          id: notifId,
          taskTitle: taskTitle,
          type: offset == 0 ? "0-minute (Start)" : "$offset-minute warning",
          fireTime: reminderTime,
          caller: caller,
          reason: reason,
        );
      } catch (e) {
        debugPrint("[SMART_COUNTDOWN_ERROR] Failed offset $offset for task $taskId: $e");
      }
    }

    // 4. Missed-task follow-up notification (5 minutes post-start)
    try {
      final followUpTime = taskScheduledTime.add(const Duration(minutes: 5));
      if (followUpTime.isAfter(now)) {
        final int followUpId = (baseId + 9999) & 0x7FFFFFFF;
        final template = NotificationTemplates.getMissedFollowUpTemplate(taskTitle);
        final tzFollowUp = tz.TZDateTime.from(followUpTime, tz.local);

        await flutterLocalNotificationsPlugin.zonedSchedule(
          followUpId,
          template.title,
          template.body,
          tzFollowUp,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'escalation_reminders',
              'Follow-up Reminders',
              channelDescription: 'Follow-ups for uncompleted tasks',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(
              categoryIdentifier: 'task_reminder_category',
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: "$taskId|missed_followup",
        );

        _logScheduledNotification(
          taskId: taskId,
          id: followUpId,
          taskTitle: taskTitle,
          type: "Missed Task Follow-up (5-min after start)",
          fireTime: followUpTime,
          caller: caller,
          reason: reason,
        );
      }
    } catch (e) {
      debugPrint("[MISSED_FOLLOWUP_ERROR] Failed to schedule follow-up for task $taskId: $e");
    }

    await logPendingNotifications();
  }

  Future<void> _scheduleInstantConfirmation(
    int baseId,
    String taskId,
    String taskTitle,
    int remainingMinutes,
    String caller,
    String reason,
  ) async {
    try {
      final int instantId = (baseId + 10) & 0x7FFFFFFF;
      final fireTime = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
      final template = NotificationTemplates.getInstantTemplate(taskTitle, remainingMinutes);

      await flutterLocalNotificationsPlugin.zonedSchedule(
        instantId,
        template.title,
        template.body,
        fireTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders',
            'Task Confirmations',
            channelDescription: 'Instant confirmation for newly created short-term tasks',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: 'task_reminder_category',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: "$taskId|instant_confirmation",
      );

      _logScheduledNotification(
        taskId: taskId,
        id: instantId,
        taskTitle: taskTitle,
        type: "Instant Confirmation (~5s delay)",
        fireTime: DateTime.now().add(const Duration(seconds: 5)),
        caller: caller,
        reason: reason,
      );
    } catch (e) {
      debugPrint("[INSTANT_CONFIRMATION_ERROR] Failed instant confirmation for task $taskId: $e");
    }
  }

  /// Schedule 3 randomized daily motivation notifications (Morning, Afternoon, Evening)
  Future<void> scheduleDailyMotivationNotifications(String userId) async {
    if (kIsWeb) return;
    try {
      final random = Random();
      final now = DateTime.now();

      // Morning window: random minute between 8:00 AM and 10:30 AM (150 min span)
      final morningTime = DateTime(now.year, now.month, now.day, 8, 0).add(Duration(minutes: random.nextInt(150)));
      // Afternoon window: random minute between 1:00 PM and 3:30 PM (150 min span)
      final afternoonTime = DateTime(now.year, now.month, now.day, 13, 0).add(Duration(minutes: random.nextInt(150)));
      // Evening window: random minute between 6:30 PM and 9:00 PM (150 min span)
      final eveningTime = DateTime(now.year, now.month, now.day, 18, 30).add(Duration(minutes: random.nextInt(150)));

      final times = [morningTime, afternoonTime, eveningTime];

      for (int i = 0; i < times.length; i++) {
        final targetTime = times[i].isBefore(now) ? times[i].add(const Duration(days: 1)) : times[i];
        final template = NotificationTemplates.getRandomMotivation();
        final id = 990000 + i;

        final tzTime = tz.TZDateTime.from(targetTime, tz.local);
        
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          template.title,
          template.body,
          tzTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'motivation_channel',
              'Daily Motivation',
              channelDescription: 'Daily motivational quotes and reminders',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            iOS: DarwinNotificationDetails(
              interruptionLevel: InterruptionLevel.active,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
      debugPrint("[MOTIVATION] 3 randomized daily motivation notifications scheduled successfully.");
    } catch (e) {
      debugPrint("[MOTIVATION ERROR] Failed to schedule daily motivation: $e");
    }
  }

  // Legacy wrapper
  Future<void> scheduleTaskReminder(int id, String title, DateTime scheduledTime, String taskId) async {
    final reminder = ReminderModel(
      id: id.toString(),
      userId: DatabaseService().currentUserId ?? '',
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
          interruptionLevel: InterruptionLevel.timeSensitive,
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

  Future<void> cancelTaskNotifications(String taskId) async {
    final baseId = taskId.hashCode & 0x1FFFFFFF;
    await cancelReminder(baseId);
    
    // Cancel smart countdown offsets (15m, 5m, 1m, 0m), instant (10), missed task follow-up (9999)
    final offsets = [1500, 500, 100, 0, 10, 9999];
    for (final offset in offsets) {
      final notifId = (baseId + offset) & 0x7FFFFFFF;
      await flutterLocalNotificationsPlugin.cancel(notifId);
    }
    
    // End Live Activity if running
    LiveActivityService().endTaskActivity();
    debugPrint("[CANCEL_NOTIFS] Cancelled all scheduled notifications & follow-ups for task '$taskId'");
  }
}
