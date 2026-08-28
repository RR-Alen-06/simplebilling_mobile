import 'package:flutter/material.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:simplebilling_mobile/presentation/screens/billing/billing_screen.dart';
import 'package:simplebilling_mobile/presentation/screens/bills/bills_list_screen.dart';
import 'package:simplebilling_mobile/presentation/screens/customers/customers_list_screen.dart';
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
      const DashboardScreen(),
      const BillingScreen(),
      const BillsListScreen(),
      const CustomersListScreen(),
      const ProductsScreen(),
      const ExpensesScreen(),
      const ReportsScreen(),
      const AuditScreen(),
      SettingsScreen(onSignOut: widget.onSignOut),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 720;

        if (isLargeScreen) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: const IconThemeData(color: AppColors.primary),
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
                    NavigationRailDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: Text('Billing')),
                    NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: Text('Bills')),
                    NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Customers')),
                    NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: Text('Products')),
                    NavigationRailDestination(icon: Icon(Icons.money_off_outlined), selectedIcon: Icon(Icons.money_off), label: Text('Expenses')),
                    NavigationRailDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: Text('Reports')),
                    NavigationRailDestination(icon: Icon(Icons.security_outlined), selectedIcon: Icon(Icons.security), label: Text('Audit')),
                    NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Settings')),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _screens,
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile Bottom Navigation Bar
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex < 5 ? _currentIndex : 4,
            onDestinationSelected: (idx) {
              if (idx == 4) {
                // Show Drawer / More Options for remaining screens
                _showMoreOptionsSheet(context);
              } else {
                setState(() => _currentIndex = idx);
              }
            },
            backgroundColor: Colors.white,
            elevation: 2,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: AppColors.primary), label: 'Dashboard'),
              NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale, color: AppColors.primary), label: 'POS'),
              NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long, color: AppColors.primary), label: 'Bills'),
              NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people, color: AppColors.primary), label: 'Customers'),
              NavigationDestination(icon: Icon(Icons.grid_view), selectedIcon: Icon(Icons.grid_view, color: AppColors.primary), label: 'More'),
            ],
          ),
        );
      },
    );
  }

  void _showMoreOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
                title: const Text('Products & Catalog', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _currentIndex = 4);
                },
              ),
              ListTile(
                leading: const Icon(Icons.money_off_outlined, color: AppColors.error),
                title: const Text('Shop Expenses', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _currentIndex = 5);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart_outlined, color: AppColors.secondary),
                title: const Text('Reports & Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _currentIndex = 6);
                },
              ),
              ListTile(
                leading: const Icon(Icons.security_outlined, color: AppColors.info),
                title: const Text('Audit Trail & Logs', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _currentIndex = 7);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined, color: AppColors.accent),
                title: const Text('Settings & Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _currentIndex = 8);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
