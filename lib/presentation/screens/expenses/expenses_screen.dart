import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/network/sync_queue_manager.dart';
import 'package:simplebilling_mobile/core/network/sync_task_model.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/core/utils/csv_exporter.dart';
import 'package:simplebilling_mobile/data/models/expense_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';
import 'package:simplebilling_mobile/presentation/shared/widgets/sync_status_badge.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

enum ExpenseDateRange { allTime, today, week, month, year, financialYear, custom }

final defaultExpenseCategories = [
  'Shop Expense',
  'Electricity',
  'Rent',
  'Paper Stock & Rolls',
  'Toner & Inks',
  'Salaries & Wages',
  'Maintenance & Repairs',
  'Tea & Refreshments',
  'Other Expense',
];

final paymentModesList = [
  'All',
  'Cash',
  'UPI',
  'Bank Transfer',
  'Card',
  'Cheque',
  'Other',
];

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchTerm = '';
  String _selectedCategory = 'All';
  String _selectedPaymentMode = 'All';
  ExpenseDateRange _selectedRange = ExpenseDateRange.month;
  DateTimeRange? _customDateRange;
  bool _isChartViewDonut = true; // true = Donut Chart, false = Bar Chart

  List<String> _customCategories = [];

  @override
  void initState() {
    super.initState();
    _customCategories = List.from(defaultExpenseCategories);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  DateTimeRange _getDateRangeForFilter() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (_selectedRange) {
      case ExpenseDateRange.allTime:
        return DateTimeRange(start: DateTime(2020), end: todayEnd);
      case ExpenseDateRange.today:
        return DateTimeRange(start: todayStart, end: todayEnd);
      case ExpenseDateRange.week:
        final weekStart = now.subtract(const Duration(days: 6));
        return DateTimeRange(start: DateTime(weekStart.year, weekStart.month, weekStart.day), end: todayEnd);
      case ExpenseDateRange.month:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: todayEnd);
      case ExpenseDateRange.year:
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: todayEnd);
      case ExpenseDateRange.financialYear:
        final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
        return DateTimeRange(start: DateTime(fyStartYear, 4, 1), end: todayEnd);
      case ExpenseDateRange.custom:
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

  SyncStatus _getExpenseSyncStatus(
    String? clientRef,
    String id,
    List<SyncTask> tasks,
  ) {
    for (final task in tasks) {
      if (task.action == 'create_expense') {
        if ((clientRef != null && task.clientRef == clientRef) ||
            task.id == id ||
            task.clientRef == id) {
          return task.status;
        }
      }
    }
    return SyncStatus.synced;
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'electricity':
        return Icons.bolt_rounded;
      case 'rent':
        return Icons.home_work_rounded;
      case 'paper stock & rolls':
      case 'paper stock':
        return Icons.layers_rounded;
      case 'toner & inks':
      case 'toner':
        return Icons.print_rounded;
      case 'salaries & wages':
      case 'wages':
        return Icons.badge_rounded;
      case 'maintenance & repairs':
      case 'maintenance':
        return Icons.build_rounded;
      case 'tea & refreshments':
        return Icons.local_cafe_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  void _showRecordExpenseDialog() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = _customCategories.first;
    String paymentMode = 'Cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.pastelCoral,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.deepCoral),
                ),
                child: const Icon(Icons.money_off_rounded, color: AppColors.deepCoral, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Record Shop Expense', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Expense Description *',
                    hintText: 'e.g. Purchased 5 Reams A4 75 GSM Paper',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Expense Category *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _customCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => category = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹) *',
                    hintText: 'e.g. 1250.00',
                    prefixIcon: Icon(Icons.currency_rupee, size: 18, color: AppColors.deepCoral),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: paymentMode,
                  decoration: const InputDecoration(
                    labelText: 'Payment Channel *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: ['Cash', 'UPI', 'Bank Transfer', 'Card', 'Cheque', 'Other']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => paymentMode = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Receipt No. / Vendor Remarks (Optional)',
                    hintText: 'e.g. Inv #8812 from Star Paper Mills',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepCoral,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                final notes = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();

                if (title.isEmpty || amount <= 0) return;

                final created = await ApiRepository.createExpense(
                  title,
                  amount,
                  category,
                  paymentMode: paymentMode,
                  notes: notes,
                );

                if (created == null) {
                  final clientRef = const Uuid().v4();
                  await SyncQueueManager.instance.enqueueTask('create_expense', {
                    'client_ref': clientRef,
                    'title': title,
                    'amount': amount,
                    'category': category,
                    'payment_mode': paymentMode,
                    'notes': notes,
                  }, clientRef: clientRef);
                }

                if (mounted) {
                  ref.invalidate(expensesListProvider);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Expense of ₹${amount.toStringAsFixed(2)} logged! 💸')),
                  );
                }
              },
              child: const Text('Record Expense'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryManagerDialog() {
    final newCatCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.category_rounded, color: AppColors.deepLavender),
              SizedBox(width: 8),
              Text('Manage Expense Categories', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: newCatCtrl,
                        decoration: const InputDecoration(
                          hintText: 'New category (e.g. Hardware)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      onPressed: () {
                        final val = newCatCtrl.text.trim();
                        if (val.isNotEmpty && !_customCategories.contains(val)) {
                          setState(() {
                            _customCategories.add(val);
                          });
                          setModalState(() {});
                          newCatCtrl.clear();
                        }
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _customCategories.length,
                    separatorBuilder: (_, __) => const Divider(height: 10),
                    itemBuilder: (c, i) {
                      final cat = _customCategories[i];
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(cat, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          if (_customCategories.length > 1)
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.deepCoral),
                              onPressed: () {
                                setState(() {
                                  _customCategories.removeAt(i);
                                });
                                setModalState(() {});
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Done')),
          ],
        ),
      ),
    );
  }

  void _showDeleteSafeguardDialog(ExpenseModel expense) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Expense Record', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to remove "${expense.title}" (₹${expense.amount.toStringAsFixed(2)})?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepCoral, foregroundColor: Colors.white),
            onPressed: () async {
              await ApiRepository.deleteExpense(expense.id);
              if (mounted) {
                ref.invalidate(expensesListProvider);
                if (ctx.mounted) Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense record deleted.')));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesListProvider);
    final billsAsync = ref.watch(billsListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Simple Accounting & Expenses',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary),
            ),
            Text(
              'Expenditure tracking, payment channels, and net profit analytics',
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
            tooltip: 'Manage Categories',
            icon: const Icon(Icons.category_rounded, color: AppColors.deepLavender),
            onPressed: _showCategoryManagerDialog,
          ),
          IconButton(
            tooltip: 'Export Expenses CSV',
            icon: const Icon(Icons.download_rounded, color: AppColors.deepSky),
            onPressed: () async {
              final activeRange = _getDateRangeForFilter();
              final allExpenses = expensesAsync.valueOrNull ?? [];
              final filtered = allExpenses.where((e) => _isDateInRange(e.date, activeRange)).toList();
              await CsvExporter.exportExpenses(filtered, filename: 'Expenses_Report_${_selectedRange.name}.csv');
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expenses CSV downloaded! 📊')));
            },
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: () => ref.invalidate(expensesListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.deepCoral,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: const Text('+ Record Expense', style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: _showRecordExpenseDialog,
      ),
      body: expensesAsync.when(
        data: (allExpenses) {
          final allBills = billsAsync.valueOrNull ?? [];
          final activeRange = _getDateRangeForFilter();

          // 1. Period Filtering
          final filteredExpenses = allExpenses.where((e) => _isDateInRange(e.date, activeRange)).toList();
          final filteredBills = allBills.where((b) => _isDateInRange(b.createdAt, activeRange)).toList();

          // Search and Category/Payment Mode filter
          final displayExpenses = filteredExpenses.where((e) {
            final matchesCat = _selectedCategory == 'All' || e.category.toLowerCase() == _selectedCategory.toLowerCase();
            final matchesMode = _selectedPaymentMode == 'All' || e.paymentMode.toLowerCase() == _selectedPaymentMode.toLowerCase();
            if (!matchesCat || !matchesMode) return false;

            if (_searchTerm.isEmpty) return true;
            final q = _searchTerm.toLowerCase();
            return e.title.toLowerCase().contains(q) ||
                (e.expenseNumber != null && e.expenseNumber!.toLowerCase().contains(q)) ||
                (e.notes != null && e.notes!.toLowerCase().contains(q)) ||
                e.category.toLowerCase().contains(q);
          }).toList();

          // 2. Financial Metrics Calculations
          final totalSalesIncome = filteredBills.fold(0.0, (sum, b) => sum + b.paidTotal);
          final totalExpensesAmount = filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);
          final netProfit = totalSalesIncome - totalExpensesAmount;

          // 3. Category Breakdown for Charts
          final categoryBreakdown = <String, double>{};
          for (final e in filteredExpenses) {
            categoryBreakdown[e.category] = (categoryBreakdown[e.category] ?? 0.0) + e.amount;
          }

          // Top Category
          String topCategoryName = 'None';
          double topCategoryAmount = 0.0;
          categoryBreakdown.forEach((cat, amt) {
            if (amt > topCategoryAmount) {
              topCategoryAmount = amt;
              topCategoryName = cat;
            }
          });

          // Payment Channel Breakdown
          final paymentModeTotals = <String, double>{};
          for (final e in filteredExpenses) {
            paymentModeTotals[e.paymentMode] = (paymentModeTotals[e.paymentMode] ?? 0.0) + e.amount;
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(expensesListProvider);
              ref.invalidate(billsListProvider);
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Time-Period Filters
                  _buildDateFilterRow(context),
                  const SizedBox(height: 12),

                  // 2. Financial P&L KPI Cards
                  _buildPnlMetricsRow(
                    totalIncome: totalSalesIncome,
                    totalExpenses: totalExpensesAmount,
                    netProfit: netProfit,
                  ),
                  const SizedBox(height: 14),

                  // 3. Visual Analytics (Dual View Chart + Payment Mode Breakdown)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 800;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildChartCard(categoryBreakdown, totalExpensesAmount),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 2,
                              child: _buildPaymentChannelsCard(
                                paymentModeTotals: paymentModeTotals,
                                totalExpenses: totalExpensesAmount,
                                topCategory: topCategoryName,
                                topCategoryAmount: topCategoryAmount,
                              ),
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          _buildChartCard(categoryBreakdown, totalExpensesAmount),
                          const SizedBox(height: 14),
                          _buildPaymentChannelsCard(
                            paymentModeTotals: paymentModeTotals,
                            totalExpenses: totalExpensesAmount,
                            topCategory: topCategoryName,
                            topCategoryAmount: topCategoryAmount,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // 4. Search & Multi-Criteria Filtering
                  _buildSearchAndFilterControls(),
                  const SizedBox(height: 12),

                  // 5. Shop Expense Log Feed
                  _buildExpenseLogFeed(displayExpenses),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Error loading expenses: $err')),
      ),
    );
  }

  // --- TIME-PERIOD FILTERS ---
  Widget _buildDateFilterRow(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('All Time', ExpenseDateRange.allTime),
          const SizedBox(width: 6),
          _buildFilterChip('Today', ExpenseDateRange.today),
          const SizedBox(width: 6),
          _buildFilterChip('This Week', ExpenseDateRange.week),
          const SizedBox(width: 6),
          _buildFilterChip('This Month', ExpenseDateRange.month),
          const SizedBox(width: 6),
          _buildFilterChip('This Year', ExpenseDateRange.year),
          const SizedBox(width: 6),
          _buildFilterChip('FY (Apr-Mar)', ExpenseDateRange.financialYear),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.date_range_rounded, size: 16, color: AppColors.deepLavender),
            label: Text(
              _selectedRange == ExpenseDateRange.custom && _customDateRange != null
                  ? '${DateFormat('dd MMM').format(_customDateRange!.start)} - ${DateFormat('dd MMM').format(_customDateRange!.end)}'
                  : 'Custom Date',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.deepLavender),
            ),
            backgroundColor: _selectedRange == ExpenseDateRange.custom ? AppColors.pastelLavender : Colors.white,
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
                  _selectedRange = ExpenseDateRange.custom;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, ExpenseDateRange range) {
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

  // --- 1. FINANCIAL P&L KPI CARDS ---
  Widget _buildPnlMetricsRow({
    required double totalIncome,
    required double totalExpenses,
    required double netProfit,
  }) {
    final isProfit = netProfit >= 0;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'TOTAL INCOME (SALES)',
            value: Formatters.currency(totalIncome),
            subtitle: 'Collected revenues',
            icon: Icons.payments_rounded,
            bgColor: AppColors.pastelSky,
            textColor: AppColors.deepSky,
            borderColor: AppColors.borderSky,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            title: 'TOTAL EXPENSES',
            value: Formatters.currency(totalExpenses),
            subtitle: 'Operational costs',
            icon: Icons.money_off_rounded,
            bgColor: AppColors.pastelCoral,
            textColor: AppColors.deepCoral,
            borderColor: AppColors.borderCoral,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            title: isProfit ? 'NET PROFIT' : 'NET LOSS',
            value: Formatters.currency(netProfit.abs()),
            subtitle: isProfit ? 'Operating Surplus ✓' : 'Operating Deficit ⚠️',
            icon: isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            bgColor: isProfit ? AppColors.pastelMint : AppColors.pastelCoral,
            textColor: isProfit ? AppColors.deepMint : AppColors.deepCoral,
            borderColor: isProfit ? AppColors.borderMint : AppColors.borderCoral,
          ),
        ),
      ],
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
                child: Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: textColor), overflow: TextOverflow.ellipsis),
              ),
              Icon(icon, size: 16, color: textColor),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.5, color: textColor)),
          Text(subtitle, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor.withValues(alpha: 0.85))),
        ],
      ),
    );
  }

  // --- 3. DUAL VIEW CHART CARD ---
  Widget _buildChartCard(Map<String, double> categoryBreakdown, double totalExpenses) {
    final entries = categoryBreakdown.entries.toList();
    final colors = [
      AppColors.deepCoral,
      AppColors.deepSky,
      AppColors.deepAmber,
      AppColors.deepLavender,
      AppColors.deepMint,
      AppColors.primary,
    ];

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
                  Icon(Icons.pie_chart_rounded, color: AppColors.deepLavender, size: 20),
                  SizedBox(width: 8),
                  Text('Expenditure by Category', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
                ],
              ),
              // View Toggle
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.pie_chart_outline_rounded, color: _isChartViewDonut ? AppColors.primary : AppColors.textSecondary, size: 20),
                    tooltip: 'Donut Chart View',
                    onPressed: () => setState(() => _isChartViewDonut = true),
                  ),
                  IconButton(
                    icon: Icon(Icons.bar_chart_rounded, color: !_isChartViewDonut ? AppColors.primary : AppColors.textSecondary, size: 20),
                    tooltip: 'Bar Chart View',
                    onPressed: () => setState(() => _isChartViewDonut = false),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: Text('No expenses recorded for this period', style: TextStyle(color: AppColors.textMuted))),
            )
          else if (_isChartViewDonut)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 160,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 32,
                        sections: List.generate(entries.length, (i) {
                          final pct = totalExpenses > 0 ? (entries[i].value / totalExpenses) * 100 : 0.0;
                          return PieChartSectionData(
                            color: colors[i % colors.length],
                            value: entries[i].value,
                            title: '${pct.toStringAsFixed(0)}%',
                            radius: 38,
                            titleStyle: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 11),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: entries.length > 4 ? 4 : entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (c, i) {
                      return Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              entries[i].key,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(Formatters.currency(entries[i].value), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        ],
                      );
                    },
                  ),
                ),
              ],
            )
          else
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              entries[idx].key.split(' ').first,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(entries.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: entries[i].value,
                          color: colors[i % colors.length],
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- PAYMENT CHANNELS & TOP CATEGORY ---
  Widget _buildPaymentChannelsCard({
    required Map<String, double> paymentModeTotals,
    required double totalExpenses,
    required String topCategory,
    required double topCategoryAmount,
  }) {
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
          // Top Category Badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.pastelAmber,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.deepAmber),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TOP EXPENDITURE CATEGORY', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: AppColors.deepAmber)),
                    const SizedBox(height: 2),
                    Text(topCategory, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.deepAmber)),
                  ],
                ),
                Text(Formatters.currency(topCategoryAmount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.deepAmber)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('Payment Mode Breakdown', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 8),
          if (paymentModeTotals.isEmpty)
            const Text('No payments recorded', style: TextStyle(fontSize: 11, color: AppColors.textMuted))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: paymentModeTotals.entries.length,
              separatorBuilder: (_, __) => const Divider(height: 10),
              itemBuilder: (c, i) {
                final entry = paymentModeTotals.entries.elementAt(i);
                final pct = totalExpenses > 0 ? ((entry.value / totalExpenses) * 100).toStringAsFixed(0) : '0';

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    Text(
                      '${Formatters.currency(entry.value)} ($pct%)',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // --- 4. SEARCH & MULTI-CRITERIA FILTERS ---
  Widget _buildSearchAndFilterControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Bar
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search expenses by description, note, or code...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
          ),
          onChanged: (v) => setState(() => _searchTerm = v),
        ),
        const SizedBox(height: 8),

        // Category Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...['All', ..._customCategories].map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: AppColors.pastelCoral,
                    checkmarkColor: AppColors.deepCoral,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: isSelected ? AppColors.deepCoral : AppColors.border, width: 1.2),
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.deepCoral : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 11.5,
                    ),
                    onSelected: (val) => setState(() => _selectedCategory = cat),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // --- 5. SHOP EXPENSE LOG FEED ---
  Widget _buildExpenseLogFeed(List<ExpenseModel> expenses) {
    return ValueListenableBuilder<List<SyncTask>>(
      valueListenable: SyncQueueManager.instance.tasksNotifier,
      builder: (ctx, tasks, _) {
        if (expenses.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.pastelCoral, borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.receipt_long_rounded, size: 44, color: AppColors.deepCoral),
                  ),
                  const SizedBox(height: 12),
                  const Text('No expenses found for the selected filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: expenses.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (c, i) {
            final exp = expenses[i];
            final syncStatus = _getExpenseSyncStatus(exp.clientRef, exp.id, tasks);
            final icon = _getCategoryIcon(exp.category);
            final parsedDate = DateTime.tryParse(exp.date) ?? DateTime.now();
            final dateFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(parsedDate);

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.pastelCoral,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: AppColors.deepCoral, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  exp.title,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (exp.expenseNumber != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(color: AppColors.pastelLavender, borderRadius: BorderRadius.circular(4)),
                                    child: Text(exp.expenseNumber!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.deepLavender)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(dateFormatted, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.pastelCoral, borderRadius: BorderRadius.circular(4)),
                                child: Text(exp.category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.deepCoral)),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.pastelMint, borderRadius: BorderRadius.circular(4)),
                                child: Text(exp.paymentMode, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.deepMint)),
                              ),
                            ],
                          ),
                          if (exp.notes != null && exp.notes!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('Ref: ${exp.notes}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted)),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Formatters.currency(exp.amount),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.deepCoral),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    SyncStatusBadge(status: syncStatus),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.deepCoral),
                      tooltip: 'Delete Expense',
                      onPressed: () => _showDeleteSafeguardDialog(exp),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
