import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/data/models/dashboard_stats_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';

final dashboardStatsProvider = FutureProvider<DashboardStatsModel>((ref) async {
  return await ApiRepository.getDashboardStats();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Shop Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(dashboardStatsProvider),
          ),
        ],
      ),
      body: statsAsync.when(
        data: (stats) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardStatsProvider),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Metric Cards Grid
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStatCard(
                      'Today\'s Sales',
                      Formatters.currency(stats.todaysSales),
                      Icons.today,
                      AppColors.primary,
                      '${stats.todaysBillsCount} bills generated',
                    ),
                    _buildStatCard(
                      'Monthly Sales',
                      Formatters.currency(stats.monthlySales),
                      Icons.calendar_month,
                      AppColors.secondary,
                      'This month total',
                    ),
                    _buildStatCard(
                      'Total Income',
                      Formatters.currency(stats.totalIncome),
                      Icons.account_balance,
                      AppColors.success,
                      'Overall revenue',
                    ),
                    _buildStatCard(
                      'Total Expense',
                      Formatters.currency(stats.totalExpense),
                      Icons.money_off,
                      AppColors.error,
                      'Shop operational costs',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Profitability Banner
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Net Profit', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(
                              Formatters.currency(stats.netProfit),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color: stats.netProfit >= 0 ? AppColors.success : AppColors.error,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (stats.netProfit >= 0 ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            stats.netProfit >= 0 ? Icons.trending_up : Icons.trending_down,
                            color: stats.netProfit >= 0 ? AppColors.success : AppColors.error,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Customer & Bills Summary Row
                Row(
                  children: [
                    Expanded(
                      child: Card(
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
                              const Text('Total Customers', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text('${stats.totalCustomers}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
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
                              const Text('Pending Balance', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                Formatters.currency(stats.pendingBalance),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.warning),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error loading stats: $e')),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                Icon(icon, size: 18, color: color),
              ],
            ),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
