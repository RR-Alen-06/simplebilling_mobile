import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/network/sync_queue_manager.dart';
import 'package:simplebilling_mobile/core/network/sync_task_model.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/core/utils/csv_exporter.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';
import 'package:simplebilling_mobile/presentation/screens/payments/payment_collection_screen.dart';
import 'package:simplebilling_mobile/presentation/shared/widgets/invoice_modal.dart';
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

  // --- Super Admin Edit Discount Modal ---
  void _showEditDiscountModal(BillModel bill, String adminPin) {
    final discountCtrl = TextEditingController(text: bill.discount.toStringAsFixed(2));
    final reasonCtrl = TextEditingController();
    final pinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.pastelAmber,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.deepAmber),
              ),
              child: const Icon(Icons.security_rounded, color: AppColors.deepAmber, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Edit Discount: ${bill.billNumber}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal: ${Formatters.currency(bill.total)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    Text('Current: ${Formatters.currency(bill.grandTotal)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: discountCtrl,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('New Discount Amount (₹)', Icons.savings_outlined),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                decoration: _inputDecoration('Reason for Modification (*)', Icons.edit_note_rounded),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Super Admin PIN (*)', Icons.lock_outline_rounded),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepAmber,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (pinCtrl.text.trim() != adminPin) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid Super Admin PIN! Authorization denied.')),
                );
                return;
              }

              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a mandatory justification reason.')),
                );
                return;
              }

              final newDisc = double.tryParse(discountCtrl.text.trim()) ?? 0.0;
              Navigator.pop(ctx);

              final success = await ApiRepository.updateBillDiscount(
                billId: bill.id,
                newDiscount: newDisc,
                reason: reasonCtrl.text.trim(),
                adminPin: pinCtrl.text.trim(),
              );

              if (!mounted) return;

              if (success) {
                ref.invalidate(billsListProvider);
                ref.invalidate(customersProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.deepMint,
                    content: Text('Invoice ${bill.billNumber} discount updated to ₹$newDisc! 🏷️'),
                  ),
                );
              }
            },
            child: const Text('Authorize & Apply', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(billsListProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.valueOrNull ?? AllSettings(
      shop: ShopSettings(),
      billing: BillingSettings(),
      loyalty: LoyaltySettings(),
    );

    final adminPin = settings.security.adminPin.isNotEmpty ? settings.security.adminPin : '1234';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Manage Bills & Archive',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Export Invoices as CSV',
            icon: const Icon(Icons.download_rounded, color: AppColors.deepLavender),
            onPressed: () async {
              final bills = billsAsync.valueOrNull ?? [];
              if (bills.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No bills available to export.')),
                );
                return;
              }
              await CsvExporter.exportBills(bills);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invoices CSV exported successfully! 📄')),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh Bills',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: () => ref.invalidate(billsListProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by Bill # (e.g. BILL-000001) or Customer Name...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
                suffixIcon: _searchTerm.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchTerm = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              onChanged: (v) => setState(() => _searchTerm = v.trim()),
            ),
          ),

          Expanded(
            child: ValueListenableBuilder<List<SyncTask>>(
              valueListenable: SyncQueueManager.instance.tasksNotifier,
              builder: (ctx, tasks, _) {
                return billsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (err, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 44, color: AppColors.deepCoral),
                        const SizedBox(height: 8),
                        Text('Error loading bills: $err', style: const TextStyle(color: AppColors.textSecondary)),
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
                          (b.customerName != null && b.customerName!.toLowerCase().contains(q)) ||
                          b.paymentMethod.toLowerCase().contains(q);
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.pastelSky,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.deepSky),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchTerm.isEmpty ? 'No bills generated yet' : 'No bills matching "$_searchTerm"',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 15),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final bill = filtered[i];
                        final syncStatus = _getBillSyncStatus(
                          bill.clientRef,
                          bill.id,
                          bill.billNumber,
                          tasks,
                        );

                        // Payment Status Badging
                        final remainingDue = (bill.grandTotal - bill.paidTotal).clamp(0.0, double.infinity);
                        final isFullyPaid = remainingDue <= 0.01;
                        final isPartiallyPaid = !isFullyPaid && bill.paidTotal > 0.01;

                        Color statusBg = AppColors.pastelMint;
                        Color statusText = AppColors.deepMint;
                        String statusLabel = 'Fully Paid';

                        if (isPartiallyPaid) {
                          statusBg = AppColors.pastelSky;
                          statusText = AppColors.deepSky;
                          statusLabel = 'Partially Paid (${Formatters.currency(remainingDue)} left)';
                        } else if (!isFullyPaid) {
                          statusBg = AppColors.pastelAmber;
                          statusText = AppColors.deepAmber;
                          statusLabel = 'Pending (${Formatters.currency(remainingDue)} due)';
                        }

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border, width: 1.5),
                            boxShadow: const [
                              BoxShadow(color: AppColors.shadowLight, offset: Offset(2, 2), blurRadius: 0),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
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
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            fontFamily: 'monospace',
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (bill.isEdited) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: AppColors.pastelAmber,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: AppColors.borderAmber),
                                            ),
                                            child: const Text('Edited', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.deepAmber)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      Formatters.currency(bill.grandTotal),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          bill.customerName != null && bill.customerName!.isNotEmpty
                                              ? bill.customerName!
                                              : 'Walk-in Customer',
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          Formatters.parseAndFormatDate(bill.createdAt),
                                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: statusBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: TextStyle(color: statusText, fontSize: 11, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Method: ${bill.paymentMethod}  |  Disc: ${Formatters.currency(bill.discount)}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                    ),
                                    Row(
                                      children: [
                                        SyncStatusBadge(status: syncStatus),
                                        const SizedBox(width: 4),
                                        // 1. View Invoice Action
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(Icons.remove_red_eye_rounded, color: AppColors.deepLavender, size: 20),
                                          tooltip: 'View Full Invoice',
                                          onPressed: () => InvoiceModal.show(context, bill: bill, settings: settings),
                                        ),
                                        // 2. Collect Payment Action (for unpaid/partially paid)
                                        if (!isFullyPaid && bill.customerId != null)
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            icon: const Icon(Icons.credit_card_rounded, color: AppColors.deepMint, size: 20),
                                            tooltip: 'Collect Payment',
                                            onPressed: () {
                                              final cust = CustomerModel(
                                                id: bill.customerId!,
                                                name: bill.customerName ?? 'Customer',
                                                mobile: bill.customerMobile,
                                                balanceDue: remainingDue,
                                              );
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => PaymentCollectionScreen(initialCustomer: cust),
                                                ),
                                              );
                                            },
                                          ),
                                        // 3. Super Admin Edit Discount
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(Icons.edit_note_rounded, color: AppColors.deepAmber, size: 20),
                                          tooltip: 'Super Admin Edit Discount',
                                          onPressed: () => _showEditDiscountModal(bill, adminPin),
                                        ),
                                      ],
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
    );
  }
}
