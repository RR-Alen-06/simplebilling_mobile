import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/network/sync_queue_manager.dart';
import 'package:simplebilling_mobile/core/network/sync_task_model.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/presentation/shared/printing/receipt_generator.dart';
import 'package:simplebilling_mobile/presentation/shared/widgets/sync_status_badge.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

class BillsListScreen extends ConsumerStatefulWidget {
  const BillsListScreen({super.key});

  @override
  ConsumerState<BillsListScreen> createState() => _BillsListScreenState();
}

class _BillsListScreenState extends ConsumerState<BillsListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchTerm = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  SyncStatus _getBillSyncStatus(String billNumber, List<SyncTask> tasks) {
    for (final task in tasks) {
      if (task.action == 'create_bill') {
        final taskBillNum = task.payload['billData']?['bill_number'];
        if (taskBillNum == billNumber) {
          return task.status;
        }
      }
    }
    return SyncStatus.synced;
  }

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(billsListProvider);
    final settings = ref.watch(settingsProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Bills', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          ValueListenableBuilder<List<SyncTask>>(
            valueListenable: SyncQueueManager.instance.tasksNotifier,
            builder: (context, tasks, child) {
              final pendingCount = tasks.where((t) => t.status == SyncStatus.pending || t.status == SyncStatus.syncing).length;
              final failedCount = tasks.where((t) => t.status == SyncStatus.failed).length;

              if (failedCount > 0) {
                return IconButton(
                  tooltip: 'Sync Failed () - Tap to retry',
                  icon: const Badge(
                    label: Text('!'),
                    backgroundColor: AppColors.error,
                    child: Icon(Icons.cloud_off, color: AppColors.error),
                  ),
                  onPressed: () => SyncQueueManager.instance.processQueue(),
                );
              }

              if (pendingCount > 0) {
                return IconButton(
                  tooltip: 'Syncing  items...',
                  icon: const Badge(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.cloud_sync, color: AppColors.primary),
                  ),
                  onPressed: () => SyncQueueManager.instance.processQueue(),
                );
              }

              return const IconButton(
                tooltip: 'All bills synced to Supabase',
                icon: Icon(Icons.cloud_done, color: AppColors.success),
                onPressed: null,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(billsListProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by bill #, customer name, mobile...',
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
                return billsAsync.when(
                  data: (bills) {
                    final filtered = bills.where((b) {
                      final numberMatch = b.billNumber.toLowerCase().contains(_searchTerm);
                      final nameMatch = (b.customerName ?? '').toLowerCase().contains(_searchTerm);
                      final phoneMatch = (b.customerMobile ?? '').contains(_searchTerm);
                      return numberMatch || nameMatch || phoneMatch;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(child: Text('No bills found'));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final bill = filtered[idx];
                        final syncStatus = _getBillSyncStatus(bill.billNumber, tasks);
                        final custName = bill.customerName ?? 'Walk-in';
                        final custMobile = bill.customerMobile ?? '-';

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          bill.billNumber,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                                        ),
                                        const SizedBox(width: 8),
                                        SyncStatusBadge(
                                          status: syncStatus,
                                          size: 16,
                                          onRetry: () => SyncQueueManager.instance.processQueue(),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      Formatters.currency(bill.grandTotal),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Customer:  ()',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Payment:  • Items:  • ',
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                                const Divider(height: 18),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                      icon: const Icon(Icons.print, size: 16),
                                      label: const Text('Thermal 80mm'),
                                      onPressed: () {
                                        final currentSettings = settings ?? AllSettings(
                                          shop: ShopSettings(),
                                          billing: BillingSettings(defaultPrinterSize: '80mm'),
                                          loyalty: LoyaltySettings(),
                                        );
                                        ReceiptGenerator.printReceipt(
                                          bill: bill,
                                          shop: currentSettings.shop,
                                          billing: BillingSettings(defaultPrinterSize: '80mm'),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      icon: const Icon(Icons.picture_as_pdf, size: 16),
                                      label: const Text('A4 PDF'),
                                      onPressed: () {
                                        final currentSettings = settings ?? AllSettings(
                                          shop: ShopSettings(),
                                          billing: BillingSettings(defaultPrinterSize: 'A4'),
                                          loyalty: LoyaltySettings(),
                                        );
                                        ReceiptGenerator.printReceipt(
                                          bill: bill,
                                          shop: currentSettings.shop,
                                          billing: BillingSettings(defaultPrinterSize: 'A4'),
                                        );
                                      },
                                    ),
                                  ],
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