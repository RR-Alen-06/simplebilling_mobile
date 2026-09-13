import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/core/utils/csv_exporter.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
import 'package:simplebilling_mobile/data/models/expense_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';
import 'package:simplebilling_mobile/presentation/shared/widgets/invoice_modal.dart';
import 'package:simplebilling_mobile/presentation/shared/widgets/supabase_banner.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

enum DashboardDateRange { today, yesterday, week, month, quarter, year, financialYear, custom }

class DashboardScreen extends ConsumerStatefulWidget {
  final Function(int tabIndex)? onNavigateTab;
  const DashboardScreen({super.key, this.onNavigateTab});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DashboardDateRange _selectedRange = DashboardDateRange.today;
  DateTimeRange? _customDateRange;

  DateTimeRange _getDateRangeForFilter() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (_selectedRange) {
      case DashboardDateRange.today:
        return DateTimeRange(start: todayStart, end: todayEnd);

      case DashboardDateRange.yesterday:
        final yest = now.subtract(const Duration(days: 1));
        final yestStart = DateTime(yest.year, yest.month, yest.day);
        final yestEnd = DateTime(yest.year, yest.month, yest.day, 23, 59, 59);
        return DateTimeRange(start: yestStart, end: yestEnd);

      case DashboardDateRange.week:
        final weekStart = now.subtract(const Duration(days: 6));
        return DateTimeRange(
          start: DateTime(weekStart.year, weekStart.month, weekStart.day),
          end: todayEnd,
        );

      case DashboardDateRange.month:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: todayEnd,
        );

      case DashboardDateRange.quarter:
        // Current quarter start
        final quarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return DateTimeRange(
          start: DateTime(now.year, quarterMonth, 1),
          end: todayEnd,
        );

