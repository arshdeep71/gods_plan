class Task {
  final String id;
  final String userId;
  final String title;
  final bool isCompleted;
  final bool isRecurring;
  final String repeatType; // 'never', 'daily', 'weekly', 'monthly'
  final String? reminderTime;
  final int orderIndex;
  final int streakCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPaused;
  final String? dueTime;
  final String? scheduledDate;
  final String? lastCompletedDate;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    required this.isCompleted,
    required this.isRecurring,
    this.repeatType = 'daily',
    this.reminderTime,
    this.orderIndex = 0,
    this.streakCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isPaused = false,
    this.dueTime,
    this.scheduledDate,
    this.lastCompletedDate,
  });

  // Convert to Map for Supabase / JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'is_completed': isCompleted,
      'is_recurring': isRecurring,
      'repeat_type': repeatType,
      'reminder_time': reminderTime,
      'order_index': orderIndex,
      'streak_count': streakCount,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_paused': isPaused,
      'due_time': dueTime,
      'scheduled_date': scheduledDate,
      'last_completed_date': lastCompletedDate,
    };
  }

  // Convert to Map for Local SQLite DB
  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'is_completed': isCompleted ? 1 : 0,
      'is_recurring': isRecurring ? 1 : 0,
      'repeat_type': repeatType,
      'reminder_time': reminderTime,
      'order_index': orderIndex,
      'streak_count': streakCount,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_paused': isPaused ? 1 : 0,
      'due_time': dueTime,
      'scheduled_date': scheduledDate,
      'last_completed_date': lastCompletedDate,
    };
  }

  // Create from JSON / Supabase map
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      isCompleted: json['is_completed'] as bool? ?? false,
      isRecurring: json['is_recurring'] as bool? ?? false,
      repeatType: json['repeat_type'] as String? ?? 'daily',
      reminderTime: json['reminder_time'] as String?,
      orderIndex: json['order_index'] as int? ?? 0,
      streakCount: json['streak_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isPaused: json['is_paused'] as bool? ?? false,
      dueTime: json['due_time'] as String?,
      scheduledDate: json['scheduled_date'] as String?,
      lastCompletedDate: json['last_completed_date'] as String?,
    );
  }

  // Create from SQLite Map
  factory Task.fromSqliteMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      isRecurring: (map['is_recurring'] as int? ?? 0) == 1,
      repeatType: map['repeat_type'] as String? ?? 'daily',
      reminderTime: map['reminder_time'] as String?,
      orderIndex: map['order_index'] as int? ?? 0,
      streakCount: map['streak_count'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isPaused: (map['is_paused'] as int? ?? 0) == 1,
      dueTime: map['due_time'] as String?,
      scheduledDate: map['scheduled_date'] as String?,
      lastCompletedDate: map['last_completed_date'] as String?,
    );
  }

  // CopyWith helper method
  Task copyWith({
    String? title,
    bool? isCompleted,
    bool? isRecurring,
    String? repeatType,
    String? reminderTime,
    int? orderIndex,
    int? streakCount,
    DateTime? updatedAt,
    bool? isPaused,
    String? dueTime,
    String? scheduledDate,
    String? lastCompletedDate,
  }) {
    return Task(
      id: id,
      userId: userId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      isRecurring: isRecurring ?? this.isRecurring,
      repeatType: repeatType ?? this.repeatType,
      reminderTime: reminderTime ?? this.reminderTime,
      orderIndex: orderIndex ?? this.orderIndex,
      streakCount: streakCount ?? this.streakCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPaused: isPaused ?? this.isPaused,
      dueTime: dueTime ?? this.dueTime,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
    );
  }
}
