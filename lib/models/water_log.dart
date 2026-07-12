class WaterLog {
  final String id;
  final String userId;
  final int glasses;
  final DateTime loggedAt;
  final DateTime updatedAt;

  WaterLog({
    required this.id,
    required this.userId,
    required this.glasses,
    required this.loggedAt,
    required this.updatedAt,
  });

  // Convert to Map for Supabase / JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'glasses': glasses,
      'logged_at': loggedAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  // Convert to Map for Local SQLite DB
  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'user_id': userId,
      'glasses': glasses,
      'logged_at': loggedAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  // Create from JSON / Supabase map
  factory WaterLog.fromJson(Map<String, dynamic> json) {
    return WaterLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      glasses: json['glasses'] as int,
      loggedAt: DateTime.parse(json['logged_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // Create from SQLite Map
  factory WaterLog.fromSqliteMap(Map<String, dynamic> map) {
    return WaterLog(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      glasses: map['glasses'] as int,
      loggedAt: DateTime.parse(map['logged_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
