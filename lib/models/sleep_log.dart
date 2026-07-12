class SleepLog {
  final String id;
  final String userId;
  final DateTime sleepTime;
  final DateTime wakeTime;
  final double reportedQuality; // 1-10
  final bool caffeineAfter3PM;
  final bool screenTimeInBed;
  final bool lateDinner;
  final double calculatedQuality; // 1-10 after multipliers
  final DateTime loggedAt;
  final DateTime updatedAt;

  SleepLog({
    required this.id,
    required this.userId,
    required this.sleepTime,
    required this.wakeTime,
    required this.reportedQuality,
    required this.caffeineAfter3PM,
    required this.screenTimeInBed,
    required this.lateDinner,
    required this.calculatedQuality,
    required this.loggedAt,
    required this.updatedAt,
  });

  // Calculate duration in hours
  double get durationHours => wakeTime.difference(sleepTime).inMinutes / 60.0;

  // Calculate adjusted quality score
  static double calculateSleepQuality({
    required double reportedQuality,
    required bool caffeineAfter3PM,
    required bool screenTimeInBed,
    required bool lateDinner,
    required bool exercisedToday,
  }) {
    double score = reportedQuality;
    if (caffeineAfter3PM) score -= 1.5;
    if (screenTimeInBed) score -= 1.0;
    if (lateDinner) score -= 0.5;
    if (exercisedToday) score += 0.5;
    return score.clamp(1.0, 10.0);
  }

  // Convert to Map for Supabase / JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'sleep_time': sleepTime.toUtc().toIso8601String(),
      'wake_time': wakeTime.toUtc().toIso8601String(),
      'reported_quality': reportedQuality,
      'caffeine_after_3pm': caffeineAfter3PM,
      'screen_time_in_bed': screenTimeInBed,
      'late_dinner': lateDinner,
      'calculated_quality': calculatedQuality,
      'logged_at': loggedAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  // Convert to Map for Local SQLite DB
  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'user_id': userId,
      'sleep_time': sleepTime.toUtc().toIso8601String(),
      'wake_time': wakeTime.toUtc().toIso8601String(),
      'reported_quality': reportedQuality,
      'caffeine_after_3pm': caffeineAfter3PM ? 1 : 0,
      'screen_time_in_bed': screenTimeInBed ? 1 : 0,
      'late_dinner': lateDinner ? 1 : 0,
      'calculated_quality': calculatedQuality,
      'logged_at': loggedAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  // Create from JSON / Supabase map
  factory SleepLog.fromJson(Map<String, dynamic> json) {
    return SleepLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sleepTime: DateTime.parse(json['sleep_time'] as String),
      wakeTime: DateTime.parse(json['wake_time'] as String),
      reportedQuality: (json['reported_quality'] as num).toDouble(),
      caffeineAfter3PM: json['caffeine_after_3pm'] as bool,
      screenTimeInBed: json['screen_time_in_bed'] as bool,
      lateDinner: json['late_dinner'] as bool,
      calculatedQuality: (json['calculated_quality'] as num).toDouble(),
      loggedAt: DateTime.parse(json['logged_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // Create from SQLite Map
  factory SleepLog.fromSqliteMap(Map<String, dynamic> map) {
    return SleepLog(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      sleepTime: DateTime.parse(map['sleep_time'] as String),
      wakeTime: DateTime.parse(map['wake_time'] as String),
      reportedQuality: (map['reported_quality'] as num).toDouble(),
      caffeineAfter3PM: (map['caffeine_after_3pm'] as int) == 1,
      screenTimeInBed: (map['screen_time_in_bed'] as int) == 1,
      lateDinner: (map['late_dinner'] as int) == 1,
      calculatedQuality: (map['calculated_quality'] as num).toDouble(),
      loggedAt: DateTime.parse(map['logged_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
