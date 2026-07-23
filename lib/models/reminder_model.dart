class ReminderModel {
  final String id;
  final String userId;
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
    required this.userId,
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
    final String? id = json['id'] as String?;
    final String? userId = json['user_id'] as String?;
    final String? taskId = json['task_id'] as String?;
    final String? scheduledTimeRaw = json['scheduled_time'] as String?;
    final String? title = json['title'] as String?;
    final String? body = json['body'] as String?;

    if (id == null || id.isEmpty) {
      throw FormatException('ReminderModel.fromJson failed: "id" field is missing or empty.');
    }
    if (taskId == null || taskId.isEmpty) {
      throw FormatException('ReminderModel.fromJson failed for reminder $id: "task_id" is missing or empty.');
    }
    if (scheduledTimeRaw == null || scheduledTimeRaw.isEmpty) {
      throw FormatException('ReminderModel.fromJson failed for reminder $id: "scheduled_time" is missing or empty.');
    }
    final scheduledTimeParsed = DateTime.tryParse(scheduledTimeRaw);
    if (scheduledTimeParsed == null) {
      throw FormatException('ReminderModel.fromJson failed for reminder $id: "scheduled_time" ("$scheduledTimeRaw") is not a valid ISO date.');
    }
    if (title == null || title.isEmpty) {
      throw FormatException('ReminderModel.fromJson failed for reminder $id: "title" is missing or empty.');
    }

    return ReminderModel(
      id: id,
      userId: userId ?? '',
      taskId: taskId,
      goalId: json['goal_id'] as String?,
      scheduledTime: scheduledTimeParsed.toLocal(),
      type: (json['type'] as String?) ?? 'REMINDER',
      title: title,
      body: body ?? '',
      category: json['category'] as String?,
      repeatPattern: (json['repeat_pattern'] as String?) ?? 'ONCE',
      isCompleted: (json['is_completed'] as int? ?? 0) == 1,
      isSnoozed: (json['is_snoozed'] as int? ?? 0) == 1,
      snoozeUntil: json['snooze_until'] != null ? DateTime.tryParse(json['snooze_until'].toString())?.toLocal() : null,
      deepLink: json['deep_link'] as String?,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      deletedAt: json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at'].toString())?.toLocal() : null,
    );
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'user_id': userId,
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
      'user_id': userId,
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
    String? userId,
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
      userId: userId ?? this.userId,
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
