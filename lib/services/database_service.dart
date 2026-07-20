import 'package:hive_flutter/hive_flutter.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'sqlite_factory.dart';
import 'package:path/path.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';
import '../models/sync_item.dart';
import '../models/workout.dart';
import '../models/sleep_log.dart';
import '../models/food_log.dart';
import '../models/water_log.dart';
import '../models/addiction_log.dart';
import '../models/finance_transaction.dart';
import '../models/social.dart';
import '../models/learning.dart';

class DatabaseService {
  static const String settingsBoxName = 'settings_box';
  static Database? _database;

  // Initialize Hive and SQLite databases
  Future<void> initDatabase() async {
    await Hive.initFlutter();
    await Hive.openBox(settingsBoxName);
    await _initSqlite();
  }

  // Get settings box instance
  Box get settingsBox => Hive.box(settingsBoxName);

  String? get currentUserId => _currentUserId;

  String? get _currentUserId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  // Settings getters and setters
  bool get isOnboarded {
    final uid = _currentUserId;
    if (uid == null) return false;
    return settingsBox.get('is_onboarded_$uid', defaultValue: false);
  }

  Future<void> setOnboarded(bool value) async {
    final uid = _currentUserId;
    if (uid == null) return;
    await settingsBox.put('is_onboarded_$uid', value);
  }

  // Get cached goal timeline parameters
  Map<String, String>? getLocalGoalDates() {
    final uid = _currentUserId;
    if (uid == null) return null;
    final start = settingsBox.get('goal_start_date_$uid');
    final end = settingsBox.get('goal_end_date_$uid');
    if (start != null && end != null) {
      return {'start_date': start, 'end_date': end};
    }
    return null;
  }

  // Set cached goal dates
  Future<void> setLocalGoalDates(String startDate, String endDate) async {
    final uid = _currentUserId;
    if (uid == null) return;
    await settingsBox.put('goal_start_date_$uid', startDate);
    await settingsBox.put('goal_end_date_$uid', endDate);
  }

