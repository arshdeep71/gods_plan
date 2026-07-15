import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/sync_item.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

      final isScheduled = t.isRecurring || (t.scheduledDate == formattedDate);
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

      final isScheduled = t.isRecurring || (t.scheduledDate == formattedDate);
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
      return t.isRecurring || (t.scheduledDate == formattedDate);
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
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Fetch from local cache instantly
      _tasks = await _dbService.getLocalTasks(userId);
      _completions = await _dbService.getLocalTaskCompletions(userId);
      _exceptions = await _dbService.getLocalTaskExceptions(userId);
      _isLoading = false;
      notifyListeners();

      // 2. Perform background synchronization with Supabase
      _isSyncing = true;
      notifyListeners();

      await _syncService.sync(userId);
      
      // 3. Reload local cache in case background sync pulled updates
      _tasks = await _dbService.getLocalTasks(userId);
      _completions = await _dbService.getLocalTaskCompletions(userId);
      _exceptions = await _dbService.getLocalTaskExceptions(userId);
    } catch (e) {
      print("Error loading tasks: $e");
    } finally {
      _isLoading = false;
      _isSyncing = false;
      notifyListeners();
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
  }) async {
    final now = DateTime.now().toUtc();
    
    // Assign orderIndex at the end
    int nextOrderIndex = _tasks.isNotEmpty ? _tasks.map((t) => t.orderIndex).reduce((a, b) => a > b ? a : b) + 1 : 0;
    
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
    );

    // Optimistic UI updates - Save locally and update memory
    _tasks.insert(0, newTask);
    _scheduleNotification(newTask);
    notifyListeners();

    await _dbService.upsertLocalTask(newTask);

    // Queue mutation for sync
    final syncItem = SyncItem(
      actionType: 'INSERT',
      tableName: 'tasks',
      recordId: newTask.id,
      payload: newTask.toJson(),
    );
    await _dbService.queueMutation(syncItem);

    // Trigger background sync flush
    _syncService.sync(userId).then((_) async {
      _tasks = await _dbService.getLocalTasks(userId);
      notifyListeners();
    });
  }

  // Toggle completion status of a task for a specific date
  Future<void> toggleTaskCompletion(Task task, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final formattedDate = "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";
    
    // Check status before toggle
    final wasSuccessful = getDayStreakStatus(targetDate, userId: task.userId) == DayStreakStatus.perfect || 
                         getDayStreakStatus(targetDate, userId: task.userId) == DayStreakStatus.successful;

    final bool isCurrentlyCompleted = _completions.any((c) => c['task_id'] == task.id && c['completed_date'] == formattedDate);

    if (isCurrentlyCompleted) {
      // Remove completion
      _completions.removeWhere((c) => c['task_id'] == task.id && c['completed_date'] == formattedDate);
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
      // Add completion
      final completionId = _uuid.v4();
      final completion = {
        'id': completionId,
        'task_id': task.id,
        'user_id': task.userId,
        'completed_date': formattedDate,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
      
      _completions.add(completion);
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
  }

  // Edit task details
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
    final updatedTask = task.copyWith(
      title: title,
      isRecurring: isRecurring,
      repeatType: repeatType ?? task.repeatType,
      reminderTime: reminderTime ?? task.reminderTime,
      dueTime: dueTime,
      scheduledDate: scheduledDate,
      isPaused: isPaused ?? task.isPaused,
      updatedAt: DateTime.now().toUtc(),
    );

    _tasks[index] = updatedTask;
    _scheduleNotification(updatedTask);
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
      _scheduleNotification(updatedTask);
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

  // Delete a task
  Future<void> deleteTask(Task task) async {
    // Optimistic UI update - delete from memory
    _tasks.removeWhere((t) => t.id == task.id);
    NotificationService().cancelReminder(task.id.hashCode);
    notifyListeners();

    await _dbService.deleteLocalTask(task.id);

    // Queue mutation for sync
    final syncItem = SyncItem(
      actionType: 'DELETE',
      tableName: 'tasks',
      recordId: task.id,
    );
    await _dbService.queueMutation(syncItem);

    // Trigger background sync flush
    _syncService.sync(task.userId).then((_) async {
      _tasks = await _dbService.getLocalTasks(task.userId);
      notifyListeners();
    });
  }
  // Delete a specific occurrence
  Future<void> deleteTaskOccurrence(Task task, DateTime date) async {
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

  // Reorder tasks
  Future<void> reorderTasks(int oldIndex, int newIndex, DateTime selectedDate) async {
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

  void _scheduleNotification(Task task) {
    if (task.isPaused || task.isCompleted) {
      NotificationService().cancelReminder(task.id.hashCode);
      return;
    }

    if (task.dueTime != null) {
      final timeParts = task.dueTime!.split(' ');
      if (timeParts.isEmpty) return;
      
      final hm = timeParts[0].split(':');
      if (hm.length < 2) return;
      
      int hour = int.tryParse(hm[0]) ?? 12;
      int minute = int.tryParse(hm[1]) ?? 0;
      
      if (timeParts.length > 1) {
        if (timeParts[1].toLowerCase() == 'pm' && hour < 12) hour += 12;
        if (timeParts[1].toLowerCase() == 'am' && hour == 12) hour = 0;
      }

      final timeOfDay = TimeOfDay(hour: hour, minute: minute);
      
      if (task.isRecurring) {
        NotificationService().scheduleDailyReminder(
          task.id.hashCode,
          task.title,
          timeOfDay,
          task.id,
        );
      } else if (task.scheduledDate != null) {
        try {
          final date = DateTime.parse(task.scheduledDate!);
          final scheduledTime = DateTime(date.year, date.month, date.day, hour, minute);
          NotificationService().scheduleTaskReminder(
            task.id.hashCode,
            task.title,
            scheduledTime,
            task.id,
          );
        } catch (_) {}
      }
    } else {
      NotificationService().cancelReminder(task.id.hashCode);
    }
  }
}
