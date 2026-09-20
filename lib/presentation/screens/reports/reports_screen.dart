import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/core/utils/csv_exporter.dart';
import 'package:simplebilling_mobile/core/utils/whatsapp_sender.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/presentation/shared/printing/receipt_generator.dart';
import 'package:simplebilling_mobile/presentation/shared/widgets/invoice_modal.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

enum ReportDateRangePreset {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  quarter,
  financialYear,
  custom,
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ReportDateRangePreset _selectedPreset = ReportDateRangePreset.thisMonth;
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTimeRange _getDateRangeForFilter() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (_selectedPreset) {
      case ReportDateRangePreset.today:
        return DateTimeRange(start: todayStart, end: todayEnd);

      case ReportDateRangePreset.yesterday:
        final yest = now.subtract(const Duration(days: 1));
        final yestStart = DateTime(yest.year, yest.month, yest.day);
        final yestEnd = DateTime(yest.year, yest.month, yest.day, 23, 59, 59, 999);
        return DateTimeRange(start: yestStart, end: yestEnd);

      case ReportDateRangePreset.thisWeek:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(
          start: DateTime(weekStart.year, weekStart.month, weekStart.day),
          end: todayEnd,
        );

      case ReportDateRangePreset.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: todayEnd,
        );

      case ReportDateRangePreset.quarter:
        final qMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return DateTimeRange(
          start: DateTime(now.year, qMonth, 1),
          end: todayEnd,
        );

      case ReportDateRangePreset.financialYear:
        final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
        return DateTimeRange(
          start: DateTime(fyStartYear, 4, 1),
          end: todayEnd,
        );

