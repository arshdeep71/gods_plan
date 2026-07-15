import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/sync_item.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/notification_service.dart';

class TaskProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final SyncService _syncService = SyncService();
  final _uuid = const Uuid();

  List<Task> _tasks = [];
  List<Map<String, dynamic>> _completions = [];
  List<Map<String, dynamic>> _exceptions = [];
  bool _isLoading = false;
  bool _isSyncing = false;

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
