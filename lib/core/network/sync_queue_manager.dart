import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:simplebilling_mobile/core/network/supabase_client.dart';
import 'package:simplebilling_mobile/core/network/sync_task_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';

class SyncQueueManager {
  SyncQueueManager._();
  static final SyncQueueManager instance = SyncQueueManager._();

  final ValueNotifier<List<SyncTask>> tasksNotifier =
      ValueNotifier<List<SyncTask>>([]);
  bool _isProcessing = false;
  static const _uuid = Uuid();

  String get _currentQueueKey {
    final uid = SupabaseConfig.client.auth.currentUser?.id ?? 'guest';
    return 'printpro_sync_queue_$uid';
  }

  Future<void> initialize() async {
    await loadQueue();
    await pruneOldSyncedTasks();
    processQueue();
  }

  Future<void> loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_currentQueueKey);
      if (data != null && data.isNotEmpty) {
        final List list = jsonDecode(data);
        tasksNotifier.value = list.map((e) => SyncTask.fromJson(e)).toList();
      } else {
        tasksNotifier.value = [];
      }
    } catch (e) {
      debugPrint('Error loading sync queue: $e');
    }
  }

  Future<void> _persistQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(
        tasksNotifier.value.map((e) => e.toJson()).toList(),
      );
      await prefs.setString(_currentQueueKey, data);
    } catch (e) {
      debugPrint('Error persisting sync queue: $e');
    }
  }

  /// Automatically prune synced tasks older than 24 hours to prevent unbounded local storage growth
  Future<void> pruneOldSyncedTasks({
    Duration maxAge = const Duration(hours: 24),
  }) async {
    final now = DateTime.now();
    final current = tasksNotifier.value;

    final retained = current.where((task) {
      if (task.status == SyncStatus.synced) {
        final age = now.difference(task.createdAt);
        return age < maxAge;
      }
      return true;
    }).toList();

    if (retained.length != current.length) {
      debugPrint(
        'Pruned ${current.length - retained.length} old synced tasks from local queue.',
      );
      tasksNotifier.value = retained;
      await _persistQueue();
    }
  }

  SyncStatus getStatusForClientRef(String clientRef) {
    for (final task in tasksNotifier.value) {
      if (task.clientRef == clientRef) {
        return task.status;
      }
    }
    return SyncStatus.synced;
  }

  Future<SyncTask> enqueueTask(
    String action,
    Map<String, dynamic> payload, {
    String? clientRef,
  }) async {
    final ref = clientRef ?? payload['client_ref'] as String? ?? _uuid.v4();
    final enrichedPayload = Map<String, dynamic>.from(payload)
      ..['client_ref'] = ref;

    final task = SyncTask(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      action: action,
      clientRef: ref,
      payload: enrichedPayload,
      status: SyncStatus.pending,
      createdAt: DateTime.now(),
    );

    tasksNotifier.value = [...tasksNotifier.value, task];
    await _persistQueue();

    processQueue();
    return task;
  }

  Future<void> retryTask(String taskId) async {
    final current = tasksNotifier.value;
    final index = current.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final updated = List<SyncTask>.from(current);
      updated[index] = updated[index].copyWith(
        status: SyncStatus.pending,
        clearError: true,
      );
      tasksNotifier.value = updated;
      await _persistQueue();
      processQueue();
    }
  }

  Future<void> removeTask(String taskId) async {
    tasksNotifier.value = tasksNotifier.value
        .where((t) => t.id != taskId)
        .toList();
    await _persistQueue();
  }

  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final tasks = List<SyncTask>.from(tasksNotifier.value);
      for (int i = 0; i < tasks.length; i++) {
        final task = tasks[i];
        if (task.status == SyncStatus.pending ||
            task.status == SyncStatus.failed) {
          tasks[i] = task.copyWith(status: SyncStatus.syncing);
          tasksNotifier.value = List.from(tasks);
          await _persistQueue();

          try {
            switch (task.action) {
              case 'create_bill':
                await ApiRepository.syncBillPayload(task.payload);
                break;
              case 'create_customer':
                await ApiRepository.syncCustomerPayload(task.payload);
                break;
              case 'create_product':
                await ApiRepository.syncProductPayload(task.payload);
                break;
              case 'create_expense':
                await ApiRepository.syncExpensePayload(task.payload);
                break;
              default:
                debugPrint('Unknown sync task action: ${task.action}');
            }

            tasks[i] = task.copyWith(
              status: SyncStatus.synced,
              clearError: true,
            );
            tasksNotifier.value = List.from(tasks);
            await _persistQueue();
          } catch (err) {
            debugPrint('Failed to sync task: $err');
            tasks[i] = task.copyWith(
              status: SyncStatus.failed,
              errorMessage: err.toString(),
            );
            tasksNotifier.value = List.from(tasks);
            await _persistQueue();
          }
        }
      }
    } finally {
      _isProcessing = false;
      pruneOldSyncedTasks();
    }
  }
}
