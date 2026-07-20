import 'dart:convert';

class SyncItem {
  final int? id;
  final String actionType; // 'INSERT', 'UPDATE', 'DELETE'
  final String tableName;
  final String recordId;
  final Map<String, dynamic>? payload;
  final int retryCount;
  final DateTime? nextRetryAt;

  SyncItem({
    this.id,
    required this.actionType,
    required this.tableName,
    required this.recordId,
    this.payload,
    this.retryCount = 0,
    this.nextRetryAt,
  });

  // Convert to Map for Local SQLite DB
  Map<String, dynamic> toSqliteMap() {
    return {
      if (id != null) 'id': id,
      'action_type': actionType,
      'table_name': tableName,
      'record_id': recordId,
      'payload': payload != null ? jsonEncode(payload) : null,
      'retry_count': retryCount,
      'next_retry_at': nextRetryAt?.toUtc().toIso8601String(),
    };
  }

  // Create from SQLite Map
  factory SyncItem.fromSqliteMap(Map<String, dynamic> map) {
    return SyncItem(
      id: map['id'] as int?,
      actionType: map['action_type'] as String,
      tableName: map['table_name'] as String,
      recordId: map['record_id'] as String,
      payload: map['payload'] != null 
          ? jsonDecode(map['payload'] as String) as Map<String, dynamic>
          : null,
      retryCount: (map['retry_count'] as int?) ?? 0,
      nextRetryAt: map['next_retry_at'] != null 
          ? DateTime.parse(map['next_retry_at'] as String) 
          : null,
    );
  }

  SyncItem copyWith({
    int? id,
    String? actionType,
    String? tableName,
    String? recordId,
    Map<String, dynamic>? payload,
    int? retryCount,
    DateTime? nextRetryAt,
  }) {
    return SyncItem(
      id: id ?? this.id,
      actionType: actionType ?? this.actionType,
      tableName: tableName ?? this.tableName,
      recordId: recordId ?? this.recordId,
      payload: payload ?? this.payload,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
    );
  }
}
