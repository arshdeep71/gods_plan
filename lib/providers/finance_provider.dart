import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/finance_transaction.dart';
import '../models/sync_item.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class FinanceProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final SyncService _syncService = SyncService();
  final Uuid _uuid = const Uuid();

  List<FinanceTransaction> _transactions = [];
  bool _isLoading = false;

  List<FinanceTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;

  String? get _currentUserId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  // Settings getters
  double get dailySavingsTarget {
    final uid = _currentUserId;
    if (uid == null) return 500.0;
    return (_dbService.settingsBox.get('daily_savings_target_$uid', defaultValue: 500.0) as num).toDouble();
  }

  double get monthlySavingsTarget {
    final uid = _currentUserId;
    if (uid == null) return 15000.0;
    return (_dbService.settingsBox.get('monthly_savings_target_$uid', defaultValue: 15000.0) as num).toDouble();
  }

  double get bigSavingsTarget {
    final uid = _currentUserId;
    if (uid == null) return 5000.0;
    return (_dbService.settingsBox.get('big_savings_target_$uid', defaultValue: 5000.0) as num).toDouble();
  }

  // Save new settings
  Future<void> updateTargets({required double daily, required double monthly, required double big}) async {
    final uid = _currentUserId;
    if (uid == null) return;
    await _dbService.settingsBox.put('daily_savings_target_$uid', daily);
    await _dbService.settingsBox.put('monthly_savings_target_$uid', monthly);
    await _dbService.settingsBox.put('big_savings_target_$uid', big);
    await _syncProfileFinanceTargets(uid, daily, monthly, big);
    notifyListeners();
  }

  Future<void> _syncProfileFinanceTargets(String userId, double daily, double monthly, double big) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .upsert({
            'id': userId,
            'daily_savings_target': daily,
            'monthly_savings_target': monthly,
            'big_savings_target': big,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'id');
    } catch (e) {
      final syncItem = SyncItem(
        actionType: 'UPDATE',
        tableName: 'profiles',
        recordId: userId,
        payload: {
          'id': userId,
          'daily_savings_target': daily,
          'monthly_savings_target': monthly,
          'big_savings_target': big,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      await _dbService.queueMutation(syncItem);
    }
  }

  // Fetch transactions from SQLite
  Future<void> fetchTransactions(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _transactions = await _dbService.getLocalFinanceTransactions(userId);
    } catch (e) {
      print("Error fetching finance transactions: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add transaction
  Future<void> addTransaction({
    required String userId,
    required String type, // 'income' or 'expense'
    required String category,
    required double amount,
    required String notes,
  }) async {
    final now = DateTime.now();
    final tx = FinanceTransaction(
      id: _uuid.v4(),
      userId: userId,
      type: type,
      category: category,
      amount: amount,
      notes: notes,
      loggedAt: now,
      updatedAt: now,
    );

    // Save locally
    await _dbService.upsertLocalFinanceTransaction(tx);

    // Queue offline sync mutation
    final syncItem = SyncItem(
      actionType: 'INSERT',
      tableName: 'finance_transactions',
      recordId: tx.id,
      payload: tx.toJson(),
    );
    await _dbService.queueMutation(syncItem);

    // Refresh list locally
    _transactions.insert(0, tx);
    notifyListeners();

    // Trigger sync in background
    _syncService.sync(userId).then((_) {
      fetchTransactions(userId);
    });
  }

  // Delete transaction
  Future<void> deleteTransaction(String userId, String txId) async {
    await _dbService.deleteLocalFinanceTransaction(txId);

    final syncItem = SyncItem(
      actionType: 'DELETE',
      tableName: 'finance_transactions',
      recordId: txId,
    );
    await _dbService.queueMutation(syncItem);

    _transactions.removeWhere((t) => t.id == txId);
    notifyListeners();

    _syncService.sync(userId).then((_) {
      fetchTransactions(userId);
    });
  }

  // Calculations helper properties
  double get todayIncome {
    final now = DateTime.now();
    return _transactions
        .where((t) => t.type == 'income' && _isSameDay(t.loggedAt, now))
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get todayExpense {
    final now = DateTime.now();
    return _transactions
        .where((t) => t.type == 'expense' && _isSameDay(t.loggedAt, now))
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get todayNetSavings => todayIncome - todayExpense;

  double get monthlyIncome {
    final now = DateTime.now();
    return _transactions
        .where((t) => t.type == 'income' && t.loggedAt.month == now.month && t.loggedAt.year == now.year)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get monthlyExpense {
    final now = DateTime.now();
    return _transactions
        .where((t) => t.type == 'expense' && t.loggedAt.month == now.month && t.loggedAt.year == now.year)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get monthlyNetSavings => monthlyIncome - monthlyExpense;

  // Cumulative savings across all logged history
  double get totalSaved {
    double total = 0.0;
    for (final tx in _transactions) {
      if (tx.type == 'income') {
        total += tx.amount;
      } else {
        total -= tx.amount;
      }
    }
    return total > 0 ? total : 0.0;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.day == b.day && a.month == b.month && a.year == b.year;
  }
}
