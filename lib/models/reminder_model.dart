class ReminderModel {
  final String id;
  final String taskId;
  final String? goalId;
  final DateTime scheduledTime;
  final String type; // 'REMINDER', 'MILESTONE', 'ACHIEVEMENT', 'MOTIVATION', 'MISSED'
  final String title;
  final String body;
  final String? category;
  final String repeatPattern; // 'ONCE', 'DAILY', 'WEEKLY', 'MONTHLY', 'CUSTOM'
  final bool isCompleted;
  final bool isSnoozed;
  final DateTime? snoozeUntil;
  final String? deepLink;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt; // For soft deletes

  ReminderModel({
    required this.id,
    required this.taskId,
    this.goalId,
    required this.scheduledTime,
    required this.type,
    required this.title,
    required this.body,
    this.category,
    this.repeatPattern = 'ONCE',
    this.isCompleted = false,
    this.isSnoozed = false,
    this.snoozeUntil,
    this.deepLink,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      goalId: json['goal_id'] as String?,
      scheduledTime: DateTime.parse(json['scheduled_time'] as String).toLocal(),
      type: json['type'] as String? ?? 'REMINDER',
      title: json['title'] as String,
      body: json['body'] as String,
      category: json['category'] as String?,
      repeatPattern: json['repeat_pattern'] as String? ?? 'ONCE',
      isCompleted: (json['is_completed'] as int? ?? 0) == 1,
      isSnoozed: (json['is_snoozed'] as int? ?? 0) == 1,
      snoozeUntil: json['snooze_until'] != null ? DateTime.parse(json['snooze_until'] as String).toLocal() : null,
      deepLink: json['deep_link'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String).toLocal() : null,
    );
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'task_id': taskId,
      'goal_id': goalId,
      'scheduled_time': scheduledTime.toUtc().toIso8601String(),
      'type': type,
      'title': title,
      'body': body,
      'category': category,
      'repeat_pattern': repeatPattern,
      'is_completed': isCompleted ? 1 : 0,
      'is_snoozed': isSnoozed ? 1 : 0,
      'snooze_until': snoozeUntil?.toUtc().toIso8601String(),
      'deep_link': deepLink,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'goal_id': goalId,
      'scheduled_time': scheduledTime.toUtc().toIso8601String(),
      'type': type,
      'title': title,
      'body': body,
      'category': category,
      'repeat_pattern': repeatPattern,
      'is_completed': isCompleted,
      'is_snoozed': isSnoozed,
      'snooze_until': snoozeUntil?.toUtc().toIso8601String(),
      'deep_link': deepLink,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  ReminderModel copyWith({
    String? id,
    String? taskId,
    String? goalId,
    DateTime? scheduledTime,
    String? type,
    String? title,
    String? body,
    String? category,
    String? repeatPattern,
    bool? isCompleted,
    bool? isSnoozed,
    DateTime? snoozeUntil,
    String? deepLink,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      goalId: goalId ?? this.goalId,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      repeatPattern: repeatPattern ?? this.repeatPattern,
      isCompleted: isCompleted ?? this.isCompleted,
      isSnoozed: isSnoozed ?? this.isSnoozed,
      snoozeUntil: snoozeUntil ?? this.snoozeUntil,
      deepLink: deepLink ?? this.deepLink,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
