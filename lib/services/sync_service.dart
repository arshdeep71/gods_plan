import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import '../models/sync_item.dart';
import '../models/task.dart';
import '../models/workout.dart';
import '../models/sleep_log.dart';
import '../models/food_log.dart';
import '../models/water_log.dart';
import '../models/addiction_log.dart';
import '../models/finance_transaction.dart';
import '../models/social.dart';
import '../models/learning.dart';
import 'package:sqflite_common/sqlite_api.dart';
import '../utils/network_helper.dart';

class SyncService {
  final DatabaseService _dbService = DatabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;

  // Check if network is available
  Future<bool> isConnected() async {
    return await checkInternetConnection();
  }

  // Master synchronization coordination
  Future<void> sync(String userId) async {
    if (!await isConnected()) return;

    try {
      // 1. Upload local pending modifications
      await _uploadLocalMutations();

      // 2. Download remote updates
      await _downloadRemoteUpdates(userId);
    } catch (e) {
      // Fail silently or log error locally, app runs offline-first
      print("Sync error encountered: $e");
    }
  }

  // Push local changes to Supabase
  Future<void> _uploadLocalMutations() async {
    final queue = await _dbService.getSyncQueue();
    if (queue.isEmpty) return;

    for (final item in queue) {
      try {
        if (item.actionType == 'INSERT' || item.actionType == 'UPDATE') {
          if (item.payload != null) {
            await _supabase.from(item.tableName).upsert(item.payload!);
          }
        } else if (item.actionType == 'DELETE') {
          if (item.tableName == 'task_completions') {
            final parts = item.recordId.split('_');
            if (parts.length >= 2) {
              final taskId = parts[0];
              final completedDate = parts[1];
              await _supabase
                  .from('task_completions')
                  .delete()
                  .eq('task_id', taskId)
                  .eq('completed_date', completedDate);
            }
          } else if (item.tableName == 'task_exceptions') {
            final parts = item.recordId.split('_');
            if (parts.length >= 2) {
              final taskId = parts[0];
              final exceptionDate = parts[1];
              await _supabase
                  .from('task_exceptions')
                  .delete()
                  .eq('task_id', taskId)
                  .eq('exception_date', exceptionDate);
            }
          } else {
            await _supabase.from(item.tableName).delete().eq('id', item.recordId);
          }
        }
        
        // Remove item from queue upon success
        if (item.id != null) {
          await _dbService.removeSyncItem(item.id!);
        }
      } catch (e) {
        // If it's a validation error or database conflict, log and skip to prevent blocking the queue
        print("Failed to sync queue item ${item.id}: $e");
      }
    }
  }

