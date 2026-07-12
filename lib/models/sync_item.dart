import 'dart:convert';

class SyncItem {
  final int? id;
  final String actionType; // 'INSERT', 'UPDATE', 'DELETE'
  final String tableName;
  final String recordId;
  final Map<String, dynamic>? payload;

  SyncItem({
    this.id,
    required this.actionType,
    required this.tableName,
    required this.recordId,
    this.payload,
  });

  // Convert to Map for Local SQLite DB
  Map<String, dynamic> toSqliteMap() {
    return {
      if (id != null) 'id': id,
      'action_type': actionType,
      'table_name': tableName,
      'record_id': recordId,
      'payload': payload != null ? jsonEncode(payload) : null,
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
    );
  }
}
