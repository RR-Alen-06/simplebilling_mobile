import 'package:flutter/material.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/network/sync_task_model.dart';

class SyncStatusBadge extends StatelessWidget {
  final SyncStatus status;
  final VoidCallback? onRetry;
  final double size;

  const SyncStatusBadge({
    super.key,
    required this.status,
    this.onRetry,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case SyncStatus.pending:
        return Tooltip(
          message: 'Pending offline sync',
          child: Icon(Icons.cloud_queue, size: size, color: AppColors.textMuted),
        );
      case SyncStatus.syncing:
        return Tooltip(
          message: 'Syncing with Supabase...',
          child: SizedBox(
            width: size - 4,
            height: size - 4,
            child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
        );
      case SyncStatus.synced:
        return Tooltip(
          message: 'Synced to cloud',
          child: Icon(Icons.cloud_done, size: size, color: AppColors.success),
        );
      case SyncStatus.failed:
        return Tooltip(
          message: 'Sync failed (Tap to retry)',
          child: InkWell(
            onTap: onRetry,
            child: Icon(Icons.cloud_off, size: size, color: AppColors.error),
          ),
        );
    }
  }
}