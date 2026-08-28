import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simplebilling_mobile/core/network/supabase_client.dart';
import 'package:simplebilling_mobile/core/network/sync_task_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';

class SyncQueueManager {
  SyncQueueManager._();
  static final SyncQueueManager instance = SyncQueueManager._();

  final ValueNotifier<List<SyncTask>> tasksNotifier = ValueNotifier<List<SyncTask>>([]);
  bool _isProcessing = false;

  String get _currentQueueKey {
    final uid = SupabaseConfig.client.auth.currentUser?.id ?? 'guest';
    return 'printpro_sync_queue_' + uid;
  }

  Future<void> initialize() async {
    await loadQueue();
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
      debugPrint('Error loading sync queue: ');
    }
  }

  Future<void> _persistQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(tasksNotifier.value.map((e) => e.toJson()).toList());
      await prefs.setString(_currentQueueKey, data);
    } catch (e) {
      debugPrint('Error persisting sync queue: ');
    }
  }

  Future<SyncTask> enqueueTask(String action, Map<String, dynamic> payload) async {
    final task = SyncTask(
      id: 'task_' + DateTime.now().millisecondsSinceEpoch.toString(),
      action: action,
      payload: payload,
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
      updated[index] = updated[index].copyWith(status: SyncStatus.pending, errorMessage: null);
      tasksNotifier.value = updated;
      await _persistQueue();
      processQueue();
    }
  }

  Future<void> removeTask(String taskId) async {
    tasksNotifier.value = tasksNotifier.value.where((t) => t.id != taskId).toList();
    await _persistQueue();
  }

  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final tasks = List<SyncTask>.from(tasksNotifier.value);
      for (int i = 0; i < tasks.length; i++) {
        final task = tasks[i];
        if (task.status == SyncStatus.pending || task.status == SyncStatus.failed) {
          tasks[i] = task.copyWith(status: SyncStatus.syncing);
          tasksNotifier.value = List.from(tasks);
          await _persistQueue();

          try {
            if (task.action == 'create_bill') {
              await ApiRepository.syncBillPayload(task.payload);
            }

            tasks[i] = task.copyWith(status: SyncStatus.synced);
            tasksNotifier.value = List.from(tasks);
            await _persistQueue();
          } catch (err) {
            debugPrint('Failed to sync task: ');
            tasks[i] = task.copyWith(status: SyncStatus.failed, errorMessage: err.toString());
            tasksNotifier.value = List.from(tasks);
            await _persistQueue();
          }
        }
      }
    } finally {
      _isProcessing = false;
    }
  }
}