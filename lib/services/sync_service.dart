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
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/network_helper.dart';
import 'dart:convert';

class SyncService {
  final DatabaseService _dbService = DatabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _syncInProgress = false;
  bool _syncNeededAfterCurrent = false;

  SyncService() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.none)) return;
      // Network restored, attempt sync if logged in
      final userId = _dbService.currentUserId;
      if (userId != null) sync(userId);
    });
  }

  // Check if network is available
  Future<bool> isConnected() async {
    return await checkInternetConnection();
  }

  // Master synchronization coordination
  Future<void> sync(String userId) async {
    print("[SYNC] sync() requested for user: $userId");
    if (_syncInProgress) {
      print("[SYNC] Synchronization already in progress. Setting follow-up flag to true.");
      _syncNeededAfterCurrent = true;
      return;
    }
    _syncInProgress = true;

    try {
      print("[SYNC] Starting synchronization cycle...");
      if (!await isConnected()) {
        print("[SYNC] Connection failed, offline-first. Aborting sync.");
        return;
      }

      final isPendingDelete = _dbService.settingsBox.get('pending_profile_deletion_$userId', defaultValue: false) as bool;
      if (isPendingDelete) {
        await deleteRemoteUserProfileData(userId);
        await _dbService.settingsBox.put('pending_profile_deletion_$userId', false);
      }

      // 1. Upload local pending modifications
      await _uploadLocalMutations();

      // 2. Download remote updates
      await _downloadRemoteUpdates(userId);
      print("[SYNC] Synchronization cycle completed successfully.");
    } catch (e) {
      // Fail silently or log error locally, app runs offline-first
      print("[SYNC] Sync error encountered: $e");
    } finally {
      _syncInProgress = false;
      if (_syncNeededAfterCurrent) {
        print("[SYNC] Follow-up synchronization requested. Starting next cycle.");
        _syncNeededAfterCurrent = false;
        // Schedule follow-up sync asynchronously to prevent stack overflow
        Future.microtask(() => sync(userId));
      }
    }
  }

  Future<void> deleteRemoteUserProfileData(String userId) async {
    final tables = [
      'tasks',
      'task_completions',
      'task_exceptions',
      'workouts',
      'sleep_logs',
      'food_logs',
      'water_logs',
      'addiction_logs',
      'finance_transactions',
      'social_contacts',
      'learning_subjects',
      'study_logs',
      'goals'
    ];
    for (final table in tables) {
      try {
        await _supabase.from(table).delete().eq('user_id', userId);
      } catch (e) {
        print("Failed to delete table $table remote data: $e");
      }
    }
    // Update profiles table instead of deleting it
    try {
      await _supabase.from('profiles').update({
        'xp': 0,
        'streak_restores': 3,
        'restored_dates': [],
        'last_restore_reset': null,
        'app_lock_pin': null,
        'daily_savings_target': 500,
        'monthly_savings_target': 15000,
        'big_savings_target': 5000,
        'nutrition_profile': null,
        'xp_awarded_dates': {},
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      print("Failed to update profile remote data: $e");
    }
  }

  // Push local changes to Supabase
  Future<void> _uploadLocalMutations() async {
    final queue = await _dbService.getSyncQueue();
    final now = DateTime.now().toUtc();
    print("[SYNC QUEUE] Upload started. Items pending: \${queue.length}");
    if (queue.isEmpty) return;

    for (final item in queue) {
      // Exponential Backoff Check
      if (item.nextRetryAt != null && item.nextRetryAt!.isAfter(now)) {
        print("[SYNC QUEUE] Skipping item \${item.id} due to exponential backoff. Next retry: \${item.nextRetryAt}");
        continue;
      }

      try {
        print("[SYNC QUEUE] Uploading item ID: \${item.id}, Table: \${item.tableName}, Action: \${item.actionType}");
        if (item.actionType == 'INSERT' || item.actionType == 'UPDATE') {
          if (item.payload != null) {
            await _supabase.from(item.tableName).upsert(item.payload!);
            print("[SYNC QUEUE] Upsert remote success for table: \${item.tableName}, ID: \${item.recordId}");
          }
        } else if (item.actionType == 'DELETE') {
          if (item.tableName == 'task_completions') {
            final parts = item.recordId.split('_');
            if (parts.length >= 2) {
              await _supabase
                  .from('task_completions')
                  .delete()
                  .eq('task_id', parts[0])
                  .eq('completed_date', parts[1]);
            }
          } else if (item.tableName == 'task_exceptions') {
            final parts = item.recordId.split('_');
            if (parts.length >= 2) {
              await _supabase
                  .from('task_exceptions')
                  .delete()
                  .eq('task_id', parts[0])
                  .eq('exception_date', parts[1]);
            }
          } else {
            await _supabase.from(item.tableName).delete().eq('id', item.recordId);
          }
          print("[SYNC QUEUE] Delete remote success for table: \${item.tableName}, ID: \${item.recordId}");
        }
        
        // Remove item from queue upon success
        if (item.id != null) {
          await _dbService.removeSyncItem(item.id!);
          print("[SYNC QUEUE] Removed item ID \${item.id} from local queue");
        }
      } catch (e) {
        // If it's a validation error or database conflict, log and skip to prevent blocking the queue
        print("[SYNC QUEUE] Failed to sync queue item \${item.id}: \$e");
        
        // Calculate exponential backoff (2^retryCount minutes)
        if (item.id != null) {
          final nextRetry = now.add(Duration(minutes: 1 << item.retryCount));
          final updatedItem = item.copyWith(
            retryCount: item.retryCount + 1,
            nextRetryAt: nextRetry,
          );
          await _dbService.updateSyncItem(updatedItem);
          print("[SYNC QUEUE] Scheduled retry for item \${item.id} at \$nextRetry (Retry #\${item.retryCount + 1})");
        }
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
    final syncStart = DateTime.now().toUtc();
    final db = await _dbService.database;

    // Use a 1-day safety window to pull other updates (protects against clock skew)
    final lastSyncDateTime = DateTime.parse(lastSyncString);
    final queryTimestamp = lastSyncDateTime.subtract(const Duration(days: 1)).toUtc().toIso8601String();

    // A. Sync Tasks (Full Mirroring to handle deletes)
    try {
      print("[LOAD] Method: _downloadRemoteUpdates -> tasks, Reason: Sync mirror, Source: Supabase remote");
      final List<dynamic> remoteTasks = await _supabase
          .from('tasks')
          .select()
          .eq('user_id', userId);
      print("[SUPABASE] GET /tasks. Received remote task count: ${remoteTasks.length}");

      await db.transaction((txn) async {
        // Get all local tasks for this user
        final List<Map<String, dynamic>> localTasks = await txn.query(
          'local_tasks',
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        print("[DATABASE] Task count in SQLite before mirror = ${localTasks.length}");

        final remoteIds = remoteTasks.map((t) => t['id'] as String).toSet();

        // Query pending mutations from the offline sync queue
        final List<Map<String, dynamic>> pendingQueue = await txn.query(
          'offline_sync_queue',
          where: 'table_name = ?',
          whereArgs: ['tasks'],
        );
        final pendingIds = pendingQueue.map((item) => item['record_id'] as String).toSet();
        print("[SYNC] Pending task IDs in sync queue: $pendingIds");

        // Delete local tasks that are not present in remote (deleted on another device)
        for (final local in localTasks) {
          final localId = local['id'] as String;
          if (!remoteIds.contains(localId)) {
            // VERIFY NO PREMATURE DELETION CHECKS:
            // 1. Check if ID is in offline_sync_queue (any action: INSERT, UPDATE, DELETE)
            final inQueue = pendingIds.contains(localId);
            
            // 2, 3, 4. Check specific mutations
            final hasInsert = pendingQueue.any((item) => item['record_id'] == localId && item['action_type'] == 'INSERT');
            final hasUpdate = pendingQueue.any((item) => item['record_id'] == localId && item['action_type'] == 'UPDATE');
            final hasDelete = pendingQueue.any((item) => item['record_id'] == localId && item['action_type'] == 'DELETE');

            // 5. Check if task was created during the current synchronization cycle
            final createdAtStr = local['created_at'] as String?;
            bool createdThisCycle = false;
            if (createdAtStr != null) {
              final taskCreatedAt = DateTime.tryParse(createdAtStr);
              if (taskCreatedAt != null) {
                // If created within last 5 minutes of sync start, consider it created this cycle
                createdThisCycle = syncStart.difference(taskCreatedAt).inMinutes < 5;
              }
            }

            if (inQueue || hasInsert || hasUpdate || hasDelete || createdThisCycle) {
              print("[SYNC] Deletion skipped for local task '$localId'. Reason: inQueue=$inQueue, hasInsert=$hasInsert, hasUpdate=$hasUpdate, hasDelete=$hasDelete, createdThisCycle=$createdThisCycle");
              continue;
            }

            print("[SYNC] Deleting local task '$localId' from SQLite (not in remote tasks and no pending mutations)");
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

        final result = await txn.rawQuery("SELECT COUNT(*) AS count FROM local_tasks WHERE user_id = ?", [userId]);
        final localCountAfter = (result.first['count'] as int?) ?? 0;
        print("[DATABASE] Task count in SQLite after mirror = $localCountAfter");
      });
    } catch (e) {
      print("Sync tasks error: $e");
    }

    // A.1 Sync Task Completions (Full Mirroring to handle deletes)
    try {
      print("[LOAD] Method: _downloadRemoteUpdates -> task_completions, Reason: Sync mirror, Source: Supabase remote");
      final List<dynamic> remoteCompletions = await _supabase
          .from('task_completions')
          .select()
          .eq('user_id', userId);
      print("[SUPABASE] GET /task_completions. Received count: ${remoteCompletions.length}");

      await db.transaction((txn) async {
        // Query pending mutations from offline sync queue for task completions
        final List<Map<String, dynamic>> pendingQueue = await txn.query(
          'offline_sync_queue',
          where: 'table_name = ?',
          whereArgs: ['task_completions'],
        );

        final pendingInserts = pendingQueue
            .where((item) => item['action_type'] == 'INSERT')
            .map((item) {
              final payloadStr = item['payload'] as String?;
              if (payloadStr != null) {
                try {
                  return Map<String, dynamic>.from(jsonDecode(payloadStr));
                } catch (_) {}
              }
              return null;
            })
            .whereType<Map<String, dynamic>>()
            .toList();

        final pendingDeletes = pendingQueue
            .where((item) => item['action_type'] == 'DELETE')
            .map((item) {
              final recordId = item['record_id'] as String;
              final parts = recordId.split('_');
              if (parts.length >= 2) {
                return {'task_id': parts[0], 'completed_date': parts[1]};
              }
              return null;
            })
            .whereType<Map<String, dynamic>>()
            .toList();

        // Clear local completions and rewrite them to match remote exactly
        await txn.delete('local_task_completions');
        
        // Write remote completions
        for (final row in remoteCompletions) {
          final map = Map<String, dynamic>.from(row);
          // Don't insert remote completions that have a pending delete locally
          final isPendingDelete = pendingDeletes.any((d) =>
              d['task_id'] == map['task_id'] && d['completed_date'] == map['completed_date']);
          if (!isPendingDelete) {
            await txn.insert('local_task_completions', map, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        // Restore pending inserts
        for (final completion in pendingInserts) {
          await txn.insert('local_task_completions', completion, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    } catch (e) {
      print("Sync task completions error: $e");
    }

    // A.2 Sync Task Exceptions (Full Mirroring to handle deletes)
    try {
      print("[LOAD] Method: _downloadRemoteUpdates -> task_exceptions, Reason: Sync mirror, Source: Supabase remote");
      final List<dynamic> remoteExceptions = await _supabase
          .from('task_exceptions')
          .select()
          .eq('user_id', userId);
      print("[SUPABASE] GET /task_exceptions. Received count: ${remoteExceptions.length}");

      await db.transaction((txn) async {
        final List<Map<String, dynamic>> pendingQueue = await txn.query(
          'offline_sync_queue',
          where: 'table_name = ?',
          whereArgs: ['task_exceptions'],
        );

        final pendingInserts = pendingQueue
            .where((item) => item['action_type'] == 'INSERT')
            .map((item) {
              final payloadStr = item['payload'] as String?;
              if (payloadStr != null) {
                try {
                  return Map<String, dynamic>.from(jsonDecode(payloadStr));
                } catch (_) {}
              }
              return null;
            })
            .whereType<Map<String, dynamic>>()
            .toList();

        final pendingDeletes = pendingQueue
            .where((item) => item['action_type'] == 'DELETE')
            .map((item) {
              final recordId = item['record_id'] as String;
              final parts = recordId.split('_');
              if (parts.length >= 2) {
                return {'task_id': parts[0], 'exception_date': parts[1]};
              }
              return null;
            })
            .whereType<Map<String, dynamic>>()
            .toList();

        // Clear local exceptions and rewrite them to match remote exactly
        await txn.delete('local_task_exceptions');
        
        // Write remote exceptions
        for (final row in remoteExceptions) {
          final map = Map<String, dynamic>.from(row);
          if (map['is_deleted'] is bool) {
            map['is_deleted'] = (map['is_deleted'] as bool) ? 1 : 0;
          }
          final isPendingDelete = pendingDeletes.any((d) =>
              d['task_id'] == map['task_id'] && d['exception_date'] == map['exception_date']);
          if (!isPendingDelete) {
            await txn.insert('local_task_exceptions', map, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        // Restore pending inserts
        for (final exception in pendingInserts) {
          await txn.insert('local_task_exceptions', exception, conflictAlgorithm: ConflictAlgorithm.replace);
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
