import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/live_activity_state.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class LiveActivityService {
  static final LiveActivityService _instance = LiveActivityService._internal();
  factory LiveActivityService() => _instance;
  LiveActivityService._internal();

  final _liveActivitiesPlugin = LiveActivities();
  String? _currentActivityId;
  
  bool get _isSupported => !kIsWeb && Platform.isIOS;

  Future<void> init() async {
    if (!_isSupported) return;
    try {
      await _liveActivitiesPlugin.init(
        appGroupId: 'group.com.godsplan.app', // Update with your actual App Group ID
      );
    } catch (_) {}
  }

  Future<void> startTaskActivity(String taskTitle, DateTime deadline) async {
    if (!_isSupported) return;
    try {
      if (!await _liveActivitiesPlugin.areActivitiesEnabled()) return;

      final activityData = {
        'taskTitle': taskTitle,
        'deadline': deadline.toUtc().toIso8601String(),
        'progress': 0.0,
      };

      _currentActivityId = await _liveActivitiesPlugin.createActivity(
        activityData,
      );
      print("Live Activity started: \$_currentActivityId");
    } catch (e) {
      print("Failed to start Live Activity: \$e");
    }
  }

  Future<void> updateTaskActivity(double progress) async {
    if (!_isSupported || _currentActivityId == null) return;
    try {
      final updateData = {
        'progress': progress,
      };
      await _liveActivitiesPlugin.updateActivity(_currentActivityId!, updateData);
    } catch (e) {
      print("Failed to update Live Activity: \$e");
    }
  }

  Future<void> endTaskActivity() async {
    if (!_isSupported || _currentActivityId == null) return;
    try {
      await _liveActivitiesPlugin.endActivity(_currentActivityId!);
      _currentActivityId = null;
    } catch (e) {
      print("Failed to end Live Activity: \$e");
    }
  }

  Future<void> endAllActivities() async {
    if (!_isSupported) return;
    try {
      await _liveActivitiesPlugin.endAllActivities();
      _currentActivityId = null;
    } catch (e) {
      print("Failed to end all Live Activities: \$e");
    }
  }
}
