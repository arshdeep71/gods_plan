import 'package:live_activities/live_activities.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

/// Single Active Live Activity Priority Manager
/// PRODUCT DESIGN DECISION: While iOS ActivityKit allows multiple Live Activities,
/// "God's Plan" intentionally limits active Live Activities to ONE at a time by design
/// to keep the Lock Screen and Dynamic Island experience clean, focused, and uncluttered.
class LiveActivityService {
  static final LiveActivityService _instance = LiveActivityService._internal();
  factory LiveActivityService() => _instance;
  LiveActivityService._internal();

  final _liveActivitiesPlugin = LiveActivities();
  String? _currentActivityId;
  String? _activeTaskId;
  DateTime? _activeDeadline;

  bool get _isSupported => !kIsWeb && Platform.isIOS;

  Future<void> init() async {
    if (!_isSupported) return;
    try {
      debugPrint("[LIVE_ACTIVITY] Initializing ActivityKit plugin...");
      await _liveActivitiesPlugin.init(
        appGroupId: 'group.com.godsplan.app', // Update with actual App Group ID in Xcode
      );
      debugPrint("[LIVE_ACTIVITY] ActivityKit plugin initialized successfully.");
    } catch (e, st) {
      debugPrint("[LIVE_ACTIVITY_ERROR] Failed to initialize ActivityKit: $e");
      debugPrintStack(stackTrace: st);
    }
  }

  /// Capability detection: checks if device & OS support Live Activities and if authorization is granted.
  Future<bool> checkCapability() async {
    if (!_isSupported) {
      debugPrint("[LIVE_ACTIVITY_CHECK] Skipped: Platform is not iOS or running on Web.");
      return false;
    }
    try {
      final enabled = await _liveActivitiesPlugin.areActivitiesEnabled();
      if (!enabled) {
        debugPrint("[LIVE_ACTIVITY_CHECK] Disabled: User has disabled Live Activities in iOS Settings.");
        return false;
      }
      return true;
    } catch (e) {
      debugPrint("[LIVE_ACTIVITY_CHECK_ERROR] Capability check failed: $e. Falling back to standard notifications.");
      return false;
    }
  }

  /// Determine deterministic header status based on remaining time
  String _getHeaderStatus(int remainingMinutes) {
    if (remainingMinutes > 5) return "Starts in";
    if (remainingMinutes > 1) return "🔥 Almost Time";
    if (remainingMinutes > 0) return "🚨 Starts in 1 Minute";
    if (remainingMinutes == 0) return "🎯 It's Time";
    return "⏳ Missed";
  }

  /// Starts or updates single Live Activity for the highest priority (earliest) task.
  Future<void> startTaskActivity({
    required String taskId,
    required String taskTitle,
    required DateTime deadline,
    int? streakDays,
    int? completedTasks,
    int? totalTasks,
    int? xpAmount,
  }) async {
    debugPrint("[LIVE_ACTIVITY] Requested for task '$taskTitle' ($taskId) at $deadline");

    final capable = await checkCapability();
    if (!capable) return;

    // Single Activity Priority Manager:
    // If an activity is already active, check if the new task is earlier/more urgent.
    if (_currentActivityId != null && _activeDeadline != null) {
      if (_activeTaskId == taskId) {
        // Same task: update state if deadline unchanged
        await updateTaskActivityState(taskId: taskId, taskTitle: taskTitle, deadline: deadline);
        return;
      }

      if (deadline.isAfter(_activeDeadline!)) {
        debugPrint("[LIVE_ACTIVITY] Priority check: Active task '$_activeTaskId' is more urgent than '$taskId'. Keeping active activity.");
        return;
      }

      debugPrint("[LIVE_ACTIVITY] Priority check: New task '$taskId' ($deadline) is more urgent than active task '$_activeTaskId' ($_activeDeadline). Replacing Live Activity.");
      await endTaskActivity();
    }

    final now = DateTime.now();
    final remainingMinutes = deadline.difference(now).inMinutes;
    final headerStatus = _getHeaderStatus(remainingMinutes);

    final streakText = streakDays != null && streakDays > 0 ? "🔥 Streak: $streakDays days" : "";
    final tasksText = (completedTasks != null && totalTasks != null)
        ? "📅 Today: $completedTasks/$totalTasks completed"
        : (xpAmount != null && xpAmount > 0 ? "🎯 XP today: $xpAmount" : "");

    final subtitleText = [streakText, tasksText].where((s) => s.isNotEmpty).join(" • ");

    // Payload keys for Swift SwiftUI Widget Extension
    final activityData = {
      'v': 'v1',
      'taskId': taskId,
      'taskTitle': taskTitle,
      'deadline': deadline.toUtc().toIso8601String(), // ActivityKit Native Timer Source
      'headerStatus': headerStatus,
      'progress': 0.0,
      'streakDays': streakDays ?? 0,
      'completedRatio': (completedTasks != null && totalTasks != null) ? "$completedTasks/$totalTasks Tasks" : "",
      'xpAmount': xpAmount ?? 0,
      'subtitle': subtitleText.isNotEmpty ? subtitleText : "Stay ready 💪",
      'footerText': streakText.isNotEmpty ? streakText : "Today's Target",
    };

    try {
      _currentActivityId = await _liveActivitiesPlugin.createActivity(activityData);
      _activeTaskId = taskId;
      _activeDeadline = deadline;
      debugPrint("==================================");
      debugPrint("[LIVE_ACTIVITY] SUCCESS");
      debugPrint("Activity ID: $_currentActivityId");
      debugPrint("Task ID: $taskId");
      debugPrint("Header Status: $headerStatus");
      debugPrint("Deadline (Native Timer): ${deadline.toIso8601String()}");
      debugPrint("==================================");
    } catch (e, st) {
      debugPrint("[LIVE_ACTIVITY_ERROR] Failed Activity.request() for task '$taskTitle': $e");
      debugPrintStack(stackTrace: st);
    }
  }

