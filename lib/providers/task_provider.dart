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

  // Active (uncompleted) tasks
  List<Task> get activeTasks => _tasks.where((t) => !t.isCompleted).toList();

  // Completed tasks
  List<Task> get completedTasks => _tasks.where((t) => t.isCompleted).toList();

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
    required String difficulty,
    required String priority,
    required bool isRecurring,
  }) async {
    final now = DateTime.now().toUtc();
    final newTask = Task(
      id: _uuid.v4(),
      userId: userId,
      title: title,
      difficulty: difficulty,
      priority: priority,
      isCompleted: false,
      isRecurring: isRecurring,
      streakCount: 0,
      createdAt: now,
      updatedAt: now,
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

  // Toggle completion status of a task
  Future<void> toggleTaskCompletion(Task task) async {
    final updatedTask = task.copyWith(
      isCompleted: !task.isCompleted,
      updatedAt: DateTime.now().toUtc(),
    );

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
