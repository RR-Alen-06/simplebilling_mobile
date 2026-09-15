import 'package:flutter/material.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/network/supabase_client.dart';
import 'package:simplebilling_mobile/data/mock/mock_data_store.dart';
import 'package:simplebilling_mobile/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:simplebilling_mobile/presentation/screens/billing/billing_screen.dart';
import 'package:simplebilling_mobile/presentation/screens/bills/bills_list_screen.dart';
import 'package:simplebilling_mobile/presentation/screens/customers/customers_list_screen.dart';
import 'package:simplebilling_mobile/presentation/screens/payments/payment_collection_screen.dart';
import 'package:simplebilling_mobile/presentation/screens/products/products_screen.dart';
import 'package:simplebilling_mobile/presentation/screens/expenses/expenses_screen.dart';
import 'package:simplebilling_mobile/presentation/screens/reports/reports_screen.dart';
import 'package:simplebilling_mobile/presentation/screens/audit/audit_screen.dart';
import 'package:simplebilling_mobile/presentation/screens/settings/settings_screen.dart';

class MainShellScreen extends StatefulWidget {
  final VoidCallback onSignOut;
  const MainShellScreen({super.key, required this.onSignOut});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 1; // Default to POS Billing

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(onNavigateTab: (idx) => setState(() => _currentIndex = idx)),
      const BillingScreen(),
      const BillsListScreen(),
      const PaymentCollectionScreen(),
      const CustomersListScreen(),
      const ProductsScreen(),
      const ExpensesScreen(),
      const ReportsScreen(),
      const AuditScreen(),
      SettingsScreen(onSignOut: widget.onSignOut),
    ];
  }

  Widget _buildSandboxBanner(BuildContext context) {
    if (!SupabaseConfig.isMockMode) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFFFEF3C7),
        border: Border(bottom: BorderSide(color: Color(0xFFFDE68A), width: 1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, size: 18, color: Color(0xFFD97706)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'TEST SANDBOX MODE • Live Web App DB Protected',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF92400E),
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () async {
              await MockDataStore.instance.resetToDefaults();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sandbox demo data reset to clean initial state.'),
                    backgroundColor: AppColors.primary,
                    duration: Duration(seconds: 2),
                  ),
                );
                setState(() {});
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.refresh, size: 14, color: Color(0xFF92400E)),
                  SizedBox(width: 4),
                  Text(
                    'Reset Data',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 720;

        if (isLargeScreen) {
          return Scaffold(
            body: Column(
              children: [
                _buildSandboxBanner(context),
                Expanded(
                  child: Row(
                    children: [
                      SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: IntrinsicHeight(
                            child: NavigationRail(
                              selectedIndex: _currentIndex,
                              onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
                              labelType: NavigationRailLabelType.all,
                              indicatorColor: AppColors.pastelLavender,
                              backgroundColor: Colors.white,
                              selectedIconTheme: const IconThemeData(color: AppColors.deepLavender, size: 26),
                              unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary, size: 22),
                              selectedLabelTextStyle: const TextStyle(
                                color: AppColors.deepLavender,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                              unselectedLabelTextStyle: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                              destinations: const [
                                NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
                                NavigationRailDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: Text('Billing')),
                                NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: Text('Bills')),
                                NavigationRailDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: Text('Payments')),
                                NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Customers')),
                                NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: Text('Products')),
                                NavigationRailDestination(icon: Icon(Icons.money_off_outlined), selectedIcon: Icon(Icons.money_off), label: Text('Expenses')),
                                NavigationRailDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: Text('Reports')),
                                NavigationRailDestination(icon: Icon(Icons.security_outlined), selectedIcon: Icon(Icons.security), label: Text('Audit')),
                                NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Settings')),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const VerticalDivider(thickness: 1, width: 1, color: AppColors.border),
                      Expanded(
                        child: IndexedStack(
                          index: _currentIndex,
                          children: _screens,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile Bottom Navigation Bar with crisp colorful theme
        return Scaffold(
          body: Column(
            children: [
              _buildSandboxBanner(context),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _screens,
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex < 5 ? _currentIndex : 4,
              indicatorColor: AppColors.pastelLavender,
              surfaceTintColor: Colors.transparent,
              onDestinationSelected: (idx) {
                if (idx == 4) {
                  _showMoreOptionsSheet(context);
                } else {
                  setState(() => _currentIndex = idx);
                }
              },
              backgroundColor: Colors.white,
              elevation: 0,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard, color: AppColors.deepLavender),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.point_of_sale_outlined),
                  selectedIcon: Icon(Icons.point_of_sale, color: AppColors.deepLavender),
                  label: 'POS',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long, color: AppColors.deepLavender),
                  label: 'Bills',
                ),
                NavigationDestination(
                  icon: Icon(Icons.payments_outlined),
                  selectedIcon: Icon(Icons.payments, color: AppColors.deepLavender),
                  label: 'Payments',
                ),
                NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view_rounded, color: AppColors.deepLavender),
                  label: 'More',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMoreOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 12),
                child: Text(
                  'More Operations',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
              _buildMoreTile(
                ctx,
                title: 'Customer Directory & Dues',
                subtitle: 'Manage client accounts and running ledgers',
                icon: Icons.people_outline,
                bgColor: AppColors.pastelMint,
                iconColor: AppColors.deepMint,
                index: 4,
              ),
              _buildMoreTile(
                ctx,
                title: 'Products & Catalog',
                subtitle: 'Manage stock and item prices',
                icon: Icons.inventory_2_outlined,
                bgColor: AppColors.pastelSky,
                iconColor: AppColors.deepSky,
                index: 5,
              ),
              _buildMoreTile(
                ctx,
                title: 'Shop Expenses',
                subtitle: 'Log operational costs and bills',
                icon: Icons.money_off_outlined,
                bgColor: AppColors.pastelCoral,
                iconColor: AppColors.deepCoral,
                index: 6,
              ),
              _buildMoreTile(
                ctx,
                title: 'Reports & Analytics',
                subtitle: 'Daily sales, monthly profit & dues',
                icon: Icons.bar_chart_outlined,
                bgColor: AppColors.pastelLavender,
                iconColor: AppColors.deepLavender,
                index: 7,
              ),
              _buildMoreTile(
                ctx,
                title: 'Audit Trail & Logs',
                subtitle: 'Security & mutation history',
                icon: Icons.security_outlined,
                bgColor: AppColors.pastelSky,
                iconColor: AppColors.deepSky,
                index: 8,
              ),
              _buildMoreTile(
                ctx,
                title: 'Settings & Profile',
                subtitle: 'Store GSTIN, phone & session',
                icon: Icons.settings_outlined,
                bgColor: AppColors.pastelAmber,
                iconColor: AppColors.deepAmber,
                index: 9,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreTile(
    BuildContext ctx, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required int index,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
        onTap: () {
          Navigator.pop(ctx);
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}
