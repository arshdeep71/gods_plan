import '../services/encryption_service.dart';

class AddictionLog {
  final String id;
  final String userId;
  final String feeling; // e.g. Strong, Struggling, Relapsed
  final int urgeLevel; // 1-10
  final String trigger; // e.g. Stress, Boredom, Fatigue, etc.
  final String helperStrategy; // e.g. Exercised, Cold shower, Called friend
  final bool isRelapse;
  final String notes;
  final DateTime loggedAt;
  final DateTime updatedAt;

  AddictionLog({
    required this.id,
    required this.userId,
    required this.feeling,
    required this.urgeLevel,
    required this.trigger,
    required this.helperStrategy,
    required this.isRelapse,
    required this.notes,
    required this.loggedAt,
    required this.updatedAt,
  });

  // Convert to Map for Supabase / JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'feeling': feeling,
      'urge_level': urgeLevel,
      'trigger_tag': trigger,
      'helper_strategy': helperStrategy,
      'is_relapse': isRelapse,
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
      'feeling': feeling,
      'urge_level': urgeLevel,
      'trigger_tag': trigger,
      'helper_strategy': helperStrategy,
      'is_relapse': isRelapse ? 1 : 0,
      'notes': EncryptionService().encrypt(notes),
      'logged_at': loggedAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  // Create from JSON / Supabase map
  factory AddictionLog.fromJson(Map<String, dynamic> json) {
    return AddictionLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      feeling: json['feeling'] as String,
      urgeLevel: json['urge_level'] as int,
      trigger: json['trigger_tag'] as String,
      helperStrategy: json['helper_strategy'] as String,
      isRelapse: json['is_relapse'] as bool,
      notes: json['notes'] ?? '',
      loggedAt: DateTime.parse(json['logged_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // Create from SQLite Map
  factory AddictionLog.fromSqliteMap(Map<String, dynamic> map) {
    return AddictionLog(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      feeling: map['feeling'] as String,
      urgeLevel: map['urge_level'] as int,
      trigger: map['trigger_tag'] as String,
      helperStrategy: map['helper_strategy'] as String,
      isRelapse: map['is_relapse'] == 1,
      notes: EncryptionService().decrypt(map['notes'] ?? ''),
      loggedAt: DateTime.parse(map['logged_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
