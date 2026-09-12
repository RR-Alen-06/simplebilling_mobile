import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/core/utils/whatsapp_sender.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
import 'package:simplebilling_mobile/presentation/screens/customers/customer_details_screen.dart';
import 'package:simplebilling_mobile/presentation/shared/widgets/invoice_details_modal.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _dateFilter = 'today'; // 'today', 'yesterday', 'weekly', 'monthly', 'all_time'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<BillModel> _filterBillsByDate(List<BillModel> bills) {
    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T')[0];

    switch (_dateFilter) {
      case 'today':
        return bills.where((b) => b.createdAt.startsWith(todayStr)).toList();
      case 'yesterday':
        final yest = now.subtract(const Duration(days: 1));
        final yestStr = yest.toIso8601String().split('T')[0];
        return bills.where((b) => b.createdAt.startsWith(yestStr)).toList();
      case 'weekly':
        final weekAgo = now.subtract(const Duration(days: 7));
        return bills.where((b) {
          final dt = DateTime.tryParse(b.createdAt);
          return dt != null && dt.isAfter(weekAgo);
        }).toList();
      case 'monthly':
        final monthStr = todayStr.substring(0, 7);
        return bills.where((b) => b.createdAt.startsWith(monthStr)).toList();
      case 'all_time':
      default:
        return bills;
    }
  }

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(billsListProvider);
    final customersAsync = ref.watch(customerSummariesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reports & Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Sales Report'),
            Tab(text: 'Customer Dues'),
            Tab(text: 'Item Sales'),
          ],
        ),
      ),
      body: billsAsync.when(
        data: (allBills) {
          final filteredBills = _filterBillsByDate(allBills);

          return TabBarView(
            controller: _tabController,
            children: [
              // 1. Sales Report Tab
              _buildSalesReportTab(filteredBills),

              // 2. Customer Dues Tab
              customersAsync.when(
                data: (customers) => _buildCustomerDuesTab(customers),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Error loading dues: $e')),
              ),

              // 3. Item Sales Tab
              _buildItemSalesTab(filteredBills),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, s) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildSalesReportTab(List<BillModel> bills) {
    final totalSales = bills.fold<double>(0.0, (sum, b) => sum + b.grandTotal);
    final totalPaid = bills.fold<double>(0.0, (sum, b) => sum + b.paidTotal);
    final totalCash = bills.fold<double>(0.0, (sum, b) => sum + b.cashPaid);
    final totalUpi = bills.fold<double>(0.0, (sum, b) => sum + b.upiPaid);
    final pendingBalance = (totalSales - totalPaid).clamp(0.0, double.infinity);
    final avgBill = bills.isNotEmpty ? (totalSales / bills.length) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Date Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDateChip('Today', 'today'),
                _buildDateChip('Yesterday', 'yesterday'),
                _buildDateChip('Last 7 Days', 'weekly'),
                _buildDateChip('This Month', 'monthly'),
                _buildDateChip('All Time', 'all_time'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Sales Metrics Overview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Revenue', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                        Text(
                          Formatters.currency(totalSales),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${bills.length} Bills', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13)),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniStat('Cash Collected', Formatters.currency(totalCash), AppColors.secondary),
                    ),
                    Expanded(
                      child: _buildMiniStat('UPI Collected', Formatters.currency(totalUpi), AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniStat('Pending Dues', Formatters.currency(pendingBalance), pendingBalance > 0 ? AppColors.error : AppColors.textSecondary),
                    ),
                    Expanded(
                      child: _buildMiniStat('Avg Bill Value', Formatters.currency(avgBill), AppColors.textPrimary),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Bills List in Period
          const Text('BILLS IN SELECTED PERIOD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 8),

          if (bills.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Text('No bills found for this time period', style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bills.length,
              separatorBuilder: (c, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final b = bills[idx];
                return Card(
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    dense: true,
                    onTap: () => InvoiceDetailsModal.show(context, b),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(b.billNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(Formatters.currency(b.grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                      ],
                    ),
                    subtitle: Text('${b.customerName ?? 'Walk-in'} • ${Formatters.parseAndFormatDate(b.createdAt)} • ${b.paymentMethod}'),
                    trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerDuesTab(List<CustomerModel> customers) {
    final dueCustomers = customers.where((c) => c.balanceDue > 0.01).toList()
      ..sort((a, b) => b.balanceDue.compareTo(a.balanceDue));
    final totalDues = dueCustomers.fold<double>(0.0, (sum, c) => sum + c.balanceDue);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Total Dues KPI Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Outstanding Dues', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                    Text(
                      Formatters.currency(totalDues),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.error),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${dueCustomers.length} Customers Due', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 12)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          const Text('OUTSTANDING CUSTOMER BALANCES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 8),

          if (dueCustomers.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                children: [
                  Icon(Icons.check_circle_outline, size: 40, color: AppColors.secondary),
                  SizedBox(height: 10),
                  Text('All customer accounts are fully settled!', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dueCustomers.length,
              separatorBuilder: (c, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final cust = dueCustomers[idx];

                return Card(
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (c) => CustomerDetailsScreen(customer: cust)),
                      );
                    },
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(cust.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(
                          Formatters.currency(cust.balanceDue),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.error),
                        ),
                      ],
                    ),
                    subtitle: Text('Mobile: ${cust.mobile ?? 'N/A'} • Advance: ${Formatters.currency(cust.advanceBalance)}'),
                    trailing: cust.mobile != null && cust.mobile!.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.chat_outlined, color: AppColors.secondary, size: 20),
                            tooltip: 'Send Due Reminder',
                            onPressed: () {
                              WhatsAppSender.sendCustomerDueReminder(
                                phone: cust.mobile!,
                                customerName: cust.name,
                                pendingBalance: cust.balanceDue,
                              );
                            },
                          )
                        : const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildItemSalesTab(List<BillModel> bills) {
    final itemMap = <String, Map<String, dynamic>>{};

    for (final b in bills) {
      for (final it in b.items) {
        if (!itemMap.containsKey(it.productName)) {
          itemMap[it.productName] = {
            'name': it.productName,
            'qty': 0.0,
            'total': 0.0,
          };
        }
        itemMap[it.productName]!['qty'] += it.quantity;
        itemMap[it.productName]!['total'] += it.total;
      }
    }

    final itemList = itemMap.values.toList()
      ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOP SELLING ITEMS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              Text('${itemList.length} Products Sold', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 8),

          if (itemList.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Text('No item sales recorded in this period', style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: itemList.length,
              separatorBuilder: (c, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final it = itemList[idx];
                final qty = it['qty'] as double;
                final total = it['total'] as double;

                return Card(
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text('#${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                    ),
                    title: Text(it['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Qty Sold: ${qty % 1 == 0 ? qty.toInt() : qty} units'),
                    trailing: Text(
                      Formatters.currency(total),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDateChip(String label, String value) {
    final isSelected = _dateFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        onSelected: (val) {
          if (val) setState(() => _dateFilter = value);
        },
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
