import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/network/sync_queue_manager.dart';
import 'package:simplebilling_mobile/core/network/sync_task_model.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/presentation/shared/widgets/sync_status_badge.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

class CustomersListScreen extends ConsumerStatefulWidget {
  const CustomersListScreen({super.key});

  @override
  ConsumerState<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends ConsumerState<CustomersListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchTerm = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  SyncStatus _getCustomerSyncStatus(String? clientRef, String id, List<SyncTask> tasks) {
    for (final task in tasks) {
      if (task.action == 'create_customer') {
        if ((clientRef != null && task.clientRef == clientRef) || task.id == id || task.clientRef == id) {
          return task.status;
        }
      }
    }
    return SyncStatus.synced;
  }

  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final advanceCtrl = TextEditingController(text: '0.0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add New Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Customer Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mobileCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile Number', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: advanceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Initial Advance (₹)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final mobile = mobileCtrl.text.trim().isEmpty ? null : mobileCtrl.text.trim();
              final advance = double.tryParse(advanceCtrl.text) ?? 0.0;
              if (name.isEmpty) return;

              final clientRef = const Uuid().v4();

              // Enqueue create_customer task with unique client_ref
              await SyncQueueManager.instance.enqueueTask(
                'create_customer',
                {
                  'client_ref': clientRef,
                  'name': name,
                  'mobile': mobile,
                  'advance_balance': advance,
                  'loyalty_points': 0.0,
                },
                clientRef: clientRef,
              );

              if (mounted) {
                ref.invalidate(customersProvider);
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text('Save Customer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customers & Balances', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(customersProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _showAddCustomerDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Customer'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name or mobile...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                fillColor: Colors.white,
                filled: true,
              ),
              onChanged: (val) => setState(() => _searchTerm = val.toLowerCase()),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<SyncTask>>(
              valueListenable: SyncQueueManager.instance.tasksNotifier,
              builder: (context, tasks, child) {
                return customersAsync.when(
                  data: (customers) {
                    final filtered = customers.where((c) =>
                        c.name.toLowerCase().contains(_searchTerm) ||
                        (c.mobile ?? '').contains(_searchTerm)).toList();

                    if (filtered.isEmpty) {
                      return const Center(child: Text('No customers found'));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final cust = filtered[idx];
                        final syncStatus = _getCustomerSyncStatus(cust.clientRef, cust.id, tasks);

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.surfaceVariant,
                              child: const Icon(Icons.person, color: AppColors.primary),
                            ),
                            title: Row(
                              children: [
                                Text(cust.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                SyncStatusBadge(
                                  status: syncStatus,
                                  size: 15,
                                  onRetry: () => SyncQueueManager.instance.processQueue(),
                                ),
                              ],
                            ),
                            subtitle: Text('Mobile: ' + (cust.mobile ?? '-')),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Advance: ' + Formatters.currency(cust.advanceBalance),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary, fontSize: 13),
                                ),
                                Text(
                                  cust.loyaltyPoints.toStringAsFixed(0) + ' pts',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, s) => Center(child: Text('Error: ')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}