  // SQLite Initialization
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initSqlite();
    return _database!;
  }

  Future<Database> _initSqlite() async {
    final dbPath = await getSqliteDatabasesPath();
    final pathString = join(dbPath, 'gods_plan.db');
    
    final db = await openSqliteDatabase(
      pathString,
      version: 1,
      onCreate: (db, version) async {
        await _createTables(db);
      },
    );

    // Apply incremental migrations for tasks table by checking existing columns first.
    // NOTE: We do NOT call _createTables() again here — doing so caused concurrent
    // sqlite3_exec/sqlite3_step calls in the sqflite WASM worker on web, producing
    // the "Uncaught Error" in sqflite_sw.js. The onCreate callback handles creation
    // for fresh databases, and CREATE TABLE IF NOT EXISTS is idempotent for existing ones.
    try {
      // Only run migration if local_tasks already exists (onCreate may have just built it)
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='local_tasks'",
      );
      if (tables.isNotEmpty) {
        final columns = await db.rawQuery('PRAGMA table_info(local_tasks)');
        final columnNames = columns.map((c) => c['name']?.toString().toLowerCase()).toList();

        Future<void> addColumnIfMissing(String name, String definition) async {
          if (!columnNames.contains(name.toLowerCase())) {
            try {
              await db.execute("ALTER TABLE local_tasks ADD COLUMN $name $definition");
            } catch (_) {}
          }
        }

        await addColumnIfMissing('is_paused', 'INTEGER DEFAULT 0');
        await addColumnIfMissing('due_time', 'TEXT');
        await addColumnIfMissing('scheduled_date', 'TEXT');
        await addColumnIfMissing('last_completed_date', 'TEXT');
        await addColumnIfMissing('repeat_type', "TEXT DEFAULT 'daily'");
        await addColumnIfMissing('reminder_time', 'TEXT');
        await addColumnIfMissing('order_index', 'INTEGER DEFAULT 0');
        await addColumnIfMissing('start_date', 'TEXT');
        await addColumnIfMissing('deleted_at', 'TEXT');

        // Migrate other tables for Soft Deletes (Phase 1)
        final otherTables = [
            'local_task_completions', 'local_task_exceptions', 'local_workouts', 
            'local_sleep_logs', 'local_food_logs', 'local_water_logs', 
            'local_addiction_logs', 'local_finance_transactions', 
            'local_social_contacts', 'local_learning_subjects', 'local_study_logs'
        ];
        
        for (final t in otherTables) {
            final tCheck = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='$t'");
            if (tCheck.isNotEmpty) {
                final tCols = await db.rawQuery('PRAGMA table_info($t)');
                final tColNames = tCols.map((c) => c['name']?.toString().toLowerCase()).toList();
                if (!tColNames.contains('deleted_at')) {
                    try { await db.execute("ALTER TABLE $t ADD COLUMN deleted_at TEXT"); } catch (_) {}
                }
            }
        }

        // Migrate existing recurring tasks with NULL start_date to their creation date prefix (YYYY-MM-DD)
        try {
          await db.execute(
            "UPDATE local_tasks SET start_date = substr(created_at, 1, 10) WHERE is_recurring = 1 AND start_date IS NULL"
          );
        } catch (_) {}
      }
    } catch (_) {}

    return db;
  }

  // Dynamically create all tables if they do not exist
  Future<void> _createTables(Database db) async {
    // Phase 1 New Tables: Preferences, Devices, Categories, Goals, Reminders
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_preferences (
        user_id TEXT PRIMARY KEY,
        theme_mode TEXT DEFAULT 'system',
        accent_color TEXT DEFAULT 'blue',
        global_sound_enabled INTEGER DEFAULT 1,
        global_haptic_intensity TEXT DEFAULT 'medium',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS devices (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        fcm_token TEXT,
        platform TEXT NOT NULL,
        device_name TEXT,
        last_active_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        color TEXT,
        icon TEXT,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS goals (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        target_date TEXT,
        category_id TEXT,
        progress INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS reminders (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        task_id TEXT NOT NULL,
        scheduled_time TEXT NOT NULL,
        recurrence_rule TEXT,
        status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // Create local tasks table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_tasks (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        is_completed INTEGER NOT NULL,
        is_recurring INTEGER NOT NULL,
        repeat_type TEXT NOT NULL,
        reminder_time TEXT,
        order_index INTEGER DEFAULT 0,
        streak_count INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_paused INTEGER DEFAULT 0,
        due_time TEXT,
        scheduled_date TEXT,
        last_completed_date TEXT,
        start_date TEXT,
        deleted_at TEXT
      )
    ''');

    // Create local task completions table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_task_completions (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        completed_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // Create local task exceptions table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_task_exceptions (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        exception_date TEXT NOT NULL,
        is_deleted INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // Create local workouts table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_workouts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        activity_type TEXT NOT NULL,
        duration INTEGER NOT NULL,
        weight_kg REAL NOT NULL,
        calories_burned REAL NOT NULL,
        logged_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // Create local sleep logs table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_sleep_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        sleep_time TEXT NOT NULL,
        wake_time TEXT NOT NULL,
        reported_quality REAL NOT NULL,
        caffeine_after_3pm INTEGER NOT NULL,
        screen_time_in_bed INTEGER NOT NULL,
        late_dinner INTEGER NOT NULL,
        calculated_quality REAL NOT NULL,
        logged_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // Create local food logs table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_food_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        food_name TEXT NOT NULL,
        calories REAL NOT NULL,
        protein REAL NOT NULL,
        carbs REAL NOT NULL,
        fats REAL NOT NULL,
        logged_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // Create local water logs table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_water_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        glasses INTEGER NOT NULL,
        logged_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // Create local addiction logs table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_addiction_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        feeling TEXT NOT NULL,
        urge_level INTEGER NOT NULL,
        trigger_tag TEXT NOT NULL,
        helper_strategy TEXT NOT NULL,
        is_relapse INTEGER NOT NULL,
        notes TEXT,
        logged_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // Create local finance transactions table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_finance_transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        notes TEXT,
        logged_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // Create local social contacts table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_social_contacts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        last_contacted TEXT NOT NULL,
        notes TEXT,
        logged_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // Create local learning subjects table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_learning_subjects (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        daily_target_minutes INTEGER NOT NULL,
        total_target_hours INTEGER NOT NULL,
        logged_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // Create local study logs table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_study_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        subject_id TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL,
        logged_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    // Create offline sync queue table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        payload TEXT,
        retry_count INTEGER DEFAULT 0,
        next_retry_at TEXT
      )
    ''');
  }

  // ==========================================
  // LOCAL TASKS DATABASE CRUD OPERATIONS
  // ==========================================

  Future<List<Task>> getLocalTasks(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_tasks',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Task.fromSqliteMap(maps[i]));
  }

  Future<void> upsertLocalTask(Task task) async {
    final db = await database;
    await db.insert(
      'local_tasks',
      task.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteLocalTask(String taskId) async {
    final db = await database;
    await db.delete(
      'local_tasks',
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  // ==========================================
  // LOCAL TASK COMPLETIONS CRUD
  // ==========================================

  Future<List<Map<String, dynamic>>> getLocalTaskCompletions(String userId) async {
    final db = await database;
    return await db.query(
      'local_task_completions',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> upsertLocalTaskCompletion(Map<String, dynamic> completion) async {
    final db = await database;
    await db.insert(
      'local_task_completions',
      completion,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteLocalTaskCompletion(String taskId, String date) async {
    final db = await database;
    await db.delete(
      'local_task_completions',
      where: 'task_id = ? AND completed_date = ?',
      whereArgs: [taskId, date],
    );
  }

  // ==========================================
  // LOCAL TASK EXCEPTIONS CRUD
  // ==========================================

  Future<List<Map<String, dynamic>>> getLocalTaskExceptions(String userId) async {
    final db = await database;
    return await db.query(
      'local_task_exceptions',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> upsertLocalTaskException(Map<String, dynamic> exception) async {
    final db = await database;
    await db.insert(
      'local_task_exceptions',
      exception,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ==========================================
  // LOCAL WORKOUTS DATABASE CRUD OPERATIONS
  // ==========================================

  Future<List<Workout>> getLocalWorkouts(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_workouts',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'logged_at DESC',
    );
    return List.generate(maps.length, (i) => Workout.fromSqliteMap(maps[i]));
  }

  Future<void> upsertLocalWorkout(Workout workout) async {
    final db = await database;
    await db.insert(
      'local_workouts',
      workout.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteLocalWorkout(String id) async {
    final db = await database;
    await db.delete(
      'local_workouts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // LOCAL SLEEP LOGS DATABASE CRUD OPERATIONS
  // ==========================================

  Future<List<SleepLog>> getLocalSleepLogs(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_sleep_logs',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'logged_at DESC',
    );
    return List.generate(maps.length, (i) => SleepLog.fromSqliteMap(maps[i]));
  }

  Future<void> upsertLocalSleepLog(SleepLog log) async {
    final db = await database;
    await db.insert(
      'local_sleep_logs',
      log.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteLocalSleepLog(String id) async {
    final db = await database;
    await db.delete(
      'local_sleep_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // LOCAL NUTRITION (FOOD LOGS) CRUD OPERATIONS
  // ==========================================

  Future<List<FoodLog>> getLocalFoodLogs(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_food_logs',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'logged_at DESC',
    );
    return List.generate(maps.length, (i) => FoodLog.fromSqliteMap(maps[i]));
  }

  Future<void> upsertLocalFoodLog(FoodLog log) async {
    final db = await database;
    await db.insert(
      'local_food_logs',
      log.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteLocalFoodLog(String id) async {
    final db = await database;
    await db.delete(
      'local_food_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // LOCAL WATER LOGS DATABASE CRUD OPERATIONS
  // ==========================================

  Future<List<WaterLog>> getLocalWaterLogs(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_water_logs',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'logged_at DESC',
    );
    return List.generate(maps.length, (i) => WaterLog.fromSqliteMap(maps[i]));
  }

  Future<void> upsertLocalWaterLog(WaterLog log) async {
    final db = await database;
    await db.insert(
      'local_water_logs',
      log.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteLocalWaterLog(String id) async {
    final db = await database;
    await db.delete(
      'local_water_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // OFFLINE MUTATIONS SYNC QUEUE OPERATIONS
  // ==========================================

  Future<List<SyncItem>> getSyncQueue() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'offline_sync_queue',
      orderBy: 'id ASC',
    );
    return List.generate(maps.length, (i) => SyncItem.fromSqliteMap(maps[i]));
  }

  Future<void> queueMutation(SyncItem item) async {
    final db = await database;
    await db.insert(
      'offline_sync_queue',
      item.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSyncItem(SyncItem item) async {
    final db = await database;
    await db.update(
      'offline_sync_queue',
      item.toSqliteMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> removeSyncItem(int id) async {
    final db = await database;
    await db.delete(
      'offline_sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearSyncQueue() async {
    final db = await database;
    await db.delete('offline_sync_queue');
  }

  // Clear all cached local data on logout
  // ==========================================
  // LOCAL ADDICTION LOGS CRUD OPERATIONS
  // ==========================================

  Future<List<AddictionLog>> getLocalAddictionLogs(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_addiction_logs',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'logged_at DESC',
    );
    return List.generate(maps.length, (i) => AddictionLog.fromSqliteMap(maps[i]));
  }

  Future<void> upsertLocalAddictionLog(AddictionLog log) async {
    final db = await database;
    await db.insert(
      'local_addiction_logs',
      log.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteLocalAddictionLog(String id) async {
    final db = await database;
    await db.delete(
      'local_addiction_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // LOCAL FINANCE TRANSACTIONS CRUD OPERATIONS
  // ==========================================

  Future<List<FinanceTransaction>> getLocalFinanceTransactions(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_finance_transactions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'logged_at DESC',
    );
    return List.generate(maps.length, (i) => FinanceTransaction.fromSqliteMap(maps[i]));
  }

  Future<void> upsertLocalFinanceTransaction(FinanceTransaction tx) async {
    final db = await database;
    await db.insert(
      'local_finance_transactions',
      tx.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteLocalFinanceTransaction(String id) async {
    final db = await database;
    await db.delete(
      'local_finance_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // LOCAL SOCIAL CONTACTS CRUD OPERATIONS
  // ==========================================

  Future<List<SocialContact>> getLocalSocialContacts(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_social_contacts',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => SocialContact.fromSqliteMap(maps[i]));
  }

  Future<void> upsertLocalSocialContact(SocialContact contact) async {
    final db = await database;
    await db.insert(
      'local_social_contacts',
      contact.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteLocalSocialContact(String id) async {
    final db = await database;
    await db.delete(
      'local_social_contacts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // LOCAL LEARNING SUBJECTS & STUDY LOGS CRUD OPERATIONS
  // ==========================================

  Future<List<LearningSubject>> getLocalLearningSubjects(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_learning_subjects',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => LearningSubject.fromSqliteMap(maps[i]));
  }

  Future<void> upsertLocalLearningSubject(LearningSubject subject) async {
    final db = await database;
    await db.insert(
      'local_learning_subjects',
      subject.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteLocalLearningSubject(String id) async {
    final db = await database;
    await db.delete(
      'local_learning_subjects',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<StudyLog>> getLocalStudyLogs(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_study_logs',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'logged_at DESC',
    );
    return List.generate(maps.length, (i) => StudyLog.fromSqliteMap(maps[i]));
  }

  Future<void> upsertLocalStudyLog(StudyLog log) async {
    final db = await database;
    await db.insert(
      'local_study_logs',
      log.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteLocalStudyLog(String id) async {
    final db = await database;
    await db.delete(
      'local_study_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearLocalCache() async {
    await settingsBox.clear();
    final db = await database;
    await db.delete('local_tasks');
    await db.delete('local_task_completions');
    await db.delete('local_task_exceptions');
    await db.delete('local_workouts');
    await db.delete('local_sleep_logs');
    await db.delete('local_food_logs');
    await db.delete('local_water_logs');
    await db.delete('local_addiction_logs');
    await db.delete('local_finance_transactions');
    await db.delete('local_social_contacts');
    await db.delete('local_learning_subjects');
    await db.delete('local_study_logs');
    await db.delete('offline_sync_queue');
  }

  Future<void> clearLocalCacheExceptPendingDeletion(String userId, bool isPendingDeletion) async {
    if (isPendingDeletion) {
      final keys = settingsBox.keys.toList();
      for (final key in keys) {
        if (key != 'pending_profile_deletion_$userId') {
          await settingsBox.delete(key);
        }
      }
    } else {
      await settingsBox.clear();
    }
    final db = await database;
    await db.delete('local_tasks');
    await db.delete('local_task_completions');
    await db.delete('local_task_exceptions');
    await db.delete('local_workouts');
    await db.delete('local_sleep_logs');
    await db.delete('local_food_logs');
    await db.delete('local_water_logs');
    await db.delete('local_addiction_logs');
    await db.delete('local_finance_transactions');
    await db.delete('local_social_contacts');
    await db.delete('local_learning_subjects');
    await db.delete('local_study_logs');
    await db.delete('offline_sync_queue');
  }

  /// Wipes all local SQLite tables and Hive settings. Equivalent to clearLocalCache().
  Future<void> wipeDatabase() => clearLocalCache();
}
