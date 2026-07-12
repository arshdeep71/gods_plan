class FinanceTransaction {
  final String id;
  final String userId;
  final String type; // 'income' or 'expense'
  final String category; // e.g. Freelance, Food, Transport
  final double amount;
  final String notes;
  final DateTime loggedAt;
  final DateTime updatedAt;

  FinanceTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.category,
    required this.amount,
    required this.notes,
    required this.loggedAt,
    required this.updatedAt,
  });

  // Convert to Map for Supabase / JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'category': category,
      'amount': amount,
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
      'type': type,
      'category': category,
      'amount': amount,
      'notes': notes,
      'logged_at': loggedAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  // Create from JSON / Supabase map
  factory FinanceTransaction.fromJson(Map<String, dynamic> json) {
    return FinanceTransaction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      notes: json['notes'] ?? '',
      loggedAt: DateTime.parse(json['logged_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // Create from SQLite Map
  factory FinanceTransaction.fromSqliteMap(Map<String, dynamic> map) {
    return FinanceTransaction(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      type: map['type'] as String,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      notes: map['notes'] ?? '',
      loggedAt: DateTime.parse(map['logged_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
