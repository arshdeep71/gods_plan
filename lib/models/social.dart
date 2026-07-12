class SocialContact {
  final String id;
  final String userId;
  final String name;
  final DateTime lastContacted;
  final String notes;
  final DateTime loggedAt;
  final DateTime updatedAt;

  SocialContact({
    required this.id,
    required this.userId,
    required this.name,
    required this.lastContacted,
    required this.notes,
    required this.loggedAt,
    required this.updatedAt,
  });

  // Convert to Map for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'last_contacted': lastContacted.toUtc().toIso8601String(),
      'notes': notes,
      'logged_at': loggedAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  // Convert to Map for Local SQLite DB
  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'last_contacted': lastContacted.toUtc().toIso8601String(),
      'notes': notes,
      'logged_at': loggedAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  // Create from JSON
  factory SocialContact.fromJson(Map<String, dynamic> json) {
    return SocialContact(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      lastContacted: DateTime.parse(json['last_contacted'] as String),
      notes: json['notes'] ?? '',
      loggedAt: DateTime.parse(json['logged_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // Create from SQLite Map
  factory SocialContact.fromSqliteMap(Map<String, dynamic> map) {
    return SocialContact(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      lastContacted: DateTime.parse(map['last_contacted'] as String),
      notes: map['notes'] ?? '',
      loggedAt: DateTime.parse(map['logged_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
