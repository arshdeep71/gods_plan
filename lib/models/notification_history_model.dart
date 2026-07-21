class NotificationHistoryModel {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final String type; // 'REMINDER', 'ACHIEVEMENT', etc.
  final String status; // 'DELIVERED', 'COMPLETED', 'MISSED', 'SNOOZED'
  final String? relatedId; // taskId or goalId
  final String? category;

  NotificationHistoryModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.type,
    required this.status,
    this.relatedId,
    this.category,
  });

  factory NotificationHistoryModel.fromJson(Map<String, dynamic> json) {
    return NotificationHistoryModel(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
      type: json['type'] as String,
      status: json['status'] as String,
      relatedId: json['related_id'] as String?,
      category: json['category'] as String?,
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
    };
  }
}
