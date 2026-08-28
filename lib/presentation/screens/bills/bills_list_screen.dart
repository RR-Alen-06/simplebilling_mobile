import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';
import 'package:simplebilling_mobile/presentation/shared/printing/receipt_generator.dart';

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
                hintText: 'Search by bill number or customer name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                fillColor: Colors.white,
                filled: true,
              ),
              onChanged: (val) => setState(() => _searchTerm = val.toLowerCase()),
            ),
          ),
          Expanded(
            child: billsAsync.when(
              data: (bills) {
                final filtered = bills.where((b) =>
                    b.billNumber.toLowerCase().contains(_searchTerm) ||
                    (b.customerName?.toLowerCase().contains(_searchTerm) ?? false)).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No bills found'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final bill = filtered[idx];
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
                                Text(
                                  bill.billNumber,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                                ),
                                Text(
                                  Formatters.parseAndFormatDate(bill.createdAt),
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.person, size: 16, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  bill.customerName ?? 'Walk-in Customer',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Grand Total: ${Formatters.currency(bill.grandTotal)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text('Method: ${bill.paymentMethod}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.print, color: AppColors.primary),
                                      tooltip: 'Print Invoice',
                                      onPressed: () {
                                        ReceiptGenerator.printReceipt(
                                          bill: bill,
                                          shop: settings?.shop ?? ShopSettings(),
                                          billing: settings?.billing ?? BillingSettings(),
                                        );
                                      },
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading bills: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
