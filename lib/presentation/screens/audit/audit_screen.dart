import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/data/models/audit_log_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';

final auditLogsProvider = FutureProvider<List<AuditLogModel>>((ref) async {
  return await ApiRepository.getAuditLogs();
});

class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Audit Trail & Logs', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(auditLogsProvider),
          ),
        ],
      ),
      body: logsAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(child: Text('No audit logs recorded yet'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (c, i) => const SizedBox(height: 10),
            itemBuilder: (ctx, idx) {
              final log = logs[idx];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              log.action,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                            ),
                          ),
                          Text(
                            Formatters.parseAndFormatDate(log.createdAt),
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Entity: ${log.entity}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      if (log.newValue != null) ...[
                        const SizedBox(height: 4),
                        Text('Change: ${log.newValue}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                      const SizedBox(height: 4),
                      Text('Logged by: ${log.userName}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, s) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
