import 'dart:io';
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

class SyncService {
  final DatabaseService _dbService = DatabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;

  // Check if network is available
  Future<bool> isConnected() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
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
          await _supabase.from(item.tableName).delete().eq('id', item.recordId);
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
      'last_sync_timestamp',
      defaultValue: '1970-01-01T00:00:00.000Z',
    ) as String;

    final currentSyncTime = DateTime.now().toUtc().toIso8601String();
    final db = await _dbService.database;

    // A. Sync Tasks
    final List<dynamic> remoteTasks = await _supabase
        .from('tasks')
        .select()
        .eq('user_id', userId)
        .gt('updated_at', lastSyncString);

    if (remoteTasks.isNotEmpty) {
      await db.transaction((txn) async {
        for (final row in remoteTasks) {
          final remoteTask = Task.fromJson(row as Map<String, dynamic>);
          final List<Map<String, dynamic>> localMatch = await txn.query(
            'local_tasks',
            where: 'id = ?',
            whereArgs: [remoteTask.id],
          );

          if (localMatch.isEmpty) {
            await txn.insert('local_tasks', remoteTask.toSqliteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
          } else {
            final localTask = Task.fromSqliteMap(localMatch.first);
            if (remoteTask.updatedAt.isAfter(localTask.updatedAt)) {
              await txn.insert('local_tasks', remoteTask.toSqliteMap(), conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
        }
      });
    }

    // B. Sync Workouts
    final List<dynamic> remoteWorkouts = await _supabase
        .from('workouts')
        .select()
        .eq('user_id', userId)
        .gt('updated_at', lastSyncString);

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

    // C. Sync Sleep Logs
    final List<dynamic> remoteSleepLogs = await _supabase
        .from('sleep_logs')
        .select()
        .eq('user_id', userId)
        .gt('updated_at', lastSyncString);

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

    // D. Sync Food Logs
    final List<dynamic> remoteFoodLogs = await _supabase
        .from('food_logs')
        .select()
        .eq('user_id', userId)
        .gt('updated_at', lastSyncString);

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

    // E. Sync Water Logs
    final List<dynamic> remoteWaterLogs = await _supabase
        .from('water_logs')
        .select()
        .eq('user_id', userId)
        .gt('updated_at', lastSyncString);

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

    // F. Sync Addiction Logs
    final List<dynamic> remoteAddictionLogs = await _supabase
        .from('addiction_logs')
        .select()
        .eq('user_id', userId)
        .gt('updated_at', lastSyncString);

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

    // G. Sync Finance Transactions
    final List<dynamic> remoteFinanceTransactions = await _supabase
        .from('finance_transactions')
        .select()
        .eq('user_id', userId)
        .gt('updated_at', lastSyncString);

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

    // H. Sync Social Contacts
    final List<dynamic> remoteSocialContacts = await _supabase
        .from('social_contacts')
        .select()
        .eq('user_id', userId)
        .gt('updated_at', lastSyncString);

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

    // I. Sync Learning Subjects
    final List<dynamic> remoteLearningSubjects = await _supabase
        .from('learning_subjects')
        .select()
        .eq('user_id', userId)
        .gt('updated_at', lastSyncString);

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

    // J. Sync Study Logs
    final List<dynamic> remoteStudyLogs = await _supabase
        .from('study_logs')
        .select()
        .eq('user_id', userId)
        .gt('updated_at', lastSyncString);

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

    // Save current sync timestamp
    await _dbService.settingsBox.put('last_sync_timestamp', currentSyncTime);
  }
}
