import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/workout.dart';
import '../models/sleep_log.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../models/sync_item.dart';

class HealthProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final SyncService _syncService = SyncService();
  final _uuid = const Uuid();

  List<Workout> _workouts = [];
  List<SleepLog> _sleepLogs = [];
  bool _isLoading = false;
  bool _isSyncing = false;

  List<Workout> get workouts => _workouts;
  List<SleepLog> get sleepLogs => _sleepLogs;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;

  // Active workout minutes logged today (to match 30-min goal)
  int get exerciseMinutesLoggedToday {
    final today = DateTime.now();
    return _workouts
        .where((w) => w.loggedAt.year == today.year && 
                      w.loggedAt.month == today.month && 
                      w.loggedAt.day == today.day)
        .fold(0, (sum, w) => sum + w.duration);
  }

  // Get sleep logged last night (latest log)
  SleepLog? get lastNightSleepLog {
    if (_sleepLogs.isEmpty) return null;
    return _sleepLogs.first;
  }

  // Load workouts and sleep logs from SQLite, then background sync
  Future<void> fetchHealthData(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Load local SQLite database records instantly
      _workouts = await _dbService.getLocalWorkouts(userId);
      _sleepLogs = await _dbService.getLocalSleepLogs(userId);
      _isLoading = false;
      notifyListeners();

      // 2. Perform background sync
      _isSyncing = true;
      notifyListeners();

      await _syncService.sync(userId);

      // 3. Reload cache
      _workouts = await _dbService.getLocalWorkouts(userId);
      _sleepLogs = await _dbService.getLocalSleepLogs(userId);
    } catch (e) {
      print("Error loading health metrics: $e");
    } finally {
      _isLoading = false;
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Add workout logs
  Future<void> addWorkout({
    required String userId,
    required String activityType,
    required int duration,
    required double weightKg,
  }) async {
    final now = DateTime.now();
    final calories = Workout.calculateCalories(duration, activityType, weightKg);
    final workout = Workout(
      id: _uuid.v4(),
      userId: userId,
      activityType: activityType,
      duration: duration,
      weightKg: weightKg,
      caloriesBurned: calories,
      loggedAt: now,
      updatedAt: now,
    );

    // Optimistic UI updates
    _workouts.insert(0, workout);
    notifyListeners();

    await _dbService.upsertLocalWorkout(workout);

    // Queue sync mutation
    final syncItem = SyncItem(
      actionType: 'INSERT',
      tableName: 'workouts',
      recordId: workout.id,
      payload: workout.toJson(),
    );
    await _dbService.queueMutation(syncItem);

    // Trigger sync
    _syncService.sync(userId).then((_) async {
      _workouts = await _dbService.getLocalWorkouts(userId);
      notifyListeners();
    });
  }

  // Delete workout logs
  Future<void> deleteWorkout(Workout workout) async {
    _workouts.removeWhere((w) => w.id == workout.id);
    notifyListeners();

    await _dbService.deleteLocalWorkout(workout.id);

    final syncItem = SyncItem(
      actionType: 'DELETE',
      tableName: 'workouts',
      recordId: workout.id,
    );
    await _dbService.queueMutation(syncItem);

    _syncService.sync(workout.userId).then((_) async {
      _workouts = await _dbService.getLocalWorkouts(workout.userId);
      notifyListeners();
    });
  }

  // Add sleep log
  Future<void> addSleepLog({
    required String userId,
    required DateTime sleepTime,
    required DateTime wakeTime,
    required double reportedQuality,
    required bool caffeineAfter3PM,
    required bool screenTimeInBed,
    required bool lateDinner,
  }) async {
    final now = DateTime.now();
    
    // Check if an exercise session was logged on the same day as sleepTime/wakeTime
    final bool exercisedToday = _workouts.any((w) => 
        w.loggedAt.year == sleepTime.year && 
        w.loggedAt.month == sleepTime.month && 
        w.loggedAt.day == sleepTime.day);

    final calculatedQuality = SleepLog.calculateSleepQuality(
      reportedQuality: reportedQuality,
      caffeineAfter3PM: caffeineAfter3PM,
      screenTimeInBed: screenTimeInBed,
      lateDinner: lateDinner,
      exercisedToday: exercisedToday,
    );

    final sleepLog = SleepLog(
      id: _uuid.v4(),
      userId: userId,
      sleepTime: sleepTime,
      wakeTime: wakeTime,
      reportedQuality: reportedQuality,
      caffeineAfter3PM: caffeineAfter3PM,
      screenTimeInBed: screenTimeInBed,
      lateDinner: lateDinner,
      calculatedQuality: calculatedQuality,
      loggedAt: now,
      updatedAt: now,
    );

    // Optimistic UI updates
    _sleepLogs.insert(0, sleepLog);
    notifyListeners();

    await _dbService.upsertLocalSleepLog(sleepLog);

    // Queue sync mutation
    final syncItem = SyncItem(
      actionType: 'INSERT',
      tableName: 'sleep_logs',
      recordId: sleepLog.id,
      payload: sleepLog.toJson(),
    );
    await _dbService.queueMutation(syncItem);

    // Trigger sync
    _syncService.sync(userId).then((_) async {
      _sleepLogs = await _dbService.getLocalSleepLogs(userId);
      notifyListeners();
    });
  }

  // Delete sleep log
  Future<void> deleteSleepLog(SleepLog log) async {
    _sleepLogs.removeWhere((s) => s.id == log.id);
    notifyListeners();

    await _dbService.deleteLocalSleepLog(log.id);

    final syncItem = SyncItem(
      actionType: 'DELETE',
      tableName: 'sleep_logs',
      recordId: log.id,
    );
    await _dbService.queueMutation(syncItem);

    _syncService.sync(log.userId).then((_) async {
      _sleepLogs = await _dbService.getLocalSleepLogs(log.userId);
      notifyListeners();
    });
  }
}
