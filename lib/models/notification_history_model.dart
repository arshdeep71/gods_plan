class NotificationHistoryModel {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final String type; // 'REMINDER', 'ACHIEVEMENT', etc.
  final String status; // 'DELIVERED', 'COMPLETED', 'MISSED', 'SNOOZED'
  final String? relatedId; // taskId or goalId
  final String? category;
  final String userId;

  NotificationHistoryModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.type,
    required this.status,
    this.relatedId,
    this.category,
    required this.userId,
  });

  factory NotificationHistoryModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedTimestamp;
    try {
      final tsStr = json['timestamp'] as String?;
      parsedTimestamp = tsStr != null ? (DateTime.tryParse(tsStr)?.toLocal() ?? DateTime.now()) : DateTime.now();
    } catch (_) {
      parsedTimestamp = DateTime.now();
    }

    return NotificationHistoryModel(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      timestamp: parsedTimestamp,
      type: (json['type'] as String?) ?? 'REMINDER',
      status: (json['status'] as String?) ?? 'DELIVERED',
      relatedId: json['related_id'] as String?,
      category: json['category'] as String?,
      userId: (json['user_id'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'type': type,
      'status': status,
      'related_id': relatedId,
      'category': category,
      'user_id': userId,
    };
  }
}
