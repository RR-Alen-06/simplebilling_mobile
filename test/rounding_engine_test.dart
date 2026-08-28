import 'package:flutter_test/flutter_test.dart';
import 'package:simplebilling_mobile/core/utils/rounding_engine.dart';
import 'package:simplebilling_mobile/core/network/sync_task_model.dart';

void main() {
  group('POS Rounding & Calculation Engine Tests', () {
    test('Round Down calculates properly', () {
      final res = RoundingEngine.calculate(45.8, RoundingMethod.roundDown);
      expect(res.roundedTotal, 45.0);
      expect(res.roundingAdjustment, -0.8);
    });

    test('Round Up calculates properly', () {
      final res = RoundingEngine.calculate(45.2, RoundingMethod.roundUp);
      expect(res.roundedTotal, 46.0);
      expect(res.roundingAdjustment, 0.8);
    });

    test('Standard rounding calculates properly', () {
      final res1 = RoundingEngine.calculate(45.4, RoundingMethod.standard);
      expect(res1.roundedTotal, 45.0);
      final res2 = RoundingEngine.calculate(45.6, RoundingMethod.standard);
      expect(res2.roundedTotal, 46.0);
    });
  });

  group('Sync Task State Machine Tests', () {
    test('SyncTask initial state and status transition', () {
      final task = SyncTask(
        id: 'task_1',
        action: 'create_bill',
        payload: {'grand_total': 100.0},
        status: SyncStatus.pending,
        createdAt: DateTime.now(),
      );

      expect(task.status, SyncStatus.pending);

      final syncingTask = task.copyWith(status: SyncStatus.syncing);
      expect(syncingTask.status, SyncStatus.syncing);

      final failedTask = syncingTask.copyWith(status: SyncStatus.failed, errorMessage: 'Network error');
      expect(failedTask.status, SyncStatus.failed);
      expect(failedTask.errorMessage, 'Network error');

      final syncedTask = failedTask.copyWith(status: SyncStatus.synced, clearError: true);
      expect(syncedTask.status, SyncStatus.synced);
      expect(syncedTask.errorMessage, isNull);
    });
  });
}