import 'package:live_activities/live_activities.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  static const MethodChannel _nativeChannel = MethodChannel("com.godsplan.app/live_activity");

  String? _currentActivityId;
  String? _activeTaskId;
  DateTime? _activeDeadline;

  bool get _isSupported => !kIsWeb && Platform.isIOS;

  Future<void> init() async {
    if (!_isSupported) return;
    try {
      debugPrint("[LIVE_ACTIVITY] Initializing ActivityKit plugin...");
      await _liveActivitiesPlugin.init(
        appGroupId: 'group.com.godsplan.app',
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
      debugPrint("[LIVE_ACTIVITY_CHECK_ERROR] Capability check failed: $e. Falling back to native channel.");
      return true; // Attempt native platform channel even if plugin check fails
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
    String? occurrenceId,
    int? streakDays,
    int? completedTasks,
    int? totalTasks,
    int? xpAmount,
  }) async {
    final effectiveOccurrenceId = occurrenceId ?? taskId;
    debugPrint("==================================");
    debugPrint("[LIVE_ACTIVITY] Activity Requested");
    debugPrint("Task Title: '$taskTitle'");
    debugPrint("Task ID: $taskId");
    debugPrint("Occurrence ID: $effectiveOccurrenceId");
    debugPrint("Deadline: ${deadline.toIso8601String()}");
    debugPrint("==================================");

    final capable = await checkCapability();
    if (!capable) return;

    // Single Activity Priority Manager:
    // If an activity is already active, check if the new task is earlier/more urgent.
    if (_currentActivityId != null && _activeDeadline != null) {
      if (_activeTaskId == taskId) {
        // Same task: update state
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

    // Payload keys matching Swift ActivityAttributes & SwiftUI Widget Extension
    final activityData = <String, dynamic>{
      'v': 'v1',
      'taskId': taskId,
      'occurrenceId': effectiveOccurrenceId,
      'taskTitle': taskTitle,
      'deadline': deadline.toUtc().toIso8601String(), // Native ActivityKit Countdown Source
      'headerStatus': headerStatus,
      'progress': 0.0,
      'streakDays': streakDays ?? 0,
      'completedRatio': (completedTasks != null && totalTasks != null) ? "$completedTasks/$totalTasks Tasks" : "",
      'xpAmount': xpAmount ?? 0,
      'subtitle': subtitleText.isNotEmpty ? subtitleText : "Stay ready 💪",
      'footerText': streakText.isNotEmpty ? streakText : "Today's Target",
    };

    try {
      // 1. Try Native Swift Platform Channel Bridge
      try {
        final Map<dynamic, dynamic>? nativeRes = await _nativeChannel.invokeMethod('startTaskActivity', activityData);
        if (nativeRes != null && nativeRes.containsKey('activityId')) {
          _currentActivityId = nativeRes['activityId'] as String;
          _activeTaskId = taskId;
          _activeDeadline = deadline;
          debugPrint("[LIVE_ACTIVITY] Activity Started (via Native Swift Bridge)");
          debugPrint("Activity ID: $_currentActivityId");
          return;
        }
      } catch (nativeErr) {
        debugPrint("[LIVE_ACTIVITY_BRIDGE_INFO] Native channel fallback to plugin: $nativeErr");
      }

      // 2. Fallback to live_activities plugin
      _currentActivityId = await _liveActivitiesPlugin.createActivity(activityData);
      _activeTaskId = taskId;
      _activeDeadline = deadline;

      debugPrint("[LIVE_ACTIVITY] Activity Started (via live_activities plugin)");
      debugPrint("Activity ID: $_currentActivityId");
      debugPrint("Header Status: $headerStatus");
      debugPrint("Deadline (Native Timer): ${deadline.toIso8601String()}");
    } catch (e, st) {
      debugPrint("[LIVE_ACTIVITY_ERROR] Exception in Activity.request() for task '$taskTitle': $e");
      debugPrintStack(stackTrace: st);
    }
  }

  /// Updates Live Activity state at discrete state transitions
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

      final updateData = <String, dynamic>{
        'taskId': taskId,
        'taskTitle': taskTitle,
        'headerStatus': headerStatus,
        'deadline': deadline.toUtc().toIso8601String(),
      };

      try {
        await _nativeChannel.invokeMethod('updateTaskActivity', updateData);
      } catch (_) {}

      await _liveActivitiesPlugin.updateActivity(_currentActivityId!, updateData);
      debugPrint("[LIVE_ACTIVITY] Activity Updated for task '$taskId' -> Header: '$headerStatus'");
    } catch (e) {
      debugPrint("[LIVE_ACTIVITY_ERROR] Failed to update Live Activity: $e");
    }
  }

  /// Focus session progress updates
  Future<void> updateTaskActivity(double progress) async {
    if (!_isSupported || _currentActivityId == null) return;
    try {
      final updateData = <String, dynamic>{
        'progress': progress,
      };

      try {
        await _nativeChannel.invokeMethod('updateTaskActivity', updateData);
      } catch (_) {}

      await _liveActivitiesPlugin.updateActivity(_currentActivityId!, updateData);
      debugPrint("[LIVE_ACTIVITY] Activity Updated focus progress: $progress");
    } catch (e) {
      debugPrint("[LIVE_ACTIVITY_ERROR] Failed to update progress: $e");
    }
  }

  /// Ends active Live Activity upon completion, deletion, or pause
  Future<void> endTaskActivity() async {
    if (!_isSupported || _currentActivityId == null) return;
    try {
      final endingId = _currentActivityId;
      try {
        await _nativeChannel.invokeMethod('endTaskActivity');
      } catch (_) {}

      await _liveActivitiesPlugin.endActivity(endingId!);
      debugPrint("[LIVE_ACTIVITY] Activity Ended | Activity ID: $endingId for task '$_activeTaskId'");
      _currentActivityId = null;
      _activeTaskId = null;
      _activeDeadline = null;
    } catch (e) {
      debugPrint("[LIVE_ACTIVITY_ERROR] Failed to end Live Activity: $e");
    }
  }

  /// Restores active Live Activity state on app launch if eligible
  Future<void> restoreTaskActivity() async {
    if (!_isSupported) return;
    try {
      try {
        final Map<dynamic, dynamic>? res = await _nativeChannel.invokeMethod('restoreTaskActivity');
        if (res != null && res['status'] == 'restored') {
          _currentActivityId = res['activityId'] as String?;
          _activeTaskId = res['taskId'] as String?;
          debugPrint("[LIVE_ACTIVITY] Restored active activity ID: $_currentActivityId for task: $_activeTaskId");
          return;
        }
      } catch (_) {}

      final activities = await _liveActivitiesPlugin.getAllActivities();
      if (activities.isNotEmpty) {
        _currentActivityId = activities.first;
        debugPrint("[LIVE_ACTIVITY] Restored active activity ID: $_currentActivityId via plugin.");
      }
    } catch (e) {
      debugPrint("[LIVE_ACTIVITY_ERROR] Failed to restore Live Activity: $e");
    }
  }

  /// Clears all orphaned Live Activities on app launch, logout, or reinstall
  Future<void> endAllActivities() async {
    if (!_isSupported) return;
    try {
      try {
        await _nativeChannel.invokeMethod('endAllActivities');
      } catch (_) {}

      await _liveActivitiesPlugin.endAllActivities();
      _currentActivityId = null;
      _activeTaskId = null;
      _activeDeadline = null;
      debugPrint("[LIVE_ACTIVITY] Ended all active activities successfully.");
    } catch (e) {
      debugPrint("[LIVE_ACTIVITY_ERROR] Failed to end all Live Activities: $e");
    }
  }
}
