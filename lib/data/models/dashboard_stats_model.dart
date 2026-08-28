class DashboardStatsModel {
  final double todaysSales;
  final double monthlySales;
  final int todaysBillsCount;
  final double pendingBalance;
  final int totalCustomers;
  final double totalIncome;
  final double totalExpense;
  final double netProfit;
  final int billsGenerated;
  final double averageBillValue;
  final List<Map<String, dynamic>> salesTrend;

  DashboardStatsModel({
    required this.todaysSales,
    required this.monthlySales,
    required this.todaysBillsCount,
    required this.pendingBalance,
    required this.totalCustomers,
    required this.totalIncome,
    required this.totalExpense,
    required this.netProfit,
    required this.billsGenerated,
    required this.averageBillValue,
    this.salesTrend = const [],
  });

  factory DashboardStatsModel.empty() {
    return DashboardStatsModel(
      todaysSales: 0.0,
      monthlySales: 0.0,
      todaysBillsCount: 0,
      pendingBalance: 0.0,
      totalCustomers: 0,
      totalIncome: 0.0,
      totalExpense: 0.0,
      netProfit: 0.0,
      billsGenerated: 0,
      averageBillValue: 0.0,
      salesTrend: [],
    );
  }
}
