import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/sync_item.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reminder_model.dart';
import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import '../services/live_activity_service.dart';
import '../utils/notification_templates.dart';

enum DayStreakStatus {
  perfect,    // 100%
  successful, // 80-99%
  partial,    // <80% today
  missed,     // <80% in the past
  paused,     // only paused tasks
  restored,   // restored streak day
  empty       // 0 active tasks
}

class TaskProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final SyncService _syncService = SyncService();
  final _uuid = const Uuid();

  List<Task> _tasks = [];
  List<Map<String, dynamic>> _completions = [];
  List<Map<String, dynamic>> _exceptions = [];
  bool _isLoading = false;
  bool _isSyncing = false;

  // Congrats popup and XP animation triggers
  bool _shouldShowCongrats = false;
  bool get shouldShowCongrats => _shouldShowCongrats;

  bool _shouldShowXpAnimation = false;
  bool get shouldShowXpAnimation => _shouldShowXpAnimation;

  int _lastAwardedXpAmount = 0;
  int get lastAwardedXpAmount => _lastAwardedXpAmount;

  void clearCongrats() {
    _shouldShowCongrats = false;
    notifyListeners();
  }

  void clearXpAnimation() {
    _shouldShowXpAnimation = false;
    notifyListeners();
  }

  List<Task> get tasks => _tasks;
  List<Map<String, dynamic>> get completions => _completions;
  List<Map<String, dynamic>> get exceptions => _exceptions;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;

  // Active (uncompleted) tasks (Default to today's date)
  List<Task> get activeTasks => getActiveTasksForDate(DateTime.now());

  // Completed tasks (Default to today's date)
  List<Task> get completedTasks => getCompletedTasksForDate(DateTime.now());

  bool _isPastDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.isBefore(today);
  }

  bool _isDateOnOrAfter(DateTime date, String startDateStr) {
    final parts = startDateStr.split('-');
    if (parts.length < 3) return true;
    final sYear = int.tryParse(parts[0]) ?? 0;
    final sMonth = int.tryParse(parts[1]) ?? 0;
    final sDay = int.tryParse(parts[2]) ?? 0;

    if (date.year > sYear) return true;
    if (date.year < sYear) return false;
    if (date.month > sMonth) return true;
    if (date.month < sMonth) return false;
    return date.day >= sDay;
  }

  // Get active tasks for a specific date
  List<Task> getActiveTasksForDate(DateTime date) {
    final formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    
    // Sort tasks by order_index
    final sortedTasks = List<Task>.from(_tasks)..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    
    return sortedTasks.where((t) {
      if (t.isPaused) return false;
      
      // Check if deleted for this date (exception)
      final isException = _exceptions.any((e) => e['task_id'] == t.id && e['exception_date'] == formattedDate && e['is_deleted'] == 1);
      if (isException) return false;

      final isScheduled = (t.isRecurring && (t.startDate == null || _isDateOnOrAfter(date, t.startDate!))) || (t.scheduledDate == formattedDate);
      if (!isScheduled) return false;
      
      // Check if completed
      final isComp = _completions.any((c) => c['task_id'] == t.id && c['completed_date'] == formattedDate);
      return !isComp;
    }).toList();
  }

  // Get completed tasks for a specific date
  List<Task> getCompletedTasksForDate(DateTime date) {
    final formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    
    final sortedTasks = List<Task>.from(_tasks)..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    return sortedTasks.where((t) {
      if (t.isPaused) return false;
      
      final isException = _exceptions.any((e) => e['task_id'] == t.id && e['exception_date'] == formattedDate && e['is_deleted'] == 1);
      if (isException) return false;

      final isScheduled = (t.isRecurring && (t.startDate == null || _isDateOnOrAfter(date, t.startDate!))) || (t.scheduledDate == formattedDate);
      if (!isScheduled) return false;

      final isComp = _completions.any((c) => c['task_id'] == t.id && c['completed_date'] == formattedDate);
      return isComp;
    }).toList();
  }

  // Calculate day streak status
  DayStreakStatus getDayStreakStatus(DateTime date, {String? userId}) {
    final formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    
    // Check restored
    final currentUserId = userId ?? (_tasks.isNotEmpty ? _tasks.first.userId : null);
    if (currentUserId != null) {
      final restoredList = _dbService.settingsBox.get('restored_dates_$currentUserId', defaultValue: <dynamic>[]) as List;
      if (restoredList.contains(formattedDate)) {
        return DayStreakStatus.restored;
      }
    }
    
    final active = getActiveTasksForDate(date);
    final completed = getCompletedTasksForDate(date);
    
    // Calculate paused tasks count for the date
    final pausedCount = _tasks.where((t) {
      if (!t.isPaused) return false;
      final isException = _exceptions.any((e) => e['task_id'] == t.id && e['exception_date'] == formattedDate && e['is_deleted'] == 1);
      if (isException) return false;
      return (t.isRecurring && (t.startDate == null || _isDateOnOrAfter(date, t.startDate!))) || (t.scheduledDate == formattedDate);
    }).length;
    
    final totalActiveTasks = active.length + completed.length;
    if (totalActiveTasks == 0) {
      if (pausedCount > 0) {
        return DayStreakStatus.paused;
      }
      return DayStreakStatus.empty;
    }
    
    final successRatio = (completed.length / totalActiveTasks) * 100;
    
    if (successRatio >= 100.0) {
      return DayStreakStatus.perfect;
    } else if (successRatio >= 80.0) {
      return DayStreakStatus.successful;
    } else {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final checkDay = DateTime(date.year, date.month, date.day);
      if (checkDay.isBefore(today)) {
        return DayStreakStatus.missed;
      } else {
        return DayStreakStatus.partial;
      }
    }
  }

  // Calculate user current streak (skipping empty days, breaking on missed/partial past days)
  int calculateCurrentStreak(String userId) {
    final now = DateTime.now();
    DateTime checkDate = DateTime(now.year, now.month, now.day);
    int streak = 0;
    
    final todayStatus = getDayStreakStatus(checkDate, userId: userId);
    if (todayStatus == DayStreakStatus.perfect || todayStatus == DayStreakStatus.successful || todayStatus == DayStreakStatus.restored) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    } else if (todayStatus == DayStreakStatus.empty || todayStatus == DayStreakStatus.paused) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    } else {
      // today is partial, doesn't count towards streak yet but doesn't break it
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    while (true) {
      final status = getDayStreakStatus(checkDate, userId: userId);
      if (status == DayStreakStatus.perfect || status == DayStreakStatus.successful || status == DayStreakStatus.restored) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (status == DayStreakStatus.empty || status == DayStreakStatus.paused) {
        checkDate = checkDate.subtract(const Duration(days: 1));
        if (checkDate.isBefore(now.subtract(const Duration(days: 365)))) break;
      } else {
        break; // Streak broke
      }
    }
    
    return streak;
  }

  // Check and award daily XP (25 for success, 50 for perfect)
  Future<void> checkAndAwardDailyXp(DateTime date, String userId) async {
    final formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final status = getDayStreakStatus(date, userId: userId);
    
    final xpMap = Map<String, dynamic>.from(_dbService.settingsBox.get('xp_awarded_dates_$userId', defaultValue: <String, dynamic>{}));
    final currentAward = xpMap[formattedDate] as String?;
    
    int xpToAdd = 0;
    String? newAward;
    
    if (status == DayStreakStatus.perfect) {
      if (currentAward == null) {
        xpToAdd = 50;
        newAward = 'perfect';
      } else if (currentAward == 'successful') {
        xpToAdd = 25; // Upgrade bonus
        newAward = 'perfect';
      }
    } else if (status == DayStreakStatus.successful) {
      if (currentAward == null) {
        xpToAdd = 25;
        newAward = 'successful';
      }
    }
    
    if (xpToAdd > 0 && newAward != null) {
      xpMap[formattedDate] = newAward;
      await _dbService.settingsBox.put('xp_awarded_dates_$userId', xpMap);
      
      final currentXp = _dbService.settingsBox.get('xp_$userId', defaultValue: 0) as int;
      final newXp = currentXp + xpToAdd;
      await _dbService.settingsBox.put('xp_$userId', newXp);
      
      _syncProfileXp(userId, newXp);
      
      if (xpToAdd == 50) {
        AudioService().playAchievement();
        HapticService().achievement();
      } else {
        AudioService().playXp();
        HapticService().xpCoin();
      }

      _lastAwardedXpAmount = xpToAdd;
      _shouldShowXpAnimation = true;
      notifyListeners();
    }
  }

  Future<void> _syncProfileXp(String userId, int newXp) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'xp': newXp})
          .eq('id', userId);
    } catch (e) {
      final syncItem = SyncItem(
        actionType: 'UPDATE',
        tableName: 'profiles',
        recordId: userId,
        payload: {
          'id': userId,
          'xp': newXp,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      await _dbService.queueMutation(syncItem);
    }
  }

  // Streak Restores left (rolling 30-day window)
  int getStreakRestoresLeft(String userId) {
    _checkRestoreReset(userId);
    return _dbService.settingsBox.get('restores_left_$userId', defaultValue: 3) as int;
  }

  void _checkRestoreReset(String userId) {
    final resetDateStr = _dbService.settingsBox.get('restore_reset_date_$userId') as String?;
    final now = DateTime.now();
    if (resetDateStr == null) {
      _dbService.settingsBox.put('restore_reset_date_$userId', now.toIso8601String());
      _dbService.settingsBox.put('restores_left_$userId', 3);
    } else {
      final resetDate = DateTime.parse(resetDateStr);
      if (now.difference(resetDate).inDays >= 30) {
        _dbService.settingsBox.put('restore_reset_date_$userId', now.toIso8601String());
        _dbService.settingsBox.put('restores_left_$userId', 3);
      }
    }
  }

  Future<bool> restoreStreak(String userId) async {
    _checkRestoreReset(userId);
    final restoresLeft = _dbService.settingsBox.get('restores_left_$userId', defaultValue: 3) as int;
    if (restoresLeft <= 0) return false;
    
    final now = DateTime.now();
    DateTime checkDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    DateTime? brokenDate;
    
    for (int i = 0; i < 30; i++) {
      final status = getDayStreakStatus(checkDate, userId: userId);
      if (status == DayStreakStatus.missed || status == DayStreakStatus.partial) {
        brokenDate = checkDate;
        break;
      }
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    
    if (brokenDate == null) return false;
    
    final formattedDate = "${brokenDate.year}-${brokenDate.month.toString().padLeft(2, '0')}-${brokenDate.day.toString().padLeft(2, '0')}";
    
    final restoredList = List<String>.from(_dbService.settingsBox.get('restored_dates_$userId', defaultValue: <dynamic>[]) as List);
    restoredList.add(formattedDate);
    await _dbService.settingsBox.put('restored_dates_$userId', restoredList);
    await _dbService.settingsBox.put('restores_left_$userId', restoresLeft - 1);
    
    _syncProfileRestores(userId, restoresLeft - 1, restoredList);
    
    notifyListeners();
    return true;
  }

  Future<void> _syncProfileRestores(String userId, int restoresLeft, List<String> restoredList) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({
            'streak_restores': restoresLeft,
            'restored_dates': restoredList,
            'last_restore_reset': _dbService.settingsBox.get('restore_reset_date_$userId'),
          })
          .eq('id', userId);
    } catch (e) {
      final syncItem = SyncItem(
        actionType: 'UPDATE',
        tableName: 'profiles',
        recordId: userId,
        payload: {
          'id': userId,
          'streak_restores': restoresLeft,
          'restored_dates': restoredList,
          'last_restore_reset': _dbService.settingsBox.get('restore_reset_date_$userId'),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      await _dbService.queueMutation(syncItem);
    }
  }

  // Load tasks from local SQLite database and trigger background cloud sync
  Future<void> fetchTasks(String userId) async {
    print("[LOAD] Method: fetchTasks, Reason: Initial load / manual refresh, Source: SQLite & Supabase");
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Fetch from local cache instantly
      final prevCount = _tasks.length;
      _tasks = await _dbService.getLocalTasks(userId);
      _completions = await _dbService.getLocalTaskCompletions(userId);
      _exceptions = await _dbService.getLocalTaskExceptions(userId);
      print("[STATE CHANGE] Function: fetchTasks (Local SQLite loaded), Previous count: $prevCount, New count: ${_tasks.length}");
      _isLoading = false;
      notifyListeners();

      // 2. Perform background synchronization with Supabase
      print("[LOAD] Triggering background sync from fetchTasks");
      _isSyncing = true;
      notifyListeners();

      await _syncService.sync(userId);
      
      // 3. Reload local cache in case background sync pulled updates
      final beforeReload = _tasks.length;
      _tasks = await _dbService.getLocalTasks(userId);
      _completions = await _dbService.getLocalTaskCompletions(userId);
      _exceptions = await _dbService.getLocalTaskExceptions(userId);
      print("[STATE CHANGE] Function: fetchTasks (After background sync), Previous count: $beforeReload, New count: ${_tasks.length}");
    } catch (e) {
      print("Error loading tasks: $e");
    } finally {
      _isLoading = false;
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> triggerSync(String userId) async {
    print("[PROVIDER] triggerSync started for user: $userId");
    _isSyncing = true;
    notifyListeners();
    try {
      await _syncService.sync(userId);
      final beforeReload = _tasks.length;
      _tasks = await _dbService.getLocalTasks(userId);
      _completions = await _dbService.getLocalTaskCompletions(userId);
      _exceptions = await _dbService.getLocalTaskExceptions(userId);
      print("[STATE CHANGE] Function: triggerSync, Previous count: $beforeReload, New count: ${_tasks.length}");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  int _getDaysInMonth(int year, int month) {
    if (month == 2) {
      return (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) ? 29 : 28;
    }
    const days = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month];
  }

  String _getTaskEmoji(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('gym') || lower.contains('workout') || lower.contains('exercise') || lower.contains('run') || lower.contains('fitness')) return '🏋️';
    if (lower.contains('study') || lower.contains('read') || lower.contains('learn') || lower.contains('book') || lower.contains('dsa') || lower.contains('exam')) return '📚';
    if (lower.contains('eat') || lower.contains('lunch') || lower.contains('dinner') || lower.contains('breakfast') || lower.contains('food') || lower.contains('meal')) return '🍽️';
    if (lower.contains('water') || lower.contains('drink') || lower.contains('hydrate')) return '💧';
    if (lower.contains('sleep') || lower.contains('bed') || lower.contains('rest')) return '😴';
    if (lower.contains('code') || lower.contains('dev') || lower.contains('project') || lower.contains('work')) return '💻';
    if (lower.contains('meditat') || lower.contains('yoga') || lower.contains('mindful')) return '🧘';
    return '⏰';
  }

  Future<void> _syncRemindersForTask(Task task) async {
    // First, delete existing reminders for this task to recreate them cleanly
    final existingReminders = await _dbService.getLocalReminders(task.userId);
    for (final r in existingReminders) {
      if (r.taskId == task.id) {
        await _dbService.deleteLocalReminder(r.id);
        await NotificationService().cancelReminder(r.id.hashCode & 0x7FFFFFFF);
        // Queue delete for Supabase
        await _dbService.queueMutation(SyncItem(
          actionType: 'DELETE',
          tableName: 'reminders',
          recordId: r.id,
        ));
      }
    }

    if (task.reminderTime == null && task.dueTime == null) return;
    if (task.isCompleted || task.isPaused) return; // Do not schedule reminders for completed/paused tasks
    
    // Parse time
    String timeString = task.reminderTime ?? task.dueTime!;
    final timeParts = timeString.split(' ');
    if (timeParts.isEmpty) return;
    
    final hm = timeParts[0].split(':');
    if (hm.length < 2) return;
    
    int hour = int.tryParse(hm[0]) ?? 12;
    int minute = int.tryParse(hm[1]) ?? 0;
    
    if (timeParts.length > 1) {
      if (timeParts[1].toLowerCase() == 'pm' && hour < 12) hour += 12;
      if (timeParts[1].toLowerCase() == 'am' && hour == 12) hour = 0;
    }

    // Determine target occurrence dates
    List<DateTime> occurrenceDates = [];
    if (!task.isRecurring) {
      DateTime? baseDate = task.scheduledDate != null 
          ? DateTime.tryParse(task.scheduledDate!) 
          : DateTime.now();
      if (baseDate != null) {
        occurrenceDates.add(baseDate);
      }
    } else {
      DateTime startDate = task.startDate != null 
          ? DateTime.tryParse(task.startDate!) ?? DateTime.now()
          : DateTime.now();
      DateTime now = DateTime.now();
      DateTime checkDate = DateTime(startDate.year, startDate.month, startDate.day);
      DateTime today = DateTime(now.year, now.month, now.day);
      if (checkDate.isBefore(today)) {
        checkDate = today;
      }
      
      int count = 0;
      int maxOccurrences = task.repeatType == 'daily' ? 7 : (task.repeatType == 'weekly' ? 4 : 3);
      
      while (count < maxOccurrences) {
        occurrenceDates.add(checkDate);
        count++;
        
        if (task.repeatType == 'daily') {
          checkDate = checkDate.add(const Duration(days: 1));
        } else if (task.repeatType == 'weekly') {
          checkDate = checkDate.add(const Duration(days: 7));
        } else if (task.repeatType == 'monthly') {
          int nextMonth = checkDate.month + 1;
          int nextYear = checkDate.year;
          if (nextMonth > 12) {
            nextMonth = 1;
            nextYear += 1;
          }
          int day = checkDate.day;
          int maxDays = _getDaysInMonth(nextYear, nextMonth);
          if (day > maxDays) day = maxDays;
          checkDate = DateTime(nextYear, nextMonth, day);
        } else {
          checkDate = checkDate.add(const Duration(days: 1));
        }
      }
    }

    final now = DateTime.now();
    final emoji = _getTaskEmoji(task.title);

    // Schedule 1 reminder per task occurrence and trigger smart countdown system push alarms
    for (final date in occurrenceDates) {
      final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      
      // Check if completed or exception deleted
      bool isCompletedOccurrence = _completions.any((c) => c['task_id'] == task.id && c['completed_date'] == dateStr);
      bool isDeletedOccurrence = _exceptions.any((e) => e['task_id'] == task.id && e['exception_date'] == dateStr && e['is_deleted'] == 1);
      
      if (isCompletedOccurrence || isDeletedOccurrence) {
        continue;
      }

      final taskStart = DateTime(date.year, date.month, date.day, hour, minute);

      if (taskStart.isAfter(now)) {
        try {
          final reminderId = "${task.id}_$dateStr";
          final template = NotificationTemplates.getCountdownTemplate(0, task.title);

          final reminder = ReminderModel(
            id: reminderId,
            userId: task.userId,
            taskId: task.id,
            scheduledTime: taskStart,
            type: 'REMINDER',
            title: "$emoji ${task.title}",
            body: template.body,
            repeatPattern: task.isRecurring ? task.repeatType.toUpperCase() : 'ONCE',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await _dbService.upsertLocalReminder(reminder);
          
          await _dbService.queueMutation(SyncItem(
            actionType: 'INSERT',
            tableName: 'reminders',
            recordId: reminder.id,
            payload: reminder.toJson(),
          ));

          // Schedule intelligent countdown push alarms (15m, 5m, 1m, 0m dynamically based on remaining time)
          await NotificationService().scheduleTaskSmartCountdown(
            taskId: task.id,
            taskTitle: task.title,
            taskScheduledTime: taskStart,
            userId: task.userId,
            caller: 'TaskProvider._syncRemindersForTask',
            reason: 'Task created or updated occurrence scheduling',
          );
        } catch (e, st) {
          debugPrint("[REMINDER ERROR] Non-fatal error scheduling reminder for task ${task.id}: $e");
          debugPrintStack(stackTrace: st);
        }
      }
    }
  }

  Future<void> addTask({
    required String userId,
    required String title,
    required bool isRecurring,
    String repeatType = 'daily',
    String? reminderTime,
    String? dueTime,
    String? scheduledDate,
    String? startDate,
    bool triggerSync = true,
  }) async {
    print("[PROVIDER] addTask started for task title: '$title'. Previous total count: ${_tasks.length}");
    if (scheduledDate != null) {
      final parsedDate = DateTime.tryParse(scheduledDate);
      if (parsedDate != null && _isPastDate(parsedDate)) {
        print("Cannot add tasks to archived dates.");
        return;
      }
    }

    final now = DateTime.now().toUtc();
    
    // Assign orderIndex at the end
    int nextOrderIndex = _tasks.isNotEmpty ? _tasks.map((t) => t.orderIndex).reduce((a, b) => a > b ? a : b) + 1 : 0;
    
    String? taskStartDate = startDate;
    if (isRecurring && taskStartDate == null) {
      final nowLocal = DateTime.now().toLocal();
      taskStartDate = "${nowLocal.year}-${nowLocal.month.toString().padLeft(2, '0')}-${nowLocal.day.toString().padLeft(2, '0')}";
    }
    
    final newTask = Task(
      id: _uuid.v4(),
      userId: userId,
      title: title,
      isCompleted: false,
      isRecurring: isRecurring,
      repeatType: repeatType,
      reminderTime: reminderTime,
      orderIndex: nextOrderIndex,
      streakCount: 0,
      createdAt: now,
      updatedAt: now,
      isPaused: false,
      dueTime: dueTime,
      scheduledDate: scheduledDate,
      startDate: taskStartDate,
    );

    // Optimistic UI updates - Save locally and update memory
    _tasks.insert(0, newTask);
    await _syncRemindersForTask(newTask);
    print("[STATE CHANGE] Function: addTask (Optimistic update), Previous count: ${_tasks.length - 1}, New count: ${_tasks.length}");
    notifyListeners();

    await _dbService.upsertLocalTask(newTask);
    print("[DATABASE] SQLite insert successful. Saved task ID: ${newTask.id}");

    // Queue mutation for sync
    final syncItem = SyncItem(
      actionType: 'INSERT',
      tableName: 'tasks',
      recordId: newTask.id,
      payload: newTask.toJson(),
    );
    await _dbService.queueMutation(syncItem);
    print("[SYNC QUEUE] Mutation queued for task: ${newTask.title}");

    // Trigger background sync flush
    if (triggerSync) {
      print("[PROVIDER] addTask - Triggering background sync flush");
      _syncService.sync(userId).then((_) async {
        final beforeReload = _tasks.length;
        _tasks = await _dbService.getLocalTasks(userId);
        print("[STATE CHANGE] Function: addTask (Sync complete reload), Previous count: $beforeReload, New count: ${_tasks.length}");
        notifyListeners();
      });
    } else {
      print("[PROVIDER] addTask - Skipping background sync flush (triggerSync is false)");
    }
  }

  // =====================================
  // Focus Session / Live Activity
  // =====================================

  Future<void> startFocusSession(Task task, {int durationMinutes = 25}) async {
    final deadline = DateTime.now().add(Duration(minutes: durationMinutes));
    await LiveActivityService().startTaskActivity(task.title, deadline);
    HapticService().selectionClick();
  }

  Future<void> updateFocusProgress(double progress) async {
    await LiveActivityService().updateTaskActivity(progress);
  }

  Future<void> cancelFocusSession() async {
    await LiveActivityService().endTaskActivity();
    HapticService().selectionClick();
  }

  Future<void> toggleTaskCompletion(Task task, {DateTime? date}) async {
    try {
    final targetDate = date ?? DateTime.now();
    if (_isPastDate(targetDate)) {
      print("Cannot toggle task completions on archived dates.");
      return;
    }
    final formattedDate = "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";
    
    // Check status before toggle
    final wasSuccessful = getDayStreakStatus(targetDate, userId: task.userId) == DayStreakStatus.perfect || 
                         getDayStreakStatus(targetDate, userId: task.userId) == DayStreakStatus.successful;

    final bool isCurrentlyCompleted = _completions.any((c) => c['task_id'] == task.id && c['completed_date'] == formattedDate);

    if (isCurrentlyCompleted) {
      // User unchecked the task
      HapticService().selectionClick();
      
      final temp = List<Map<String, dynamic>>.from(_completions);
      temp.removeWhere((c) => c['task_id'] == task.id && c['completed_date'] == formattedDate);
      _completions = temp;
      notifyListeners();
      
      await _dbService.deleteLocalTaskCompletion(task.id, formattedDate);
      
      // Queue delete mutation
      final syncItem = SyncItem(
        actionType: 'DELETE',
        tableName: 'task_completions',
        recordId: '${task.id}_$formattedDate', // Using composite key conceptually
      );
      await _dbService.queueMutation(syncItem);
    } else {
      // User completed the task
      AudioService().playSuccess();
      HapticService().success();

      // End Live Activity and cancel all pending reminders & follow-ups for this task
      await NotificationService().cancelTaskNotifications(task.id);

      final completionId = _uuid.v4();
      final completion = {
        'id': completionId,
        'task_id': task.id,
        'user_id': task.userId,
        'completed_date': formattedDate,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
      
      final temp = List<Map<String, dynamic>>.from(_completions);
      temp.add(completion);
      _completions = temp;
      notifyListeners();
      
      await _dbService.upsertLocalTaskCompletion(completion);
      
      // Queue insert mutation
      final syncItem = SyncItem(
        actionType: 'INSERT',
        tableName: 'task_completions',
        recordId: completionId,
        payload: completion,
      );
      await _dbService.queueMutation(syncItem);
    }

    // Check status after toggle and award XP / Congrats if it just became successful
    final isSuccessfulNow = getDayStreakStatus(targetDate, userId: task.userId) == DayStreakStatus.perfect || 
                            getDayStreakStatus(targetDate, userId: task.userId) == DayStreakStatus.successful;

    if (!wasSuccessful && isSuccessfulNow) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final checkDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
      if (checkDay.isAtSameMomentAs(today)) {
        final lastShown = _dbService.settingsBox.get('popup_shown_date_${task.userId}');
        final todayStr = "${today.year}-${today.month}-${today.day}";
        if (lastShown != todayStr) {
          _shouldShowCongrats = true;
          await _dbService.settingsBox.put('popup_shown_date_${task.userId}', todayStr);
        }
      }
    }

    await checkAndAwardDailyXp(targetDate, task.userId);

    // Trigger background sync flush
    _syncService.sync(task.userId).then((_) async {
      _completions = await _dbService.getLocalTaskCompletions(task.userId);
      notifyListeners();
    });
  }catch (e, stack) {
  print("=================================");
  print("TOGGLE TASK ERROR");
  print("Type: ${e.runtimeType}");
  print("Error: $e");
  print(stack);
  rethrow;
}}

  Future<void> updateTask({
    required String taskId,
    required String title,
    required bool isRecurring,
    String? repeatType,
    String? reminderTime,
    String? dueTime,
    String? scheduledDate,
    bool? isPaused,
  }) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    
    final task = _tasks[index];

    // Guard edit: if the task is scheduled on a past date, block updating it
    if (task.scheduledDate != null) {
      final parsedDate = DateTime.tryParse(task.scheduledDate!);
      if (parsedDate != null && _isPastDate(parsedDate)) {
        print("Cannot edit tasks scheduled on archived dates.");
        return;
      }
    }

    String? newStartDate = task.startDate;
    if (isRecurring && newStartDate == null) {
      final nowLocal = DateTime.now().toLocal();
      newStartDate = "${nowLocal.year}-${nowLocal.month.toString().padLeft(2, '0')}-${nowLocal.day.toString().padLeft(2, '0')}";
    }

    final updatedTask = task.copyWith(
      title: title,
      isRecurring: isRecurring,
      repeatType: repeatType ?? task.repeatType,
      reminderTime: reminderTime ?? task.reminderTime,
      dueTime: dueTime,
      scheduledDate: scheduledDate,
      isPaused: isPaused ?? task.isPaused,
      startDate: newStartDate,
      updatedAt: DateTime.now().toUtc(),
    );

    _tasks[index] = updatedTask;
    await _syncRemindersForTask(updatedTask);
    notifyListeners();

    await _dbService.upsertLocalTask(updatedTask);

    final syncItem = SyncItem(
      actionType: 'UPDATE',
      tableName: 'tasks',
      recordId: updatedTask.id,
      payload: updatedTask.toJson(),
    );
    await _dbService.queueMutation(syncItem);

    _syncService.sync(task.userId).then((_) async {
      _tasks = await _dbService.getLocalTasks(task.userId);
      notifyListeners();
    });
  }

  // Toggle paused state of a task
  Future<void> toggleTaskPause(Task task) async {
    final updatedTask = task.copyWith(
      isPaused: !task.isPaused,
      updatedAt: DateTime.now().toUtc(),
    );

    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = updatedTask;
      await _syncRemindersForTask(updatedTask);
      notifyListeners();
    }

    await _dbService.upsertLocalTask(updatedTask);

    final syncItem = SyncItem(
      actionType: 'UPDATE',
      tableName: 'tasks',
      recordId: updatedTask.id,
      payload: updatedTask.toJson(),
    );
    await _dbService.queueMutation(syncItem);

    _syncService.sync(task.userId).then((_) async {
      _tasks = await _dbService.getLocalTasks(task.userId);
      notifyListeners();
    });
  }

  Future<void> deleteTask(Task task) async {
    if (task.scheduledDate != null) {
      final parsedDate = DateTime.tryParse(task.scheduledDate!);
      if (parsedDate != null && _isPastDate(parsedDate)) {
        print("Cannot delete tasks scheduled on archived dates.");
        return;
      }
    }

    // Optimistic UI update - delete from memory
    _tasks.removeWhere((t) => t.id == task.id);
    await NotificationService().cancelTaskNotifications(task.id);
    await _syncRemindersForTask(task.copyWith(reminderTime: null, dueTime: null));
    notifyListeners();

    try {
      await _dbService.deleteLocalTask(task.id);

      // Queue mutation for sync
      final syncItem = SyncItem(
        actionType: 'DELETE',
        tableName: 'tasks',
        recordId: task.id,
      );
      await _dbService.queueMutation(syncItem);

      // Await sync fully before reloading to avoid concurrent SQLite access on web
      try {
        await _syncService.sync(task.userId);
      } catch (_) {}
      _tasks = await _dbService.getLocalTasks(task.userId);
      _completions = await _dbService.getLocalTaskCompletions(task.userId);
      _exceptions = await _dbService.getLocalTaskExceptions(task.userId);
      notifyListeners();
    } catch (e, stack) {
      print("Error deleting task: $e");
      print(stack);
    }
  }
  // Delete a specific occurrence
  Future<void> deleteTaskOccurrence(Task task, DateTime date) async {
    if (_isPastDate(date)) {
      print("Cannot delete task occurrences on archived dates.");
      return;
    }
    final formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    
    final exceptionId = _uuid.v4();
    final exception = {
      'id': exceptionId,
      'task_id': task.id,
      'user_id': task.userId,
      'exception_date': formattedDate,
      'is_deleted': 1,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    
    _exceptions.add(exception);
    notifyListeners();
    
    await _dbService.upsertLocalTaskException(exception);
    
    final syncItem = SyncItem(
      actionType: 'INSERT',
      tableName: 'task_exceptions',
      recordId: exceptionId,
      payload: exception,
    );
    await _dbService.queueMutation(syncItem);
    _syncService.sync(task.userId);
  }

  Future<void> reorderTasks(int oldIndex, int newIndex, DateTime selectedDate) async {
    if (_isPastDate(selectedDate)) {
      print("Cannot reorder tasks on archived dates.");
      return;
    }
    final active = getActiveTasksForDate(selectedDate);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    final task = active.removeAt(oldIndex);
    active.insert(newIndex, task);
    
    // Update order indices for all tasks in active list
    for (int i = 0; i < active.length; i++) {
      final t = active[i];
      final updatedTask = t.copyWith(orderIndex: i, updatedAt: DateTime.now().toUtc());
      
      final index = _tasks.indexWhere((item) => item.id == t.id);
      if (index != -1) {
        _tasks[index] = updatedTask;
      }
      
      await _dbService.upsertLocalTask(updatedTask);
      
      final syncItem = SyncItem(
        actionType: 'UPDATE',
        tableName: 'tasks',
        recordId: updatedTask.id,
        payload: updatedTask.toJson(),
      );
      await _dbService.queueMutation(syncItem);
    }
    
    notifyListeners();
    if (_tasks.isNotEmpty) {
      _syncService.sync(_tasks.first.userId);
    }
  }



  void clear() {
    _tasks = [];
    _completions = [];
    _exceptions = [];
    _shouldShowCongrats = false;
    _shouldShowXpAnimation = false;
    _lastAwardedXpAmount = 0;
    notifyListeners();
  }
}