import 'package:flutter/material.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/network/sync_queue_manager.dart';
import 'package:simplebilling_mobile/core/network/sync_task_model.dart';

class SupabaseBanner extends StatelessWidget {
  const SupabaseBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SyncTask>>(
      valueListenable: SyncQueueManager.instance.tasksNotifier,
      builder: (context, tasks, child) {
        final failedTasks = tasks.where((t) => t.status == SyncStatus.failed).toList();
        final pendingTasks = tasks.where((t) => t.status == SyncStatus.pending || t.status == SyncStatus.syncing).toList();
        final isSyncing = tasks.any((t) => t.status == SyncStatus.syncing);

        if (failedTasks.isNotEmpty) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.pastelCoral,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.deepCoral, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_off_rounded, color: AppColors.deepCoral, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Offline Sync Warning',
                        style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.deepCoral, fontSize: 13),
                      ),
                      Text(
                        '${failedTasks.length} bill(s) failed cloud sync. Queued locally.',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.deepCoral, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepCoral,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => SyncQueueManager.instance.processQueue(),
                  child: const Text('Retry Sync', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          );
        }

        if (pendingTasks.isNotEmpty) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.pastelSky,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.deepSky, width: 1.5),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.deepSky)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isSyncing
                        ? 'Syncing ${pendingTasks.length} transaction(s) to Supabase Cloud...'
                        : '${pendingTasks.length} transaction(s) pending sync in queue.',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.deepSky),
                  ),
                ),
                TextButton(
                  onPressed: () => SyncQueueManager.instance.processQueue(),
                  child: const Text('Sync Now', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: AppColors.deepSky)),
                ),
              ],
            ),
          );
        }

        // Healthy connected state
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.deepMint,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Supabase Backend Connected • Real-time Sync Active',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.pastelMint,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ALL SYNCED',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: AppColors.deepMint),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
