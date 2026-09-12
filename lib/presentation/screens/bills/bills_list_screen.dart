import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/network/sync_queue_manager.dart';
import 'package:simplebilling_mobile/core/network/sync_task_model.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/presentation/shared/printing/receipt_generator.dart';
import 'package:simplebilling_mobile/presentation/shared/widgets/invoice_details_modal.dart';
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

  SyncStatus _getBillSyncStatus(
    String? clientRef,
    String id,
    String billNumber,
    List<SyncTask> tasks,
  ) {
    for (final task in tasks) {
      if (task.action == 'create_bill') {
        if ((clientRef != null && task.clientRef == clientRef) ||
            task.id == id ||
            task.clientRef == id) {
          return task.status;
        }
        final taskBillNum =
            task.payload['billData']?['bill_number'] ??
            task.payload['bill_number'];
        if (taskBillNum == billNumber) {
          return task.status;
        }
      }
    }
    return SyncStatus.synced;
  }

  void _showPrintOptionsDialog(
    BillModel bill,
    ShopSettings shop,
    BillingSettings billing,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Invoice: ${bill.billNumber}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grand Total: ${Formatters.currency(bill.grandTotal)} (${bill.paymentMethod})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Date: ${Formatters.parseAndFormatDate(bill.createdAt)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            if (bill.customerName != null)
              Text(
                'Customer: ${bill.customerName} (${bill.customerMobile ?? "-"})',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Share & Print Options:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.chat, size: 16),
            label: const Text('WhatsApp Invoice'),
            onPressed: () async {
              await ReceiptGenerator.shareViaWhatsApp(
                bill: bill,
                shop: shop,
                billing: billing,
              );
            },
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.description, size: 16),
            label: const Text('A4 Invoice'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ReceiptGenerator.printReceipt(
                bill: bill,
                shop: shop,
                billing: billing,
                forceA4: true,
              );
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print 80mm POS'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ReceiptGenerator.printReceipt(
                bill: bill,
                shop: shop,
                billing: billing,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(billsListProvider);
    final settings =
        ref.watch(settingsProvider).value ??
        AllSettings(
          shop: ShopSettings(),
          billing: BillingSettings(),
          loyalty: LoyaltySettings(),
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Manage Bills',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          ValueListenableBuilder<List<SyncTask>>(
            valueListenable: SyncQueueManager.instance.tasksNotifier,
            builder: (context, tasks, child) {
              final pendingCount = tasks
                  .where(
                    (t) =>
                        t.status == SyncStatus.pending ||
                        t.status == SyncStatus.syncing,
                  )
                  .length;
              final failedCount = tasks
                  .where((t) => t.status == SyncStatus.failed)
                  .length;

              if (failedCount > 0) {
                return IconButton(
                  tooltip: 'Sync Failed ($failedCount) - Tap to retry',
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
                  tooltip: 'Syncing $pendingCount items...',
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
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search bill #, customer name, or payment...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchTerm.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchTerm = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
              ),
              onChanged: (v) => setState(() => _searchTerm = v),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<SyncTask>>(
              valueListenable: SyncQueueManager.instance.tasksNotifier,
              builder: (ctx, tasks, _) {
                return billsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 8),
                        Text('Error loading bills: $err'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(billsListProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (bills) {
                    final filtered = bills.where((b) {
                      if (_searchTerm.isEmpty) return true;
                      final q = _searchTerm.toLowerCase();
                      return b.billNumber.toLowerCase().contains(q) ||
                          (b.customerName != null &&
                              b.customerName!.toLowerCase().contains(q)) ||
                          b.paymentMethod.toLowerCase().contains(q);
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchTerm.isEmpty
                                  ? 'No bills generated yet'
                                  : 'No bills matching "$_searchTerm"',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final bill = filtered[i];
                        final syncStatus = _getBillSyncStatus(
                          bill.clientRef,
                          bill.id,
                          bill.billNumber,
                          tasks,
                        );

                        return Card(
                          elevation: 0.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            onTap: () => InvoiceDetailsModal.show(context, bill),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  bill.billNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  Formatters.currency(bill.grandTotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        bill.customerName != null &&
                                                bill.customerName!.isNotEmpty
                                            ? 'Customer: ${bill.customerName}'
                                            : 'Walk-in Customer',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${Formatters.parseAndFormatDate(bill.createdAt)} • ${bill.paymentMethod}',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SyncStatusBadge(status: syncStatus),
                                ],
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.share,
                                color: AppColors.primary,
                              ),
                              tooltip: 'Print or WhatsApp Invoice',
                              onPressed: () => _showPrintOptionsDialog(
                                bill,
                                settings.shop,
                                settings.billing,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