  // Pull remote updates from Supabase (Tasks, Workouts, Sleep, Nutrition, Water)
  Future<void> _downloadRemoteUpdates(String userId) async {
    final lastSyncString = _dbService.settingsBox.get(
      'last_sync_timestamp_$userId',
      defaultValue: '1970-01-01T00:00:00.000Z',
    ) as String;

    final currentSyncTime = DateTime.now().toUtc().toIso8601String();
    final db = await _dbService.database;

    // Use a 1-day safety window to pull other updates (protects against clock skew)
    final lastSyncDateTime = DateTime.parse(lastSyncString);
    final queryTimestamp = lastSyncDateTime.subtract(const Duration(days: 1)).toUtc().toIso8601String();

    // A. Sync Tasks (Full Mirroring to handle deletes)
    try {
      final List<dynamic> remoteTasks = await _supabase
          .from('tasks')
          .select()
          .eq('user_id', userId);

      await db.transaction((txn) async {
        // Get all local tasks for this user
        final List<Map<String, dynamic>> localTasks = await txn.query(
          'local_tasks',
          where: 'user_id = ?',
          whereArgs: [userId],
        );

        final remoteIds = remoteTasks.map((t) => t['id'] as String).toSet();

        // Delete local tasks that are not present in remote (deleted on another device)
        for (final local in localTasks) {
          final localId = local['id'] as String;
          if (!remoteIds.contains(localId)) {
            await txn.delete(
              'local_tasks',
              where: 'id = ?',
              whereArgs: [localId],
            );
          }
        }

        // Insert or update remote tasks
        for (final row in remoteTasks) {
          final remoteTask = Task.fromJson(row as Map<String, dynamic>);
          await txn.insert('local_tasks', remoteTask.toSqliteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    } catch (e) {
      print("Sync tasks error: $e");
    }

    // A.1 Sync Task Completions (Full Mirroring to handle deletes)
    try {
      final List<dynamic> remoteCompletions = await _supabase
          .from('task_completions')
          .select()
          .eq('user_id', userId);

      await db.transaction((txn) async {
        // Clear local completions and rewrite them to match remote exactly
        await txn.delete('local_task_completions');
        for (final row in remoteCompletions) {
          await txn.insert('local_task_completions', Map<String, dynamic>.from(row), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    } catch (e) {
      print("Sync task completions error: $e");
    }

    // A.2 Sync Task Exceptions (Full Mirroring to handle deletes)
    try {
      final List<dynamic> remoteExceptions = await _supabase
          .from('task_exceptions')
          .select()
          .eq('user_id', userId);

      await db.transaction((txn) async {
        // Clear local exceptions and rewrite them to match remote exactly
        await txn.delete('local_task_exceptions');
        for (final row in remoteExceptions) {
          final map = Map<String, dynamic>.from(row);
          if (map['is_deleted'] is bool) {
            map['is_deleted'] = (map['is_deleted'] as bool) ? 1 : 0;
          }
          await txn.insert('local_task_exceptions', map, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    } catch (e) {
      print("Sync task exceptions error: $e");
    }

    // B. Sync Workouts (Incremental with safety margin)
    try {
      final List<dynamic> remoteWorkouts = await _supabase
          .from('workouts')
          .select()
          .eq('user_id', userId)
          .gt('updated_at', queryTimestamp);

      if (remoteWorkouts.isNotEmpty) {
        await db.transaction((txn) async {
          for (final row in remoteWorkouts) {
            final remoteWorkout = Workout.fromJson(row as Map<String, dynamic>);
            final List<Map<String, dynamic>> localMatch = await txn.query(
              'local_workouts',
              where: 'id = ?',
              whereArgs: [remoteWorkout.id],
            );

            if (localMatch.isEmpty) {
              await txn.insert('local_workouts', remoteWorkout.toSqliteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
            } else {
              final localWorkout = Workout.fromSqliteMap(localMatch.first);
              if (remoteWorkout.updatedAt.isAfter(localWorkout.updatedAt)) {
                await txn.insert('local_workouts', remoteWorkout.toSqliteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
          }
        });
      }
    } catch (e) {
      print("Sync workouts error: $e");
    }

    // C. Sync Sleep Logs (Incremental with safety margin)
    try {
      final List<dynamic> remoteSleepLogs = await _supabase
          .from('sleep_logs')
          .select()
          .eq('user_id', userId)
          .gt('updated_at', queryTimestamp);

      if (remoteSleepLogs.isNotEmpty) {
        await db.transaction((txn) async {
          for (final row in remoteSleepLogs) {
            final remoteSleep = SleepLog.fromJson(row as Map<String, dynamic>);
            final List<Map<String, dynamic>> localMatch = await txn.query(
              'local_sleep_logs',
              where: 'id = ?',
              whereArgs: [remoteSleep.id],
            );

            if (localMatch.isEmpty) {
              await txn.insert('local_sleep_logs', remoteSleep.toSqliteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
            } else {
              final localSleep = SleepLog.fromSqliteMap(localMatch.first);
              if (remoteSleep.updatedAt.isAfter(localSleep.updatedAt)) {
                await txn.insert('local_sleep_logs', remoteSleep.toSqliteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
          }
        });
      }
    } catch (e) {
      print("Sync sleep logs error: $e");
    }

    // D. Sync Food Logs (Incremental with safety margin)
    try {
      final List<dynamic> remoteFoodLogs = await _supabase
          .from('food_logs')
          .select()
          .eq('user_id', userId)
          .gt('updated_at', queryTimestamp);

      if (remoteFoodLogs.isNotEmpty) {
        await db.transaction((txn) async {
          for (final row in remoteFoodLogs) {
            final remoteFood = FoodLog.fromJson(row as Map<String, dynamic>);
            final List<Map<String, dynamic>> localMatch = await txn.query(
              'local_food_logs',
              where: 'id = ?',
              whereArgs: [remoteFood.id],
            );

            if (localMatch.isEmpty) {
              await txn.insert('local_food_logs', remoteFood.toSqliteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
            } else {
              final localFood = FoodLog.fromSqliteMap(localMatch.first);
              if (remoteFood.updatedAt.isAfter(localFood.updatedAt)) {
                await txn.insert('local_food_logs', remoteFood.toSqliteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
          }
        });
      }
    } catch (e) {
      print("Sync food logs error: $e");
    }

    // E. Sync Water Logs (Incremental with safety margin)
    try {
      final List<dynamic> remoteWaterLogs = await _supabase
          .from('water_logs')
          .select()
          .eq('user_id', userId)
          .gt('updated_at', queryTimestamp);

      if (remoteWaterLogs.isNotEmpty) {
        await db.transaction((txn) async {
          for (final row in remoteWaterLogs) {
            final remoteWater = WaterLog.fromJson(row as Map<String, dynamic>);
            final List<Map<String, dynamic>> localMatch = await txn.query(
              'local_water_logs',
              where: 'id = ?',
              whereArgs: [remoteWater.id],
            );

            if (localMatch.isEmpty) {
              await txn.insert('local_water_logs', remoteWater.toSqliteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
            } else {
              final localWater = WaterLog.fromSqliteMap(localMatch.first);
              if (remoteWater.updatedAt.isAfter(localWater.updatedAt)) {
                await txn.insert('local_water_logs', remoteWater.toSqliteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
          }
        });
      }
    } catch (e) {
      print("Sync water logs error: $e");
    }

    // F. Sync Addiction Logs (Incremental with safety margin)
    try {
      final List<dynamic> remoteAddictionLogs = await _supabase
          .from('addiction_logs')
          .select()
          .eq('user_id', userId)
          .gt('updated_at', queryTimestamp);

      if (remoteAddictionLogs.isNotEmpty) {
        await db.transaction((txn) async {
          for (final row in remoteAddictionLogs) {
            final remoteAddiction = AddictionLog.fromJson(row as Map<String, dynamic>);
            final List<Map<String, dynamic>> localMatch = await txn.query(
              'local_addiction_logs',
              where: 'id = ?',
              whereArgs: [remoteAddiction.id],
            );

            if (localMatch.isEmpty) {
              await txn.insert('local_addiction_logs', remoteAddiction.toSqliteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
            } else {
              final localAddiction = AddictionLog.fromSqliteMap(localMatch.first);
              if (remoteAddiction.updatedAt.isAfter(localAddiction.updatedAt)) {
                await txn.insert('local_addiction_logs', remoteAddiction.toSqliteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
          }
        });
      }
    } catch (e) {
      print("Sync addiction logs error: $e");
    }

    // G. Sync Finance Transactions (Incremental with safety margin)
    try {
      final List<dynamic> remoteFinanceTransactions = await _supabase
          .from('finance_transactions')
          .select()
          .eq('user_id', userId)
          .gt('updated_at', queryTimestamp);

      if (remoteFinanceTransactions.isNotEmpty) {
        await db.transaction((txn) async {
          for (final row in remoteFinanceTransactions) {
            final remoteFinance = FinanceTransaction.fromJson(row as Map<String, dynamic>);
            final List<Map<String, dynamic>> localMatch = await txn.query(
              'local_finance_transactions',
              where: 'id = ?',
              whereArgs: [remoteFinance.id],
            );

            if (localMatch.isEmpty) {
              await txn.insert('local_finance_transactions', remoteFinance.toSqliteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
            } else {
              final localFinance = FinanceTransaction.fromSqliteMap(localMatch.first);
              if (remoteFinance.updatedAt.isAfter(localFinance.updatedAt)) {
                await txn.insert('local_finance_transactions', remoteFinance.toSqliteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
          }
        });
      }
    } catch (e) {
      print("Sync finance transactions error: $e");
    }

    // H. Sync Social Contacts (Incremental with safety margin)
    try {
      final List<dynamic> remoteSocialContacts = await _supabase
          .from('social_contacts')
          .select()
          .eq('user_id', userId)
          .gt('updated_at', queryTimestamp);

      if (remoteSocialContacts.isNotEmpty) {
        await db.transaction((txn) async {
          for (final row in remoteSocialContacts) {
            final remoteContact = SocialContact.fromJson(row as Map<String, dynamic>);
            final List<Map<String, dynamic>> localMatch = await txn.query(
              'local_social_contacts',
              where: 'id = ?',
              whereArgs: [remoteContact.id],
            );

            if (localMatch.isEmpty) {
              await txn.insert('local_social_contacts', remoteContact.toSqliteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
            } else {
              final localContact = SocialContact.fromSqliteMap(localMatch.first);
              if (remoteContact.updatedAt.isAfter(localContact.updatedAt)) {
                await txn.insert('local_social_contacts', remoteContact.toSqliteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
          }
        });
      }
    } catch (e) {
      print("Sync social contacts error: $e");
    }

    // I. Sync Learning Subjects (Incremental with safety margin)
    try {
      final List<dynamic> remoteLearningSubjects = await _supabase
          .from('learning_subjects')
          .select()
          .eq('user_id', userId)
          .gt('updated_at', queryTimestamp);

      if (remoteLearningSubjects.isNotEmpty) {
        await db.transaction((txn) async {
          for (final row in remoteLearningSubjects) {
            final remoteSubject = LearningSubject.fromJson(row as Map<String, dynamic>);
            final List<Map<String, dynamic>> localMatch = await txn.query(
              'local_learning_subjects',
              where: 'id = ?',
              whereArgs: [remoteSubject.id],
            );

            if (localMatch.isEmpty) {
              await txn.insert('local_learning_subjects', remoteSubject.toSqliteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
            } else {
              final localSubject = LearningSubject.fromSqliteMap(localMatch.first);
              if (remoteSubject.updatedAt.isAfter(localSubject.updatedAt)) {
                await txn.insert('local_learning_subjects', remoteSubject.toSqliteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
          }
        });
      }
    } catch (e) {
      print("Sync learning subjects error: $e");
    }

    // J. Sync Study Logs (Incremental with safety margin)
    try {
      final List<dynamic> remoteStudyLogs = await _supabase
          .from('study_logs')
          .select()
          .eq('user_id', userId)
          .gt('updated_at', queryTimestamp);

      if (remoteStudyLogs.isNotEmpty) {
        await db.transaction((txn) async {
          for (final row in remoteStudyLogs) {
            final remoteLog = StudyLog.fromJson(row as Map<String, dynamic>);
            final List<Map<String, dynamic>> localMatch = await txn.query(
              'local_study_logs',
              where: 'id = ?',
              whereArgs: [remoteLog.id],
            );

            if (localMatch.isEmpty) {
              await txn.insert('local_study_logs', remoteLog.toSqliteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
            } else {
              final localLog = StudyLog.fromSqliteMap(localMatch.first);
              if (remoteLog.updatedAt.isAfter(localLog.updatedAt)) {
                await txn.insert('local_study_logs', remoteLog.toSqliteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
          }
        });
      }
    } catch (e) {
      print("Sync study logs error: $e");
    }

    // K. Sync Profile Username, XP, targets, App Lock, and Restores
    try {
      final profileData = await _supabase
          .from('profiles')
          .select('username, xp, streak_restores, restored_dates, last_restore_reset, app_lock_pin, daily_savings_target, monthly_savings_target, big_savings_target, nutrition_profile, xp_awarded_dates')
          .eq('id', userId)
          .maybeSingle();
      if (profileData != null) {
        if (profileData['username'] != null) {
          await _dbService.settingsBox.put('username_$userId', profileData['username'] as String);
        }
        if (profileData['xp'] != null) {
          await _dbService.settingsBox.put('xp_$userId', profileData['xp'] as int);
        }
        if (profileData['streak_restores'] != null) {
          await _dbService.settingsBox.put('restores_left_$userId', profileData['streak_restores'] as int);
        }
        if (profileData['restored_dates'] != null) {
          final List<dynamic> datesRaw = profileData['restored_dates'] as List;
          final List<String> restoredList = datesRaw.map((d) => d.toString()).toList();
          await _dbService.settingsBox.put('restored_dates_$userId', restoredList);
        }
        if (profileData['last_restore_reset'] != null) {
          await _dbService.settingsBox.put('restore_reset_date_$userId', profileData['last_restore_reset'] as String);
        }
        if (profileData['app_lock_pin'] != null) {
          await _dbService.settingsBox.put('app_lock_pin_$userId', profileData['app_lock_pin'] as String);
        } else {
          await _dbService.settingsBox.delete('app_lock_pin_$userId');
        }
        if (profileData['daily_savings_target'] != null) {
          await _dbService.settingsBox.put('daily_savings_target_$userId', (profileData['daily_savings_target'] as num).toDouble());
        }
        if (profileData['monthly_savings_target'] != null) {
          await _dbService.settingsBox.put('monthly_savings_target_$userId', (profileData['monthly_savings_target'] as num).toDouble());
        }
        if (profileData['big_savings_target'] != null) {
          await _dbService.settingsBox.put('big_savings_target_$userId', (profileData['big_savings_target'] as num).toDouble());
        }
        if (profileData['nutrition_profile'] != null) {
          await _dbService.settingsBox.put('nutrition_profile_$userId', profileData['nutrition_profile']);
        }
        if (profileData['xp_awarded_dates'] != null) {
          await _dbService.settingsBox.put('xp_awarded_dates_$userId', profileData['xp_awarded_dates']);
        }
      }
    } catch (e) {
      print("Sync profile error: $e");
    }

    // L. Sync Goals
    try {
      final goalData = await _supabase
          .from('goals')
          .select('start_date, end_date')
          .eq('user_id', userId)
          .maybeSingle();
      if (goalData != null) {
        await _dbService.setLocalGoalDates(
          goalData['start_date'] as String,
          goalData['end_date'] as String,
        );
        await _dbService.setOnboarded(true);
      }
    } catch (e) {
      print("Sync goals error: $e");
    }

    // Save current sync timestamp
    await _dbService.settingsBox.put('last_sync_timestamp_$userId', currentSyncTime);
  }
}
