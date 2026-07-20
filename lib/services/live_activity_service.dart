import 'dart:io';
import 'package:live_activities/live_activities.dart';

class LiveActivityService {
  static final LiveActivityService _instance = LiveActivityService._internal();
  factory LiveActivityService() => _instance;
  LiveActivityService._internal();

  final LiveActivities _liveActivities = LiveActivities();
  String? _currentActivityId;

  Future<void> init() async {
    if (!Platform.isIOS) return;
    try {
      await _liveActivities.init(
        appGroupId: 'group.com.godsplan.app', // To share data between App and Widget Extension
      );
      print("Live Activities initialized successfully on iOS.");
    } catch (e) {
      print("Failed to initialize Live Activities: \$e");
    }
  }

  /// Start a new Live Activity for a Focus Task
  Future<void> startFocusSession({
    required String taskName,
    required int totalSeconds,
  }) async {
    if (!Platform.isIOS) return;
    
    // Check if device supports Live Activities (iOS 16.1+)
    final areEnabled = await _liveActivities.areActivitiesEnabled();
    if (!areEnabled) return;

    try {
      final endTime = DateTime.now().add(Duration(seconds: totalSeconds)).millisecondsSinceEpoch;
      
      _currentActivityId = await _liveActivities.createActivity(
        {
          'taskName': taskName,
          'totalSeconds': totalSeconds,
          'endTime': endTime,
          'status': 'Focusing...',
          'progress': 0.0,
        },
      );
      print("Started Live Activity ID: \$_currentActivityId");
    } catch (e) {
      print("Error starting Live Activity: \$e");
    }
  }

  /// Push an update to the Dynamic Island (e.g. paused state or time extension)
  Future<void> updateFocusSession({
    required String status,
    required double progress,
    int? newEndTime,
  }) async {
    if (!Platform.isIOS || _currentActivityId == null) return;

    try {
      final Map<String, dynamic> updateData = {
        'status': status,
        'progress': progress,
      };
      
      if (newEndTime != null) {
        updateData['endTime'] = newEndTime;
      }

      await _liveActivities.updateActivity(
        _currentActivityId!,
        updateData,
      );
    } catch (e) {
      print("Error updating Live Activity: \$e");
    }
  }

  /// End the Live Activity and remove it from the Lock Screen
  Future<void> endFocusSession({bool completed = true}) async {
    if (!Platform.isIOS || _currentActivityId == null) return;

    try {
      await _liveActivities.endActivity(
        _currentActivityId!,
      );
      _currentActivityId = null;
    } catch (e) {
      print("Error ending Live Activity: \$e");
    }
  }

  /// Force end all active Live Activities (useful on app crash recovery)
  Future<void> endAllActivities() async {
    if (!Platform.isIOS) return;
    try {
      await _liveActivities.endAllActivities();
      _currentActivityId = null;
    } catch (e) {
      print("Error ending all Live Activities: \$e");
    }
  }
}