      case DashboardDateRange.year:
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: todayEnd,
        );

      case DashboardDateRange.financialYear:
        // Indian Financial Year: April 1 to March 31
        final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
        return DateTimeRange(
          start: DateTime(fyStartYear, 4, 1),
          end: todayEnd,
        );

      case DashboardDateRange.custom:
        return _customDateRange ?? DateTimeRange(start: todayStart, end: todayEnd);
    }
  }

  bool _isDateInRange(String? dateStr, DateTimeRange range) {
    if (dateStr == null || dateStr.isEmpty) return false;
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return false;
    return (parsed.isAfter(range.start) || parsed.isAtSameMomentAs(range.start)) &&
        (parsed.isBefore(range.end) || parsed.isAtSameMomentAs(range.end));
  }

  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Quick Add Customer', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Customer Name *')),
            const SizedBox(height: 10),
            TextField(controller: mobileCtrl, decoration: const InputDecoration(labelText: 'Mobile Number')),
            const SizedBox(height: 10),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final mobile = mobileCtrl.text.trim().isEmpty ? null : mobileCtrl.text.trim();
              final email = emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim();
              await ApiRepository.createCustomer(name, mobile, email: email);
              ref.invalidate(customersProvider);
              ref.invalidate(customerSummariesProvider);
              if (mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer added! 🎉')));
              }
            },
            child: const Text('Save Customer'),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = 'Shop Expense';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Quick Log Expense', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Expense Title / Description *')),
              const SizedBox(height: 10),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹) *')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(value: 'Shop Expense', child: Text('Shop Expense')),
                  DropdownMenuItem(value: 'Electricity', child: Text('Electricity')),
                  DropdownMenuItem(value: 'Rent', child: Text('Rent')),
                  DropdownMenuItem(value: 'Paper Stock', child: Text('Paper Stock')),
                  DropdownMenuItem(value: 'Toner / Ink', child: Text('Toner / Ink')),
                  DropdownMenuItem(value: 'Salaries', child: Text('Salaries')),
                  DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (val) => setModalState(() => category = val ?? 'Shop Expense'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepCoral,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                final title = titleCtrl.text.trim();
                if (title.isEmpty || amt <= 0) return;
                await ApiRepository.createExpense(title, amt, category);
                ref.invalidate(expensesListProvider);
                if (mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense logged! 💸')));
                }
              },
              child: const Text('Save Expense'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(billsListProvider);
    final customersAsync = ref.watch(customerSummariesProvider);
    final expensesAsync = ref.watch(expensesListProvider);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Reconciliation & Store Dashboard',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary),
            ),
            Text(
              'Cash & UPI reconciliation, real-time ledger, and cashflow monitoring',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary.withValues(alpha: 0.9)),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh All Data',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: () {
              ref.invalidate(billsListProvider);
              ref.invalidate(customerSummariesProvider);
              ref.invalidate(expensesListProvider);
              ref.invalidate(settingsProvider);
            },
          ),
        ],
      ),
      body: billsAsync.when(
        data: (allBills) {
          final allCustomers = customersAsync.valueOrNull ?? [];
          final allExpenses = expensesAsync.valueOrNull ?? [];
          final activeRange = _getDateRangeForFilter();

          // 1. Period Filtering
          final filteredBills = allBills.where((b) => _isDateInRange(b.createdAt, activeRange)).toList();
          final filteredExpenses = allExpenses.where((e) => _isDateInRange(e.date, activeRange)).toList();

          // 2. Metrics & Reconciliation Calculations
          final totalSalesBilled = filteredBills.fold(0.0, (sum, b) => sum + b.grandTotal);

          double cashCollected = 0.0;
          double upiCollected = 0.0;
          double outstandingPeriodAmount = 0.0;

          for (final b in filteredBills) {
            final method = b.paymentMethod.toUpperCase();
            if (method == 'CASH') {
              cashCollected += b.paidTotal;
            } else if (method == 'UPI') {
              upiCollected += b.paidTotal;
            } else if (method == 'SPLIT') {
              // Extract split components if recorded, or distribute
              if (b.cashPaid > 0 || b.upiPaid > 0) {
                cashCollected += b.cashPaid;
                upiCollected += b.upiPaid;
              } else {
                cashCollected += (b.paidTotal / 2);
                upiCollected += (b.paidTotal / 2);
              }
            } else {
              // Direct cash fallback
              cashCollected += b.paidTotal;
            }

            final unpaid = (b.grandTotal - b.paidTotal).clamp(0.0, double.infinity);
            outstandingPeriodAmount += unpaid;
          }

          final totalAmountCollected = cashCollected + upiCollected;
          final totalCustomerAdvance = allCustomers.fold(0.0, (sum, c) => sum + c.advanceBalance);
          final periodExpenses = filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);
          final netProfit = totalAmountCollected - periodExpenses;

          // 3. Daily trend data for Area Chart (last 7 data points or filtered days)
          final trendMap = <String, double>{};
          for (int i = 6; i >= 0; i--) {
            final day = DateTime.now().subtract(Duration(days: i));
            final key = DateFormat('yyyy-MM-dd').format(day);
            trendMap[key] = 0.0;
          }
          for (final b in filteredBills) {
            final dateKey = b.createdAt.split('T')[0];
            if (trendMap.containsKey(dateKey)) {
              trendMap[dateKey] = (trendMap[dateKey] ?? 0.0) + b.grandTotal;
            }
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(billsListProvider);
              ref.invalidate(customerSummariesProvider);
              ref.invalidate(expensesListProvider);
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWidescreen = constraints.maxWidth >= 850;

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Supabase Status Banner
                      const SupabaseBanner(),

                      // 2. Reconciliation Period & Date Filtering Row
                      _buildDateFilterRow(context),
                      const SizedBox(height: 12),

                      // 3. Quick Action Hub
                      _buildQuickActionsBar(filteredBills),
                      const SizedBox(height: 14),

                      // 4. 6-Card KPI Summary Grid
                      _build6CardKpiGrid(
                        isWidescreen: isWidescreen,
                        totalSalesBilled: totalSalesBilled,
                        cashCollected: cashCollected,
                        upiCollected: upiCollected,
                        totalAmountCollected: totalAmountCollected,
                        outstandingAmount: outstandingPeriodAmount,
                        customerAdvanceBalance: totalCustomerAdvance,
                        billCount: filteredBills.length,
                      ),
                      const SizedBox(height: 14),

                      // 5. Payment Analysis Breakdown & Net Profit Card Row
                      if (isWidescreen)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 1,
                              child: _buildPaymentAnalysisTable(
                                cashCollected: cashCollected,
                                upiCollected: upiCollected,
                                totalCollected: totalAmountCollected,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 1,
                              child: _buildNetProfitCard(
                                totalIncome: totalAmountCollected,
                                totalExpenses: periodExpenses,
                                netProfit: netProfit,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildPaymentAnalysisTable(
                          cashCollected: cashCollected,
                          upiCollected: upiCollected,
                          totalCollected: totalAmountCollected,
                        ),
                        const SizedBox(height: 14),
                        _buildNetProfitCard(
                          totalIncome: totalAmountCollected,
                          totalExpenses: periodExpenses,
                          netProfit: netProfit,
                        ),
                      ],
                      const SizedBox(height: 14),

                      // 6. Interactive Analytics Charts (Area Chart + Payment Distribution Donut)
                      if (isWidescreen)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildSalesTrendAreaChart(trendMap)),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 2,
                              child: _buildPaymentMethodDonutChart(
                                cashCollected: cashCollected,
                                upiCollected: upiCollected,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildSalesTrendAreaChart(trendMap),
                        const SizedBox(height: 14),
                        _buildPaymentMethodDonutChart(
                          cashCollected: cashCollected,
                          upiCollected: upiCollected,
                        ),
                      ],
                      const SizedBox(height: 14),

                      // 7. Recent Transactions Live Feed (8 transactions + View/Print Modal)
                      _buildRecentTransactionsCard(allBills, settingsAsync.valueOrNull),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, s) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
              const SizedBox(height: 10),
              Text('Error loading dashboard: $err', style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => ref.invalidate(billsListProvider),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 2. RECONCILIATION PERIOD & DATE FILTERING ---
  Widget _buildDateFilterRow(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('Today', DashboardDateRange.today),
          const SizedBox(width: 6),
          _buildFilterChip('Yesterday', DashboardDateRange.yesterday),
          const SizedBox(width: 6),
          _buildFilterChip('Weekly', DashboardDateRange.week),
          const SizedBox(width: 6),
          _buildFilterChip('Monthly', DashboardDateRange.month),
          const SizedBox(width: 6),
          _buildFilterChip('Quarterly', DashboardDateRange.quarter),
          const SizedBox(width: 6),
          _buildFilterChip('Yearly', DashboardDateRange.year),
          const SizedBox(width: 6),
          _buildFilterChip('FY (Apr-Mar)', DashboardDateRange.financialYear),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.date_range_rounded, size: 16, color: AppColors.deepLavender),
            label: Text(
              _selectedRange == DashboardDateRange.custom && _customDateRange != null
                  ? '${DateFormat('dd MMM').format(_customDateRange!.start)} - ${DateFormat('dd MMM').format(_customDateRange!.end)}'
                  : 'Custom Date',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.deepLavender),
            ),
            backgroundColor: _selectedRange == DashboardDateRange.custom ? AppColors.pastelLavender : Colors.white,
            side: const BorderSide(color: AppColors.neoBorder, width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                initialDateRange: _customDateRange ??
                    DateTimeRange(
                      start: DateTime.now().subtract(const Duration(days: 7)),
                      end: DateTime.now(),
                    ),
              );
              if (picked != null) {
                setState(() {
                  _customDateRange = picked;
                  _selectedRange = DashboardDateRange.custom;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, DashboardDateRange range) {
    final isSelected = _selectedRange == range;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: isSelected ? AppColors.textPrimary : AppColors.textSecondary)),
      selected: isSelected,
      selectedColor: AppColors.pastelSky,
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.neoBorder, width: 1.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (val) {
        if (val) setState(() => _selectedRange = range);
      },
    );
  }

  // --- 1. QUICK ACTION SHORTCUTS HUB ---
  Widget _buildQuickActionsBar(List<BillModel> filteredBills) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neoBorder, width: 1.5),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.point_of_sale_rounded, size: 16),
            label: const Text('+ Create Bill (POS)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            onPressed: () {
              widget.onNavigateTab?.call(1);
            },
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.deepSky,
              backgroundColor: AppColors.pastelSky.withValues(alpha: 0.5),
              side: const BorderSide(color: AppColors.deepSky, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            icon: const Icon(Icons.inventory_2_rounded, size: 16),
            label: const Text('Products', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            onPressed: () {
              widget.onNavigateTab?.call(3);
            },
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.deepMint,
              backgroundColor: AppColors.pastelMint.withValues(alpha: 0.5),
              side: const BorderSide(color: AppColors.deepMint, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            icon: const Icon(Icons.people_alt_rounded, size: 16),
            label: const Text('Customers', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            onPressed: () {
              widget.onNavigateTab?.call(4);
            },
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.deepCoral,
              backgroundColor: AppColors.pastelCoral.withValues(alpha: 0.5),
              side: const BorderSide(color: AppColors.deepCoral, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            icon: const Icon(Icons.money_off_rounded, size: 16),
            label: const Text('Expenses', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            onPressed: _showAddExpenseDialog,
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.deepLavender,
              backgroundColor: AppColors.pastelLavender.withValues(alpha: 0.5),
              side: const BorderSide(color: AppColors.deepLavender, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Export Period CSV', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            onPressed: () async {
              await CsvExporter.exportBills(filteredBills, filename: 'reconciled_sales_export.csv');
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reconciled Period CSV exported! 📊')));
            },
          ),
        ],
      ),
    );
  }

  // --- 3. 6-CARD SUMMARY KPI GRID ---
  Widget _build6CardKpiGrid({
    required bool isWidescreen,
    required double totalSalesBilled,
    required double cashCollected,
    required double upiCollected,
    required double totalAmountCollected,
    required double outstandingAmount,
    required double customerAdvanceBalance,
    required int billCount,
  }) {
    final cards = [
      _buildMetricCard(
        title: 'TOTAL SALES BILLED',
        value: Formatters.currency(totalSalesBilled),
        subtitle: '$billCount invoices generated',
        icon: Icons.receipt_long_rounded,
        bgColor: AppColors.pastelSky,
        textColor: AppColors.deepSky,
        borderColor: AppColors.borderSky,
      ),
      _buildMetricCard(
        title: 'CASH COLLECTED',
        value: Formatters.currency(cashCollected),
        subtitle: 'Physical cash received',
        icon: Icons.attach_money_rounded,
        bgColor: AppColors.pastelMint,
        textColor: AppColors.deepMint,
        borderColor: AppColors.borderMint,
      ),
      _buildMetricCard(
        title: 'UPI COLLECTED',
        value: Formatters.currency(upiCollected),
        subtitle: 'Digital QR / UPI received',
        icon: Icons.qr_code_2_rounded,
        bgColor: AppColors.pastelSky,
        textColor: AppColors.deepSky,
        borderColor: AppColors.borderSky,
      ),
      _buildMetricCard(
        title: 'TOTAL AMOUNT COLLECTED',
        value: Formatters.currency(totalAmountCollected),
        subtitle: 'Cash + UPI collections',
        icon: Icons.account_balance_wallet_rounded,
        bgColor: AppColors.pastelMint,
        textColor: AppColors.deepMint,
        borderColor: AppColors.borderMint,
      ),
      _buildMetricCard(
        title: 'OUTSTANDING AMOUNT',
        value: Formatters.currency(outstandingAmount),
        subtitle: 'Unpaid dues for period',
        icon: Icons.pending_actions_rounded,
        bgColor: AppColors.pastelCoral,
        textColor: AppColors.deepCoral,
        borderColor: AppColors.borderCoral,
      ),
      _buildMetricCard(
        title: 'CUSTOMER ADVANCE BALANCE',
        value: Formatters.currency(customerAdvanceBalance),
        subtitle: 'Prepaid store credit',
        icon: Icons.credit_score_rounded,
        bgColor: AppColors.pastelAmber,
        textColor: AppColors.deepAmber,
        borderColor: AppColors.borderAmber,
      ),
    ];

    if (isWidescreen) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
              const SizedBox(width: 12),
              Expanded(child: cards[2]),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: cards[3]),
              const SizedBox(width: 12),
              Expanded(child: cards[4]),
              const SizedBox(width: 12),
              Expanded(child: cards[5]),
            ],
          ),
        ],
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.35,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cards,
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: textColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 15, color: textColor),
              ),
            ],
          ),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: textColor)),
          Text(subtitle, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor.withValues(alpha: 0.85))),
        ],
      ),
    );
  }

  // --- 4. PAYMENT ANALYSIS TABLE & NET PROFIT CARD ---
  Widget _buildPaymentAnalysisTable({
    required double cashCollected,
    required double upiCollected,
    required double totalCollected,
  }) {
    final cashPct = totalCollected > 0 ? ((cashCollected / totalCollected) * 100).toStringAsFixed(1) : '0.0';
    final upiPct = totalCollected > 0 ? ((upiCollected / totalCollected) * 100).toStringAsFixed(1) : '0.0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neoBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.table_chart_rounded, color: AppColors.deepSky, size: 20),
              SizedBox(width: 8),
              Text('Payment Analysis Breakdown', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(1.2),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 1.5))),
                children: const [
                  Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textSecondary))),
                  Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Collected', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textSecondary))),
                  Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Share', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textSecondary))),
                ],
              ),
              TableRow(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.attach_money_rounded, size: 16, color: AppColors.deepMint),
                        SizedBox(width: 4),
                        Text('Cash', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  ),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(Formatters.currency(cashCollected), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.deepMint))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('$cashPct%', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
                ],
              ),
              TableRow(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.qr_code_2_rounded, size: 16, color: AppColors.deepSky),
                        SizedBox(width: 4),
                        Text('UPI / QR', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  ),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(Formatters.currency(upiCollected), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.deepSky))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('$upiPct%', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.pastelMint,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderMint),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Collected:', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.deepMint, fontSize: 12.5)),
                Text(Formatters.currency(totalCollected), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.deepMint, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetProfitCard({
    required double totalIncome,
    required double totalExpenses,
    required double netProfit,
  }) {
    final isProfit = netProfit >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neoBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_rounded, color: AppColors.deepMint, size: 20),
                  SizedBox(width: 8),
                  Text('Financial Summary & Profit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.deepCoral,
                  side: const BorderSide(color: AppColors.deepCoral),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Log Expense', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                onPressed: _showAddExpenseDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Income (Collected):', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              Text(Formatters.currency(totalIncome), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.deepMint)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Shop Expenses:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              Text(Formatters.currency(totalExpenses), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.deepCoral)),
            ],
          ),
          const Divider(height: 18, color: AppColors.border),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isProfit ? AppColors.pastelMint : AppColors.pastelCoral,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isProfit ? AppColors.deepMint : AppColors.deepCoral, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isProfit ? 'NET RECONCILED PROFIT' : 'NET LOSS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isProfit ? AppColors.deepMint : AppColors.deepCoral),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.currency(netProfit.abs()),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isProfit ? AppColors.deepMint : AppColors.deepCoral),
                    ),
                  ],
                ),
                Icon(
                  isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  size: 32,
                  color: isProfit ? AppColors.deepMint : AppColors.deepCoral,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. INTERACTIVE ANALYTICS CHARTS ---
  Widget _buildSalesTrendAreaChart(Map<String, double> trendMap) {
    final entries = trendMap.entries.toList();
    final maxVal = entries.fold(100.0, (max, e) => e.value > max ? e.value : max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neoBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.show_chart_rounded, color: AppColors.deepLavender, size: 20),
                  SizedBox(width: 8),
                  Text('Sales Trend (Area Curve)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.pastelLavender, borderRadius: BorderRadius.circular(6)),
                child: const Text('7-Day Window', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.deepLavender)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 170,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxVal * 1.25,
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.toInt();
                        final date = idx >= 0 && idx < entries.length ? entries[idx].key : '';
                        return LineTooltipItem(
                          '$date\n₹${spot.y.toStringAsFixed(0)}',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => const FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                        final parsed = DateTime.tryParse(entries[idx].key);
                        final label = parsed != null ? DateFormat('E').format(parsed) : '';
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(entries.length, (i) => FlSpot(i.toDouble(), entries[i].value)),
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.pastelSky.withValues(alpha: 0.8),
                          AppColors.pastelSky.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodDonutChart({
    required double cashCollected,
    required double upiCollected,
  }) {
    final total = cashCollected + upiCollected;
    final cashPct = total > 0 ? ((cashCollected / total) * 100).round() : 50;
    final upiPct = total > 0 ? ((upiCollected / total) * 100).round() : 50;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neoBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_rounded, color: AppColors.deepMint, size: 20),
              SizedBox(width: 8),
              Text('Payment Method Share', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 32,
                sections: [
                  PieChartSectionData(
                    color: AppColors.deepMint,
                    value: cashCollected > 0 ? cashCollected : 1.0,
                    title: '$cashPct%',
                    radius: 36,
                    titleStyle: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 11),
                  ),
                  PieChartSectionData(
                    color: AppColors.deepSky,
                    value: upiCollected > 0 ? upiCollected : 1.0,
                    title: '$upiPct%',
                    radius: 36,
                    titleStyle: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.deepMint, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text('Cash ($cashPct%)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
              const SizedBox(width: 16),
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.deepSky, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text('UPI ($upiPct%)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
            ],
          ),
        ],
      ),
    );
  }

  // --- 6. RECENT TRANSACTIONS & BILL VIEWER ---
  Widget _buildRecentTransactionsCard(List<BillModel> allBills, AllSettings? settings) {
    final recentBills = allBills.take(8).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neoBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: AppColors.deepSky, size: 20),
                  SizedBox(width: 8),
                  Text('Recent Transactions (Live Feed)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
                ],
              ),
              if (widget.onNavigateTab != null)
                TextButton(
                  onPressed: () => widget.onNavigateTab!(2),
                  child: const Text('View All Invoices →', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (recentBills.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No transactions recorded yet.', style: TextStyle(color: AppColors.textMuted))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentBills.length,
              separatorBuilder: (c, i) => const Divider(height: 14, color: AppColors.border),
              itemBuilder: (ctx, i) {
                final bill = recentBills[i];
                final isUpi = bill.paymentMethod.toUpperCase() == 'UPI';
                final isCash = bill.paymentMethod.toUpperCase() == 'CASH';

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isUpi ? AppColors.pastelSky : (isCash ? AppColors.pastelMint : AppColors.pastelLavender),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isUpi ? Icons.qr_code_2_rounded : (isCash ? Icons.attach_money_rounded : Icons.payment_rounded),
                        size: 18,
                        color: isUpi ? AppColors.deepSky : (isCash ? AppColors.deepMint : AppColors.deepLavender),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${bill.billNumber} • ${bill.customerName ?? "Walk-in Customer"}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${Formatters.parseAndFormatDate(bill.createdAt)} • ${bill.items.length} item(s)',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(Formatters.currency(bill.grandTotal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: AppColors.textPrimary)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isUpi ? AppColors.pastelSky : AppColors.pastelMint,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            bill.paymentMethod,
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: isUpi ? AppColors.deepSky : AppColors.deepMint),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pastelLavender,
                        foregroundColor: AppColors.deepLavender,
                        elevation: 0,
                        side: const BorderSide(color: AppColors.deepLavender),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.visibility_rounded, size: 14),
                      label: const Text('View / Print', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      onPressed: () {
                        if (settings != null) {
                          InvoiceModal.show(context, bill: bill, settings: settings);
                        }
                      },
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}