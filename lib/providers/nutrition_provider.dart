import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/nutrition_profile.dart';
import '../models/food_log.dart';
import '../models/water_log.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../models/sync_item.dart';

class NutritionProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final SyncService _syncService = SyncService();
  final _uuid = const Uuid();

  List<FoodLog> _foodLogs = [];
  List<WaterLog> _waterLogs = [];
  late NutritionProfile _profile;
  bool _isLoading = false;
  bool _isSyncing = false;

  List<FoodLog> get foodLogs => _foodLogs;
  List<WaterLog> get waterLogs => _waterLogs;
  NutritionProfile get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;

  NutritionProvider() {
    loadNutritionProfile();
  }

  // Load the BMR/TDEE calculation settings
  void loadNutritionProfile() {
    final rawProfile = _dbService.settingsBox.get('nutrition_profile');
    if (rawProfile != null) {
      try {
        final Map<String, dynamic> jsonMap = Map<String, dynamic>.from(
          rawProfile is String ? jsonDecode(rawProfile) : rawProfile,
        );
        _profile = NutritionProfile.fromJson(jsonMap);
      } catch (e) {
        _profile = NutritionProfile.defaultProfile();
      }
    } else {
      _profile = NutritionProfile.defaultProfile();
    }
  }

  // Save/Calculate new profile limits
  Future<void> saveNutritionProfile(NutritionProfile newProfile) async {
    _profile = newProfile;
    await _dbService.settingsBox.put('nutrition_profile', newProfile.toJson());
    notifyListeners();
  }

  // Todays Nutrition Metrics
  double get caloriesLoggedToday {
    final today = DateTime.now();
    return _foodLogs
        .where((f) => f.loggedAt.year == today.year && 
                      f.loggedAt.month == today.month && 
                      f.loggedAt.day == today.day)
        .fold(0.0, (sum, f) => sum + f.calories);
  }

  double get proteinLoggedToday {
    final today = DateTime.now();
    return _foodLogs
        .where((f) => f.loggedAt.year == today.year && 
                      f.loggedAt.month == today.month && 
                      f.loggedAt.day == today.day)
        .fold(0.0, (sum, f) => sum + f.protein);
  }

  double get carbsLoggedToday {
    final today = DateTime.now();
    return _foodLogs
        .where((f) => f.loggedAt.year == today.year && 
                      f.loggedAt.month == today.month && 
                      f.loggedAt.day == today.day)
        .fold(0.0, (sum, f) => sum + f.carbs);
  }

  double get fatsLoggedToday {
    final today = DateTime.now();
    return _foodLogs
        .where((f) => f.loggedAt.year == today.year && 
                      f.loggedAt.month == today.month && 
                      f.loggedAt.day == today.day)
        .fold(0.0, (sum, f) => sum + f.fats);
  }

  // Water metrics today
  int get waterGlassesLoggedToday {
    final today = DateTime.now();
    final match = _waterLogs.firstWhere(
      (w) => w.loggedAt.year == today.year && 
             w.loggedAt.month == today.month && 
             w.loggedAt.day == today.day,
      orElse: () => WaterLog(id: '', userId: '', glasses: 0, loggedAt: today, updatedAt: today),
    );
    return match.glasses;
  }

  // Dynamic water calculation target linked to exercise
  int getCalculatedWaterTarget(int activeExerciseMinutes) {
    // Default 8 glasses + 1 glass for every 30 mins active
    int extraGlasses = (activeExerciseMinutes / 30).floor();
    return 8 + extraGlasses;
  }

  // Fetch SQLite logs and run sync
  Future<void> fetchNutritionData(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _foodLogs = await _dbService.getLocalFoodLogs(userId);
      _waterLogs = await _dbService.getLocalWaterLogs(userId);
      _isLoading = false;
      notifyListeners();

      _isSyncing = true;
      notifyListeners();

      await _syncService.sync(userId);

      _foodLogs = await _dbService.getLocalFoodLogs(userId);
      _waterLogs = await _dbService.getLocalWaterLogs(userId);
    } catch (e) {
      print("Error loading nutrition metrics: $e");
    } finally {
      _isLoading = false;
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Add Food Log
  Future<void> addFoodLog({
    required String userId,
    required String foodName,
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
  }) async {
    final now = DateTime.now();
    final log = FoodLog(
      id: _uuid.v4(),
      userId: userId,
      foodName: foodName,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
      loggedAt: now,
      updatedAt: now,
    );

    _foodLogs.insert(0, log);
    notifyListeners();

    await _dbService.upsertLocalFoodLog(log);

    final syncItem = SyncItem(
      actionType: 'INSERT',
      tableName: 'food_logs',
      recordId: log.id,
      payload: log.toJson(),
    );
    await _dbService.queueMutation(syncItem);

    _syncService.sync(userId).then((_) async {
      _foodLogs = await _dbService.getLocalFoodLogs(userId);
      notifyListeners();
    });
  }

  // Delete Food Log
  Future<void> deleteFoodLog(FoodLog log) async {
    _foodLogs.removeWhere((f) => f.id == log.id);
    notifyListeners();

    await _dbService.deleteLocalFoodLog(log.id);

    final syncItem = SyncItem(
      actionType: 'DELETE',
      tableName: 'food_logs',
      recordId: log.id,
    );
    await _dbService.queueMutation(syncItem);

    _syncService.sync(log.userId).then((_) async {
      _foodLogs = await _dbService.getLocalFoodLogs(log.userId);
      notifyListeners();
    });
  }

  // Log water glasses consumed
  Future<void> setWaterGlasses(String userId, int glasses) async {
    final today = DateTime.now();
    WaterLog? existingLog;
    try {
      existingLog = _waterLogs.firstWhere(
        (w) => w.loggedAt.year == today.year && 
               w.loggedAt.month == today.month && 
               w.loggedAt.day == today.day,
      );
    } catch (_) {
      existingLog = null;
    }

    final now = DateTime.now();
    final log = WaterLog(
      id: existingLog?.id ?? _uuid.v4(),
      userId: userId,
      glasses: glasses,
      loggedAt: existingLog?.loggedAt ?? now,
      updatedAt: now,
    );

    if (existingLog == null) {
      _waterLogs.insert(0, log);
    } else {
      final index = _waterLogs.indexWhere((w) => w.id == log.id);
      if (index != -1) {
        _waterLogs[index] = log;
      }
    }
    notifyListeners();

    await _dbService.upsertLocalWaterLog(log);

    final syncItem = SyncItem(
      actionType: 'INSERT',
      tableName: 'water_logs',
      recordId: log.id,
      payload: log.toJson(),
    );
    await _dbService.queueMutation(syncItem);

    _syncService.sync(userId).then((_) async {
      _waterLogs = await _dbService.getLocalWaterLogs(userId);
      notifyListeners();
    });
  }
}
