import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(billsListProvider);
    final customersAsync = ref.watch(customersProvider);

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
            Tab(text: 'Daily Sales'),
            Tab(text: 'Monthly Sales'),
            Tab(text: 'Customer Dues'),
          ],
        ),
      ),
      body: billsAsync.when(
        data: (bills) {
          final todayStr = DateTime.now().toIso8601String().split('T')[0];
          final dailyBills = bills.where((b) => b.createdAt.startsWith(todayStr)).toList();
          final dailyTotal = dailyBills.fold(0.0, (sum, b) => sum + b.grandTotal);

          final monthStr = todayStr.substring(0, 7);
          final monthlyBills = bills.where((b) => b.createdAt.startsWith(monthStr)).toList();
          final monthlyTotal = monthlyBills.fold(0.0, (sum, b) => sum + b.grandTotal);

          return TabBarView(
            controller: _tabController,
            children: [
              // Daily Tab
              _buildBillsReportTab('Today\'s Revenue', dailyTotal, dailyBills),
              // Monthly Tab
              _buildBillsReportTab('Monthly Revenue', monthlyTotal, monthlyBills),
              // Customer Dues Tab
              customersAsync.when(
                data: (customers) {
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: customers.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final cust = customers[idx];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: ListTile(
                          title: Text(cust.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Mobile: ${cust.mobile ?? '-'}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Advance: ${Formatters.currency(cust.advanceBalance)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary, fontSize: 13),
                              ),
                              Text('${cust.loyaltyPoints.toStringAsFixed(0)} pts', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Error: $e')),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, s) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildBillsReportTab(String summaryTitle, double totalAmount, List dynamicBills) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$summaryTitle (${dynamicBills.length} bills):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(
                Formatters.currency(totalAmount),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
              ),
            ],
          ),
        ),
        Expanded(
          child: dynamicBills.isEmpty
              ? const Center(child: Text('No bills recorded for this period'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: dynamicBills.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final b = dynamicBills[idx];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text(b.billNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${b.customerName ?? 'Walk-in'} • ${Formatters.parseAndFormatDate(b.createdAt)}'),
                        trailing: Text(Formatters.currency(b.grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
