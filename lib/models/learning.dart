class LearningSubject {
  final String id;
  final String userId;
  final String name;
  final int dailyTargetMinutes;
  final int totalTargetHours;
  final DateTime loggedAt;
  final DateTime updatedAt;

  LearningSubject({
    required this.id,
    required this.userId,
    required this.name,
    required this.dailyTargetMinutes,
    required this.totalTargetHours,
    required this.loggedAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'daily_target_minutes': dailyTargetMinutes,
      'total_target_hours': totalTargetHours,
      'logged_at': loggedAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'daily_target_minutes': dailyTargetMinutes,
      'total_target_hours': totalTargetHours,
      'logged_at': loggedAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory LearningSubject.fromJson(Map<String, dynamic> json) {
    return LearningSubject(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      dailyTargetMinutes: json['daily_target_minutes'] as int,
      totalTargetHours: json['total_target_hours'] as int,
      loggedAt: DateTime.parse(json['logged_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  factory LearningSubject.fromSqliteMap(Map<String, dynamic> map) {
    return LearningSubject(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      dailyTargetMinutes: map['daily_target_minutes'] as int,
      totalTargetHours: map['total_target_hours'] as int,
      loggedAt: DateTime.parse(map['logged_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

class StudyLog {
  final String id;
  final String userId;
  final String subjectId;
  final int durationMinutes;
  final DateTime loggedAt;
  final DateTime updatedAt;

  StudyLog({
    required this.id,
    required this.userId,
    required this.subjectId,
    required this.durationMinutes,
    required this.loggedAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'subject_id': subjectId,
      'duration_minutes': durationMinutes,
      'logged_at': loggedAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'user_id': userId,
      'subject_id': subjectId,
      'duration_minutes': durationMinutes,
      'logged_at': loggedAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory StudyLog.fromJson(Map<String, dynamic> json) {
    return StudyLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      subjectId: json['subject_id'] as String,
      durationMinutes: json['duration_minutes'] as int,
      loggedAt: DateTime.parse(json['logged_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  factory StudyLog.fromSqliteMap(Map<String, dynamic> map) {
    return StudyLog(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      subjectId: map['subject_id'] as String,
      durationMinutes: map['duration_minutes'] as int,
      loggedAt: DateTime.parse(map['logged_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