      case ReportDateRangePreset.custom:
        return _customDateRange ?? DateTimeRange(start: todayStart, end: todayEnd);
    }
  }

  bool _isBillInRange(BillModel bill, DateTimeRange range) {
    if (bill.createdAt.isEmpty) return false;
    final parsed = DateTime.tryParse(bill.createdAt);
    if (parsed == null) return false;
    return (parsed.isAfter(range.start) || parsed.isAtSameMomentAs(range.start)) &&
        (parsed.isBefore(range.end) || parsed.isAtSameMomentAs(range.end));
  }

  String _getPresetLabel(ReportDateRangePreset preset) {
    switch (preset) {
      case ReportDateRangePreset.today:
        return 'Today';
      case ReportDateRangePreset.yesterday:
        return 'Yesterday';
      case ReportDateRangePreset.thisWeek:
        return 'This Week';
      case ReportDateRangePreset.thisMonth:
        return 'This Month';
      case ReportDateRangePreset.quarter:
        return 'Quarter';
      case ReportDateRangePreset.financialYear:
        return 'Financial Year';
      case ReportDateRangePreset.custom:
        return 'Custom';
    }
  }

  String _getPeriodTitleString() {
    final range = _getDateRangeForFilter();
    final fmt = DateFormat('dd MMM yyyy');
    if (_selectedPreset == ReportDateRangePreset.today) {
      return 'Today (${fmt.format(range.start)})';
    } else if (_selectedPreset == ReportDateRangePreset.yesterday) {
      return 'Yesterday (${fmt.format(range.start)})';
    }
    return '${_getPresetLabel(_selectedPreset)}: ${fmt.format(range.start)} - ${fmt.format(range.end)}';
  }

  List<Map<String, dynamic>> _computeItemSales(List<BillModel> bills) {
    final Map<String, double> itemQty = {};
    final Map<String, double> itemRevenue = {};

    for (final bill in bills) {
      for (final it in bill.items) {
        final name = it.productName.trim().isNotEmpty ? it.productName.trim() : 'Item';
        itemQty[name] = (itemQty[name] ?? 0.0) + it.quantity;
        itemRevenue[name] = (itemRevenue[name] ?? 0.0) + (it.unitPrice * it.quantity);
      }
    }

    final totalRev = itemRevenue.values.fold(0.0, (s, r) => s + r);

    final List<Map<String, dynamic>> list = itemRevenue.entries.map((e) {
      final rev = e.value;
      final qty = itemQty[e.key] ?? 0.0;
      final share = totalRev > 0 ? (rev / totalRev) * 100 : 0.0;
      return {
        'name': e.key,
        'qty': qty,
        'revenue': rev,
        'share': share,
      };
    }).toList();

    // Sort descending by revenue
    list.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
    return list;
  }

  Future<void> _handleCsvExport(
    List<BillModel> filteredBills,
    List<Map<String, dynamic>> itemSales,
    List<CustomerModel> dueCustomers,
  ) async {
    final dateTag = DateFormat('yyyyMMdd').format(DateTime.now());
    final periodTag = _selectedPreset.name;

    if (_tabController.index == 0) {
      await CsvExporter.exportBills(
        filteredBills,
        filename: 'Sales_Report_${periodTag}_$dateTag.csv',
      );
    } else if (_tabController.index == 1) {
      await CsvExporter.exportItemSales(
        itemSales,
        filename: 'Item_Sales_Report_${periodTag}_$dateTag.csv',
      );
    } else {
      await CsvExporter.exportCustomerDues(
        dueCustomers,
        filename: 'Customer_Due_List_$dateTag.csv',
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV report generated and shared! 📊')),
    );
  }

  Future<void> _handlePrintReport(
    List<BillModel> filteredBills,
    List<Map<String, dynamic>> itemSales,
    List<CustomerModel> dueCustomers,
    ShopSettings shop,
    BillingSettings billing,
  ) async {
    final periodTitle = _getPeriodTitleString();

    if (_tabController.index == 0) {
      await ReceiptGenerator.printSalesReport(
        bills: filteredBills,
        shop: shop,
        billing: billing,
        periodTitle: periodTitle,
      );
    } else if (_tabController.index == 1) {
      final totalRev = itemSales.fold(0.0, (s, i) => s + ((i['revenue'] as num?)?.toDouble() ?? 0.0));
      await ReceiptGenerator.printItemSalesReport(
        itemSales: itemSales,
        shop: shop,
        billing: billing,
        periodTitle: periodTitle,
        totalPeriodRevenue: totalRev,
      );
    } else {
      final totalDue = dueCustomers.fold(0.0, (s, c) => s + c.balanceDue);
      await ReceiptGenerator.printCustomerDuesReport(
        dueCustomers: dueCustomers,
        shop: shop,
        billing: billing,
        totalUncollectedDues: totalDue,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(billsListProvider);
    final customersAsync = ref.watch(customersProvider);
    final settingsAsync = ref.watch(settingsProvider);

    final allSettings = settingsAsync.valueOrNull ??
        AllSettings(
          shop: ShopSettings(),
          billing: BillingSettings(),
          loyalty: LoyaltySettings(),
        );
    final shop = allSettings.shop;
    final billing = allSettings.billing;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Reports & Analytics',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Print / PDF Button
          IconButton(
            tooltip: 'Print Report / PDF',
            icon: const Icon(Icons.print_rounded, color: AppColors.primary),
            onPressed: () {
              final bills = billsAsync.valueOrNull ?? [];
              final customers = customersAsync.valueOrNull ?? [];
              final range = _getDateRangeForFilter();
              final filteredBills = bills.where((b) => _isBillInRange(b, range)).toList();
              final itemSales = _computeItemSales(filteredBills);
              final dueCustomers = customers.where((c) => c.balanceDue > 0).toList();

              _handlePrintReport(filteredBills, itemSales, dueCustomers, shop, billing);
            },
          ),
          // CSV Export Button
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.download_rounded, color: AppColors.deepLavender),
            onPressed: () {
              final bills = billsAsync.valueOrNull ?? [];
              final customers = customersAsync.valueOrNull ?? [];
              final range = _getDateRangeForFilter();
              final filteredBills = bills.where((b) => _isBillInRange(b, range)).toList();
              final itemSales = _computeItemSales(filteredBills);
              final dueCustomers = customers.where((c) => c.balanceDue > 0).toList();

              _handleCsvExport(filteredBills, itemSales, dueCustomers);
            },
          ),
          // Refresh Button
          IconButton(
            tooltip: 'Refresh Reports',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: () {
              ref.invalidate(billsListProvider);
              ref.invalidate(customersProvider);
              ref.invalidate(settingsProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.deepLavender,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.deepLavender,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Sales & Bills'),
            Tab(text: 'Product / Item Sales'),
            Tab(text: 'Customer Due List'),
          ],
        ),
      ),
      body: billsAsync.when(
        data: (allBills) {
          final customers = customersAsync.valueOrNull ?? [];
          final range = _getDateRangeForFilter();
          final filteredBills = allBills.where((b) => _isBillInRange(b, range)).toList();

          // Recalculate 6 KPI Metrics
          final totalSales = filteredBills.fold(0.0, (sum, b) => sum + b.grandTotal);
          final cashPaid = filteredBills.fold(0.0, (sum, b) => sum + b.cashPaid);
          final upiPaid = filteredBills.fold(0.0, (sum, b) => sum + b.upiPaid);
          final pendingBalance = (totalSales - (cashPaid + upiPaid)).clamp(0.0, double.infinity);
          final avgBillValue = filteredBills.isNotEmpty ? totalSales / filteredBills.length : 0.0;
          final totalDuesAll = customers.fold(0.0, (sum, c) => sum + c.balanceDue);

          final itemSales = _computeItemSales(filteredBills);
          final dueCustomers = customers.where((c) => c.balanceDue > 0).toList();

          return Column(
            children: [
              // 1. Date Range Auditing & Filters
              _buildDateFilterBar(),

              // 2. Multi-Metric Financial Strip (6 KPI Cards)
              _buildFinancialStrip(
                totalSales: totalSales,
                billsCount: filteredBills.length,
                cashPaid: cashPaid,
                upiPaid: upiPaid,
                pendingBalance: pendingBalance,
                avgBillValue: avgBillValue,
                totalDuesAll: totalDuesAll,
              ),

              // 3. Report Section Views (3 Specialized Tabs)
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Sales & Invoices Report
                    _buildSalesBillsTab(filteredBills, allSettings),

                    // Tab 2: Product & Service Sales Breakdown
                    _buildItemSalesTab(itemSales, totalSales),

                    // Tab 3: Customer Outstanding Dues List
                    _buildCustomerDuesTab(dueCustomers, totalDuesAll, shop, billing),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, s) => Center(child: Text('Error loading reports: $err', style: const TextStyle(color: AppColors.textSecondary))),
      ),
    );
  }

  // --- 1. Date Range Bar ---
  Widget _buildDateFilterBar() {
    final range = _getDateRangeForFilter();
    final fmt = DateFormat('dd/MM/yyyy');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ReportDateRangePreset.values.map((preset) {
                final isSelected = _selectedPreset == preset;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(
                      _getPresetLabel(preset),
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 12,
                        color: isSelected ? AppColors.deepLavender : AppColors.textSecondary,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) async {
                      if (selected) {
                        if (preset == ReportDateRangePreset.custom) {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            initialDateRange: _customDateRange ?? DateTimeRange(
                              start: DateTime.now().subtract(const Duration(days: 7)),
                              end: DateTime.now(),
                            ),
                          );
                          if (picked != null) {
                            setState(() {
                              _customDateRange = picked;
                              _selectedPreset = ReportDateRangePreset.custom;
                            });
                          }
                        } else {
                          setState(() {
                            _selectedPreset = preset;
                          });
                        }
                      }
                    },
                    backgroundColor: AppColors.background,
                    selectedColor: AppColors.pastelLavender,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? AppColors.deepLavender : AppColors.border,
                        width: 1.2,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_selectedPreset == ReportDateRangePreset.custom) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  initialDateRange: _customDateRange ?? DateTimeRange(
                    start: DateTime.now().subtract(const Duration(days: 7)),
                    end: DateTime.now(),
                  ),
                );
                if (picked != null) {
                  setState(() {
                    _customDateRange = picked;
                  });
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.pastelLavender.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.deepLavender, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.date_range_rounded, size: 16, color: AppColors.deepLavender),
                    const SizedBox(width: 6),
                    Text(
                      'Custom Accounting Window: ${fmt.format(range.start)} - ${fmt.format(range.end)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.deepLavender),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.edit_rounded, size: 14, color: AppColors.deepLavender),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- 2. Multi-Metric Financial Strip (6 KPI Cards) ---
  Widget _buildFinancialStrip({
    required double totalSales,
    required int billsCount,
    required double cashPaid,
    required double upiPaid,
    required double pendingBalance,
    required double avgBillValue,
    required double totalDuesAll,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final isWide = constraints.maxWidth > 700;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildKpiCard(
                width: isWide ? (constraints.maxWidth - 40) / 6 : (constraints.maxWidth - 16) / 2,
                title: 'Total Sales',
                value: Formatters.currency(totalSales),
                subtitle: '$billsCount Bills',
                icon: Icons.point_of_sale_rounded,
                bgColor: AppColors.pastelMint,
                textColor: AppColors.deepMint,
                borderColor: AppColors.borderMint,
              ),
              _buildKpiCard(
                width: isWide ? (constraints.maxWidth - 40) / 6 : (constraints.maxWidth - 16) / 2,
                title: 'Cash Paid',
                value: Formatters.currency(cashPaid),
                subtitle: 'Physical Cash',
                icon: Icons.payments_rounded,
                bgColor: AppColors.pastelSky,
                textColor: AppColors.deepSky,
                borderColor: AppColors.borderSky,
              ),
              _buildKpiCard(
                width: isWide ? (constraints.maxWidth - 40) / 6 : (constraints.maxWidth - 16) / 2,
                title: 'UPI Paid',
                value: Formatters.currency(upiPaid),
                subtitle: 'Digital QR',
                icon: Icons.qr_code_2_rounded,
                bgColor: AppColors.pastelLavender,
                textColor: AppColors.deepLavender,
                borderColor: AppColors.borderLavender,
              ),
              _buildKpiCard(
                width: isWide ? (constraints.maxWidth - 40) / 6 : (constraints.maxWidth - 16) / 2,
                title: 'Pending Balance',
                value: Formatters.currency(pendingBalance),
                subtitle: 'Period Dues',
                icon: Icons.hourglass_top_rounded,
                bgColor: AppColors.pastelCoral,
                textColor: AppColors.deepCoral,
                borderColor: AppColors.borderCoral,
              ),
              _buildKpiCard(
                width: isWide ? (constraints.maxWidth - 40) / 6 : (constraints.maxWidth - 16) / 2,
                title: 'Avg Bill Value',
                value: Formatters.currency(avgBillValue),
                subtitle: 'Mean Transaction',
                icon: Icons.analytics_rounded,
                bgColor: AppColors.pastelAmber,
                textColor: AppColors.deepAmber,
                borderColor: AppColors.borderAmber,
              ),
              _buildKpiCard(
                width: isWide ? (constraints.maxWidth - 40) / 6 : (constraints.maxWidth - 16) / 2,
                title: 'Total Dues (All)',
                value: Formatters.currency(totalDuesAll),
                subtitle: 'Store Debt',
                icon: Icons.account_balance_wallet_rounded,
                bgColor: AppColors.pastelPink,
                textColor: AppColors.deepPink,
                borderColor: AppColors.borderPink,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpiCard({
    required double width,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
    required Color borderColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowLight, offset: Offset(2, 2), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  color: textColor,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(icon, size: 14, color: textColor),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 9.5,
              color: textColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  // --- Tab 1: Sales & Invoices Report ---
  Widget _buildSalesBillsTab(List<BillModel> bills, AllSettings settings) {
    if (bills.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.border),
            SizedBox(height: 8),
            Text('No invoices issued in this period', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;

        if (isDesktop) {
          // Table layout for desktop
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: AppColors.shadowLight, offset: Offset(3, 3), blurRadius: 0),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: DataTable(
                  columnSpacing: 16,
                  headingRowColor: WidgetStateProperty.all(AppColors.background),
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 12),
                  dataTextStyle: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  columns: const [
                    DataColumn(label: Text('Bill No')),
                    DataColumn(label: Text('Date & Time')),
                    DataColumn(label: Text('Customer Name')),
                    DataColumn(label: Text('Payment Method')),
                    DataColumn(label: Text('Cash (₹)'), numeric: true),
                    DataColumn(label: Text('UPI (₹)'), numeric: true),
                    DataColumn(label: Text('Total (₹)'), numeric: true),
                    DataColumn(label: Text('Status Badge')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: bills.map((b) {
                    final isFullyPaid = b.balanceDue <= 0;
                    return DataRow(
                      cells: [
                        DataCell(Text(b.billNumber, style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'monospace'))),
                        DataCell(Text(Formatters.parseAndFormatDate(b.createdAt))),
                        DataCell(Text(b.customerName ?? 'Walk-in', style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.pastelLavender.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(b.paymentMethod, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        DataCell(Text(Formatters.currency(b.cashPaid))),
                        DataCell(Text(Formatters.currency(b.upiPaid))),
                        DataCell(Text(Formatters.currency(b.grandTotal), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isFullyPaid ? AppColors.pastelMint : AppColors.pastelCoral,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isFullyPaid ? AppColors.deepMint : AppColors.deepCoral, width: 1),
                            ),
                            child: Text(
                              isFullyPaid ? 'Fully Paid' : 'Pending',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 10.5,
                                color: isFullyPaid ? AppColors.deepMint : AppColors.deepCoral,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.remove_red_eye_rounded, size: 18, color: AppColors.deepLavender),
                            tooltip: 'View Invoice',
                            onPressed: () => InvoiceModal.show(context, bill: b, settings: settings),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        }

        // Card list layout for mobile
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          itemCount: bills.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
          itemBuilder: (ctx, idx) {
            final b = bills[idx];
            final isFullyPaid = b.balanceDue <= 0;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: AppColors.shadowLight, offset: Offset(2, 2), blurRadius: 0),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            b.billNumber,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, fontFamily: 'monospace'),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isFullyPaid ? AppColors.pastelMint : AppColors.pastelCoral,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isFullyPaid ? 'Fully Paid' : 'Pending',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                color: isFullyPaid ? AppColors.deepMint : AppColors.deepCoral,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        Formatters.currency(b.grandTotal),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${b.customerName ?? 'Walk-in'} • ${Formatters.parseAndFormatDate(b.createdAt)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.remove_red_eye_rounded, size: 18, color: AppColors.deepLavender),
                        tooltip: 'View Invoice',
                        onPressed: () => InvoiceModal.show(context, bill: b, settings: settings),
                      ),
                    ],
                  ),
                  const Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Method: ${b.paymentMethod}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      Text('Cash: ${Formatters.currency(b.cashPaid)}  |  UPI: ${Formatters.currency(b.upiPaid)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Tab 2: Product & Service Sales Breakdown ---
  Widget _buildItemSalesTab(List<Map<String, dynamic>> items, double totalRevenue) {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_rounded, size: 48, color: AppColors.border),
            SizedBox(height: 8),
            Text('No product/service sales in this period', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    final totalUnits = items.fold(0.0, (s, i) => s + ((i['qty'] as num?)?.toDouble() ?? 0.0));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      children: [
        // Summary banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.pastelSky,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSky, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL REVENUE FROM ITEMS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: AppColors.deepSky, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(Formatters.currency(totalRevenue), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.deepSky)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('TOTAL UNITS SOLD', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: AppColors.deepSky, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text('${totalUnits.toStringAsFixed(0)} Units (${items.length} Products)', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.deepSky)),
                ],
              ),
            ],
          ),
        ),

        // Items list sorted by revenue
        ...items.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final it = entry.value;
          final name = it['name'] as String;
          final qty = (it['qty'] as num?)?.toDouble() ?? 0.0;
          final revenue = (it['revenue'] as num?)?.toDouble() ?? 0.0;
          final share = (it['share'] as num?)?.toDouble() ?? 0.0;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 1.5),
              boxShadow: const [
                BoxShadow(color: AppColors.shadowLight, offset: Offset(2, 2), blurRadius: 0),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: idx <= 3 ? AppColors.pastelMint : AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: idx <= 3 ? AppColors.deepMint : AppColors.border),
                          ),
                          child: Text(
                            '#$idx',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                              color: idx <= 3 ? AppColors.deepMint : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                      ],
                    ),
                    Text(
                      Formatters.currency(revenue),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quantity Sold: ${qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2)} units',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Revenue Share: ${share.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.deepLavender),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (share / 100).clamp(0.0, 1.0),
                    backgroundColor: AppColors.background,
                    valueColor: AlwaysStoppedAnimation<Color>(idx <= 3 ? AppColors.deepMint : AppColors.deepLavender),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // --- Tab 3: Customer Outstanding Dues List ---
  Widget _buildCustomerDuesTab(
    List<CustomerModel> dueCustomers,
    double totalDue,
    ShopSettings shop,
    BillingSettings billing,
  ) {
    return Column(
      children: [
        // Total Uncollected Dues Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.pastelCoral,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.deepCoral, width: 1.5),
            boxShadow: const [
              BoxShadow(color: AppColors.shadowLight, offset: Offset(2, 2), blurRadius: 0),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL UNCOLLECTED STORE DUES',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 10.5,
                      color: AppColors.deepCoral,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.currency(totalDue),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: AppColors.deepCoral,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.deepCoral, width: 1),
                ),
                child: Text(
                  '${dueCustomers.length} Accounts Due',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.deepCoral),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: dueCustomers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 48, color: AppColors.deepMint),
                      SizedBox(height: 8),
                      Text('No pending customer dues! All balances cleared 🎉', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.deepMint)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  itemCount: dueCustomers.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final cust = dueCustomers[idx];

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: AppColors.shadowLight, offset: Offset(2, 2), blurRadius: 0),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                cust.name,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.pastelCoral,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.deepCoral, width: 1),
                                ),
                                child: Text(
                                  'Due: ${Formatters.currency(cust.balanceDue)}',
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.deepCoral, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Mobile: ${cust.mobile ?? '-'}  •  Email: ${cust.email ?? '-'}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Billed: ${Formatters.currency(cust.totalBilled)} | Paid: ${Formatters.currency(cust.totalPaid)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                              // WhatsApp Reminder Action
                              if (cust.mobile != null && cust.mobile!.isNotEmpty)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                                  label: const Text('Remind', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                  onPressed: () async {
                                    final sent = await WhatsAppSender.sendPaymentReminder(
                                      customer: cust,
                                      shop: shop,
                                      billing: billing,
                                    );
                                    if (!context.mounted) return;
                                    if (sent) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('WhatsApp reminder sent to ${cust.name}! 💬')),
                                      );
                                    }
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
