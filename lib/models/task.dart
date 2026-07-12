class Task {
  final String id;
  final String userId;
  final String title;
  final String difficulty; // 'easy', 'medium', 'hard'
  final String priority;   // 'low', 'medium', 'high'
  final bool isCompleted;
  final bool isRecurring;
  final int streakCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    required this.difficulty,
    required this.priority,
    required this.isCompleted,
    required this.isRecurring,
    this.streakCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to Map for Supabase / JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'difficulty': difficulty,
      'priority': priority,
      'is_completed': isCompleted,
      'is_recurring': isRecurring,
      'streak_count': streakCount,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  // Convert to Map for Local SQLite DB
  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'difficulty': difficulty,
      'priority': priority,
      'is_completed': isCompleted ? 1 : 0,
      'is_recurring': isRecurring ? 1 : 0,
      'streak_count': streakCount,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  // Create from JSON / Supabase map
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      difficulty: json['difficulty'] as String,
      priority: json['priority'] as String,
      isCompleted: json['is_completed'] as bool,
      isRecurring: json['is_recurring'] as bool,
      streakCount: json['streak_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // Create from SQLite Map
  factory Task.fromSqliteMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      difficulty: map['difficulty'] as String,
      priority: map['priority'] as String,
      isCompleted: (map['is_completed'] as int) == 1,
      isRecurring: (map['is_recurring'] as int) == 1,
      streakCount: map['streak_count'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // CopyWith helper method
  Task copyWith({
    String? title,
    String? difficulty,
    String? priority,
    bool? isCompleted,
    bool? isRecurring,
    int? streakCount,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id,
      userId: userId,
      title: title ?? this.title,
      difficulty: difficulty ?? this.difficulty,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      isRecurring: isRecurring ?? this.isRecurring,
      streakCount: streakCount ?? this.streakCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
