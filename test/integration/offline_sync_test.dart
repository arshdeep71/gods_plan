import 'package:flutter_test/flutter_test.dart';
import 'package:gods_plan/models/sync_item.dart';

void main() {
  group('Offline Sync Queue & Exponential Backoff Integration', () {
    test('SyncItem initializes with 0 retries and null backoff', () {
      final item = SyncItem(
        actionType: 'INSERT',
        tableName: 'tasks',
        recordId: '123',
        payload: {'title': 'Test'},
      );

      expect(item.retryCount, 0);
      expect(item.nextRetryAt, isNull);
    });

    test('SyncItem gracefully handles SQLite serialization and deserialization', () {
      final now = DateTime.now().toUtc();
      final item = SyncItem(
        id: 1,
        actionType: 'UPDATE',
        tableName: 'goals',
        recordId: 'abc-456',
        payload: {'progress': 50},
        retryCount: 2,
        nextRetryAt: now,
      );

      final map = item.toSqliteMap();
      expect(map['retry_count'], 2);
      expect(map['next_retry_at'], isNotNull);
      expect(map['action_type'], 'UPDATE');

      final reconstructed = SyncItem.fromSqliteMap(map);
      expect(reconstructed.retryCount, 2);
      expect(reconstructed.nextRetryAt!.difference(now).inSeconds, 0);
    });

    test('copyWith correctly increments backoff logic during simulated failure', () {
      final baseItem = SyncItem(
        id: 99,
        actionType: 'DELETE',
        tableName: 'reminders',
        recordId: '789',
      );

      final now = DateTime.now().toUtc();
      
      // Simulate first failure (2^0 = 1 minute delay)
      final firstRetryTime = now.add(const Duration(minutes: 1));
      final failedOnce = baseItem.copyWith(
        retryCount: baseItem.retryCount + 1,
        nextRetryAt: firstRetryTime,
      );

      expect(failedOnce.retryCount, 1);
      expect(failedOnce.nextRetryAt, firstRetryTime);

      // Simulate second failure (2^1 = 2 minute delay)
      final secondRetryTime = now.add(const Duration(minutes: 2));
      final failedTwice = failedOnce.copyWith(
        retryCount: failedOnce.retryCount + 1,
        nextRetryAt: secondRetryTime,
      );

      expect(failedTwice.retryCount, 2);
      expect(failedTwice.nextRetryAt, secondRetryTime);
    });
  });
}
