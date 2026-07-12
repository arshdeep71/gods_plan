class Workout {
  final String id;
  final String userId;
  final String activityType; // 'running', 'strength', 'yoga', 'sports', 'walking'
  final int duration; // in minutes
  final double weightKg;
  final double caloriesBurned;
  final DateTime loggedAt;
  final DateTime updatedAt;

  Workout({
    required this.id,
    required this.userId,
    required this.activityType,
    required this.duration,
    required this.weightKg,
    required this.caloriesBurned,
    required this.loggedAt,
    required this.updatedAt,
  });

  // Calculate MET value based on activity type
  static double getMET(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'running':
        return 9.8;
      case 'strength':
        return 6.0;
      case 'yoga':
        return 2.5;
      case 'sports':
        return 8.0;
      case 'walking':
      default:
        return 3.5;
    }
  }

  // MET Calorie Burn formula: Duration * (MET * 3.5 * Weight) / 200
  static double calculateCalories(int duration, String activityType, double weightKg) {
    final met = getMET(activityType);
    return duration * (met * 3.5 * weightKg) / 200;
  }

  // Convert to Map for Supabase / JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'activity_type': activityType,
      'duration': duration,
      'weight_kg': weightKg,
      'calories_burned': caloriesBurned,
      'logged_at': loggedAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  // Convert to Map for Local SQLite DB
  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'user_id': userId,
      'activity_type': activityType,
      'duration': duration,
      'weight_kg': weightKg,
      'calories_burned': caloriesBurned,
      'logged_at': loggedAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  // Create from JSON / Supabase map
  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      activityType: json['activity_type'] as String,
      duration: json['duration'] as int,
      weightKg: (json['weight_kg'] as num).toDouble(),
      caloriesBurned: (json['calories_burned'] as num).toDouble(),
      loggedAt: DateTime.parse(json['logged_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // Create from SQLite Map
  factory Workout.fromSqliteMap(Map<String, dynamic> map) {
    return Workout(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      activityType: map['activity_type'] as String,
      duration: map['duration'] as int,
      weightKg: (map['weight_kg'] as num).toDouble(),
      caloriesBurned: (map['calories_burned'] as num).toDouble(),
      loggedAt: DateTime.parse(map['logged_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Workout copyWith({
    String? activityType,
    int? duration,
    double? weightKg,
    double? caloriesBurned,
    DateTime? updatedAt,
  }) {
    return Workout(
      id: id,
      userId: userId,
      activityType: activityType ?? this.activityType,
      duration: duration ?? this.duration,
      weightKg: weightKg ?? this.weightKg,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      loggedAt: loggedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
