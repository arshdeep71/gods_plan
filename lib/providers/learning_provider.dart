import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/learning.dart';
import '../models/sync_item.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class LearningProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final SyncService _syncService = SyncService();
  final Uuid _uuid = const Uuid();

  List<LearningSubject> _subjects = [];
  List<StudyLog> _studyLogs = [];
  bool _isLoading = false;

  List<LearningSubject> get subjects => _subjects;
  List<StudyLog> get studyLogs => _studyLogs;
  bool get isLoading => _isLoading;

  // Fetch from SQLite cache and initiate background cloud synchronization
  Future<void> fetchLearningData(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _subjects = await _dbService.getLocalLearningSubjects(userId);
      _studyLogs = await _dbService.getLocalStudyLogs(userId);
    } catch (e) {
      print("Error fetching learning data: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // Background sync
    try {
      await _syncService.sync(userId);
      _subjects = await _dbService.getLocalLearningSubjects(userId);
      _studyLogs = await _dbService.getLocalStudyLogs(userId);
      notifyListeners();
    } catch (_) {}
  }

  // Create academic subject
  Future<void> addSubject(String userId, String name, int dailyTargetMinutes, int totalTargetHours) async {
    final now = DateTime.now();
    final subject = LearningSubject(
      id: _uuid.v4(),
      userId: userId,
      name: name,
      dailyTargetMinutes: dailyTargetMinutes,
      totalTargetHours: totalTargetHours,
      loggedAt: now,
      updatedAt: now,
    );

    // Save locally
    await _dbService.upsertLocalLearningSubject(subject);
    _subjects.insert(0, subject);
    notifyListeners();

    // Queue sync mutation
    final syncItem = SyncItem(
      actionType: 'INSERT',
      tableName: 'learning_subjects',
      recordId: subject.id,
      payload: subject.toJson(),
    );
    await _dbService.queueSyncItem(syncItem);

    // Trigger sync
    _syncService.sync(userId).then((_) => fetchLearningData(userId));
  }

  // Log study session
  Future<void> addStudyLog(String userId, String subjectId, int durationMinutes) async {
    final now = DateTime.now();
    final log = StudyLog(
      id: _uuid.v4(),
      userId: userId,
      subjectId: subjectId,
      durationMinutes: durationMinutes,
      loggedAt: now,
      updatedAt: now,
    );

    // Save locally
    await _dbService.upsertLocalStudyLog(log);
    _studyLogs.insert(0, log);
    notifyListeners();

    // Queue sync mutation
    final syncItem = SyncItem(
      actionType: 'INSERT',
      tableName: 'study_logs',
      recordId: log.id,
      payload: log.toJson(),
    );
    await _dbService.queueSyncItem(syncItem);

    // Trigger sync
    _syncService.sync(userId).then((_) => fetchLearningData(userId));
  }

  // Helper: Today's logged minutes for a subject
  int getMinutesLoggedToday(String subjectId) {
    final today = DateTime.now();
    return _studyLogs
        .where((log) =>
            log.subjectId == subjectId &&
            log.loggedAt.year == today.year &&
            log.loggedAt.month == today.month &&
            log.loggedAt.day == today.day)
        .fold(0, (sum, log) => sum + log.durationMinutes);
  }

  // Helper: Total study hours logged for a subject
  double getTotalHoursLogged(String subjectId) {
    final totalMinutes = _studyLogs
        .where((log) => log.subjectId == subjectId)
        .fold(0, (sum, log) => sum + log.durationMinutes);
    return totalMinutes / 60.0;
  }

  // Helper: Current streak in consecutive days studied (any subject or specific)
  int getStudyStreak(String subjectId) {
    final subjectLogs = _studyLogs.where((log) => log.subjectId == subjectId).toList();
    if (subjectLogs.isEmpty) return 0;

    // Sort by date descending
    subjectLogs.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

    final Set<String> uniqueStudyDays = {};
    for (final log in subjectLogs) {
      final dateStr = "${log.loggedAt.year}-${log.loggedAt.month}-${log.loggedAt.day}";
      uniqueStudyDays.add(dateStr);
    }

    final sortedDays = uniqueStudyDays.map((d) => DateTime.parse(d)).toList();
    sortedDays.sort((a, b) => b.compareTo(a));

    int streak = 0;
    DateTime checkDate = DateTime.now();
    final todayStr = "${checkDate.year}-${checkDate.month}-${checkDate.day}";
    final yesterdayStr = "${checkDate.subtract(const Duration(days: 1)).year}-${checkDate.subtract(const Duration(days: 1)).month}-${checkDate.subtract(const Duration(days: 1)).day}";

    // If studied neither today nor yesterday, streak is broken/0
    if (!uniqueStudyDays.contains(todayStr) && !uniqueStudyDays.contains(yesterdayStr)) {
      return 0;
    }

    // Start check from the most recent study day
    if (!uniqueStudyDays.contains(todayStr)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    while (true) {
      final checkStr = "${checkDate.year}-${checkDate.month}-${checkDate.day}";
      if (uniqueStudyDays.contains(checkStr)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }
}
