import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/sync_item.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class TaskProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final SyncService _syncService = SyncService();
  final _uuid = const Uuid();

  List<Task> _tasks = [];
  bool _isLoading = false;
  bool _isSyncing = false;

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;

  // Active (uncompleted) tasks (Default to today's date)
  List<Task> get activeTasks => getActiveTasksForDate(DateTime.now());

  // Completed tasks (Default to today's date)
  List<Task> get completedTasks => getCompletedTasksForDate(DateTime.now());

  // Get active tasks for a specific date
  List<Task> getActiveTasksForDate(DateTime date) {
    final formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return _tasks.where((t) {
      if (t.isPaused) return false;
      final isScheduled = t.isRecurring || (t.scheduledDate == formattedDate);
      if (!isScheduled) return false;
      
      final isComp = t.isRecurring
          ? t.lastCompletedDate == formattedDate
          : t.isCompleted;
      return !isComp;
    }).toList();
  }

  // Get completed tasks for a specific date
  List<Task> getCompletedTasksForDate(DateTime date) {
    final formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return _tasks.where((t) {
      if (t.isPaused) return false;
      final isScheduled = t.isRecurring || (t.scheduledDate == formattedDate);
      if (!isScheduled) return false;

      final isComp = t.isRecurring
          ? t.lastCompletedDate == formattedDate
          : t.isCompleted;
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
      _isLoading = false;
      notifyListeners();

      // 2. Perform background synchronization with Supabase
      _isSyncing = true;
      notifyListeners();

      await _syncService.sync(userId);
      
      // 3. Reload local cache in case background sync pulled updates
      _tasks = await _dbService.getLocalTasks(userId);
    } catch (e) {
      print("Error loading tasks: $e");
    } finally {
      _isLoading = false;
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Create a new task
  Future<void> addTask({
    required String userId,
    required String title,
    required bool isRecurring,
    String? dueTime,
    String? scheduledDate,
  }) async {
    final now = DateTime.now().toUtc();
    final newTask = Task(
      id: _uuid.v4(),
      userId: userId,
      title: title,
      difficulty: 'medium',
      priority: 'medium',
      isCompleted: false,
      isRecurring: isRecurring,
      streakCount: 0,
      createdAt: now,
      updatedAt: now,
      isPaused: false,
      dueTime: dueTime,
      scheduledDate: scheduledDate,
    );

    // Optimistic UI updates - Save locally and update memory
    _tasks.insert(0, newTask);
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
    
    final bool isCurrentlyCompleted = task.isRecurring
        ? task.lastCompletedDate == formattedDate
        : task.isCompleted;

    Task updatedTask;
    if (task.isRecurring) {
      if (isCurrentlyCompleted) {
        updatedTask = task.copyWith(
          lastCompletedDate: null,
          streakCount: task.streakCount > 0 ? task.streakCount - 1 : 0,
          updatedAt: DateTime.now().toUtc(),
        );
      } else {
        updatedTask = task.copyWith(
          lastCompletedDate: formattedDate,
          streakCount: task.streakCount + 1,
          updatedAt: DateTime.now().toUtc(),
        );
      }
    } else {
      if (isCurrentlyCompleted) {
        updatedTask = task.copyWith(
          isCompleted: false,
          lastCompletedDate: null,
          updatedAt: DateTime.now().toUtc(),
        );
      } else {
        updatedTask = task.copyWith(
          isCompleted: true,
          lastCompletedDate: formattedDate,
          updatedAt: DateTime.now().toUtc(),
        );
      }
    }

    // Find and replace in memory list
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = updatedTask;
      notifyListeners();
    }

    await _dbService.upsertLocalTask(updatedTask);

    // Queue mutation for sync
    final syncItem = SyncItem(
      actionType: 'UPDATE',
      tableName: 'tasks',
      recordId: updatedTask.id,
      payload: updatedTask.toJson(),
    );
    await _dbService.queueMutation(syncItem);

    // Trigger background sync flush
    _syncService.sync(task.userId).then((_) async {
      _tasks = await _dbService.getLocalTasks(task.userId);
      notifyListeners();
    });
  }

  // Edit task details
  Future<void> updateTask({
    required String taskId,
    required String title,
    required bool isRecurring,
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
      dueTime: dueTime,
      scheduledDate: scheduledDate,
      isPaused: isPaused ?? task.isPaused,
      updatedAt: DateTime.now().toUtc(),
    );

    _tasks[index] = updatedTask;
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
}