  /// Updates Live Activity state ONLY at discrete state transitions (minimizing battery usage)
  Future<void> updateTaskActivityState({
    required String taskId,
    required String taskTitle,
    required DateTime deadline,
    String? customHeaderStatus,
  }) async {
    if (!_isSupported || _currentActivityId == null || _activeTaskId != taskId) return;
    try {
      final remainingMinutes = deadline.difference(DateTime.now()).inMinutes;
      final headerStatus = customHeaderStatus ?? _getHeaderStatus(remainingMinutes);

      final updateData = {
        'headerStatus': headerStatus,
        'taskTitle': taskTitle,
        'deadline': deadline.toUtc().toIso8601String(),
      };
      await _liveActivitiesPlugin.updateActivity(_currentActivityId!, updateData);
      debugPrint("[LIVE_ACTIVITY] Updated state for task '$taskId' -> Header: '$headerStatus'");
    } catch (e) {
      debugPrint("[LIVE_ACTIVITY_ERROR] Failed to update Live Activity: $e");
    }
  }

  /// Support focus session progress updates
  Future<void> updateTaskActivity(double progress) async {
    if (!_isSupported || _currentActivityId == null) return;
    try {
      final updateData = {
        'progress': progress,
      };
      await _liveActivitiesPlugin.updateActivity(_currentActivityId!, updateData);
      debugPrint("[LIVE_ACTIVITY] Updated focus progress value: $progress");
    } catch (e) {
      debugPrint("[LIVE_ACTIVITY_ERROR] Failed to update progress value: $e");
    }
  }

  /// Immediately ends active Live Activity upon task completion, deletion, or pause
  Future<void> endTaskActivity() async {
    if (!_isSupported || _currentActivityId == null) return;
    try {
      final endingId = _currentActivityId;
      await _liveActivitiesPlugin.endActivity(endingId!);
      debugPrint("[LIVE_ACTIVITY] Ended activity ID: $endingId for task '$_activeTaskId'");
      _currentActivityId = null;
      _activeTaskId = null;
      _activeDeadline = null;
    } catch (e) {
      debugPrint("[LIVE_ACTIVITY_ERROR] Failed to end Live Activity: $e");
    }
  }

  /// Clears all orphaned Live Activities on app launch, logout, or reinstall
  Future<void> endAllActivities() async {
    if (!_isSupported) return;
    try {
      await _liveActivitiesPlugin.endAllActivities();
      _currentActivityId = null;
      _activeTaskId = null;
      _activeDeadline = null;
      debugPrint("[LIVE_ACTIVITY] All orphaned Live Activities ended successfully.");
    } catch (e) {
      debugPrint("[LIVE_ACTIVITY_ERROR] Failed to end all Live Activities: $e");
    }
  }
}
