import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/addiction_log.dart';
import '../models/sync_item.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class AddictionProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final SyncService _syncService = SyncService();
  final Uuid _uuid = const Uuid();

  List<AddictionLog> _logs = [];
  bool _isLoading = false;
  int _currentStreak = 0;
  int _longestStreak = 0;

  List<AddictionLog> get logs => _logs;
  bool get isLoading => _isLoading;
  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;

  // Fetch addiction logs and calculate streaks
  Future<void> fetchAddictionLogs(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _logs = await _dbService.getLocalAddictionLogs(userId);
      _calculateStreaks(userId);
    } catch (e) {
      print("Error fetching addiction logs: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add a new urge/relapse log
  Future<void> logUrge({
    required String userId,
    required String feeling,
    required int urgeLevel,
    required String trigger,
    required String helperStrategy,
    required bool isRelapse,
    required String notes,
  }) async {
    final now = DateTime.now();
    final log = AddictionLog(
      id: _uuid.v4(),
      userId: userId,
      feeling: feeling,
      urgeLevel: urgeLevel,
      trigger: trigger,
      helperStrategy: helperStrategy,
      isRelapse: isRelapse,
      notes: notes,
      loggedAt: now,
      updatedAt: now,
    );

    // Write to local cache
    await _dbService.upsertLocalAddictionLog(log);

    // Queue mutation for offline sync
    final syncItem = SyncItem(
      actionType: 'INSERT',
      tableName: 'addiction_logs',
      recordId: log.id,
      payload: log.toJson(),
    );
    await _dbService.queueMutation(syncItem);

    // Refresh local lists & streaks
    _logs.insert(0, log);
    _calculateStreaks(userId);
    notifyListeners();

    // Trigger sync in background
    _syncService.sync(userId).then((_) {
      fetchAddictionLogs(userId);
    });
  }

  // Delete an addiction log
  Future<void> deleteAddictionLog(String userId, String logId) async {
    await _dbService.deleteLocalAddictionLog(logId);

    final syncItem = SyncItem(
      actionType: 'DELETE',
      tableName: 'addiction_logs',
      recordId: logId,
    );
    await _dbService.queueMutation(syncItem);

    _logs.removeWhere((l) => l.id == logId);
    _calculateStreaks(userId);
    notifyListeners();

    _syncService.sync(userId).then((_) {
      fetchAddictionLogs(userId);
    });
  }

  // Calculate streaks
  void _calculateStreaks(String userId) {
    if (_logs.isEmpty) {
      // Default to goal start date if available
      final dates = _dbService.getLocalGoalDates();
      if (dates != null && dates['start_date'] != null) {
        try {
          final startDate = DateTime.parse(dates['start_date']!);
          final diff = DateTime.now().difference(startDate).inDays;
          _currentStreak = diff >= 0 ? diff : 0;
        } catch (_) {
          _currentStreak = 0;
        }
      } else {
        _currentStreak = 0;
      }
      _longestStreak = _currentStreak;
      _dbService.settingsBox.put('longest_addiction_streak', _longestStreak);
      return;
    }

    // Sort logs by loggedAt descending
    final sortedLogs = List<AddictionLog>.from(_logs);
    sortedLogs.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

    // Find the most recent relapse log
    final lastRelapseIndex = sortedLogs.indexWhere((l) => l.isRelapse);

    DateTime cleanSince;
    if (lastRelapseIndex == -1) {
      // No relapse logged. Clean since goal start date or earliest log
      final dates = _dbService.getLocalGoalDates();
      if (dates != null && dates['start_date'] != null) {
        try {
          cleanSince = DateTime.parse(dates['start_date']!);
        } catch (_) {
          cleanSince = sortedLogs.last.loggedAt;
        }
      } else {
        cleanSince = sortedLogs.last.loggedAt;
      }
    } else {
      // Clean since last relapse
      cleanSince = sortedLogs[lastRelapseIndex].loggedAt;
    }

    final currentDiff = DateTime.now().difference(cleanSince).inDays;
    _currentStreak = currentDiff >= 0 ? currentDiff : 0;

    // Calculate longest streak from history
    // We sort ascending to walk through relapses
    final chronLogs = List<AddictionLog>.from(_logs);
    chronLogs.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));

    final dates = _dbService.getLocalGoalDates();
    DateTime lastAnchor = dates != null && dates['start_date'] != null
        ? (DateTime.tryParse(dates['start_date']!) ?? chronLogs.first.loggedAt)
        : chronLogs.first.loggedAt;

    int maxStreak = 0;

    for (final log in chronLogs) {
      if (log.isRelapse) {
        final diff = log.loggedAt.difference(lastAnchor).inDays;
        if (diff > maxStreak) maxStreak = diff;
        lastAnchor = log.loggedAt; // Reset anchor to the relapse date
      }
    }

    // Also check current streak from the last relapse to now
    final finalDiff = DateTime.now().difference(lastAnchor).inDays;
    if (finalDiff > maxStreak) maxStreak = finalDiff;

    // Cache and set longest streak
    final cachedLongest = _dbService.settingsBox.get('longest_addiction_streak', defaultValue: 0) as int;
    _longestStreak = maxStreak > cachedLongest ? maxStreak : cachedLongest;
    if (maxStreak > cachedLongest) {
      _dbService.settingsBox.put('longest_addiction_streak', maxStreak);
    }
  }
}
