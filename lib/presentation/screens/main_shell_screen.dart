import 'package:flutter/material.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 768;

        if (isLargeScreen) {
          return _buildTabletDesktopLayout();
        }

        return _buildMobileAdaptiveLayout();
      },
    );
  }

  // --- Tablet / Desktop Modern Sidebar Rail Layout ---
  Widget _buildTabletDesktopLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          Container(
            width: 240,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryEmerald,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryEmerald.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.point_of_sale, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SimpleBilling',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                'POS & ERP Suite',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.pastelMint,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.borderMint),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt, size: 13, color: AppColors.deepMint),
                            SizedBox(width: 4),
                            Text(
                              'TEST / MOCK MODE (SAFE)',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.deepMint,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 12),
                
                // Navigation Items List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _buildSidebarItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
                      _buildSidebarItem(1, Icons.point_of_sale_outlined, Icons.point_of_sale, 'POS Billing'),
                      _buildSidebarItem(2, Icons.receipt_long_outlined, Icons.receipt_long, 'Invoices & Bills'),
                      _buildSidebarItem(3, Icons.payments_outlined, Icons.payments, 'Payments'),
                      _buildSidebarItem(4, Icons.people_outline, Icons.people, 'Customers'),
                      _buildSidebarItem(5, Icons.inventory_2_outlined, Icons.inventory_2, 'Products & Stock'),
                      _buildSidebarItem(6, Icons.money_off_outlined, Icons.money_off, 'Shop Expenses'),
                      _buildSidebarItem(7, Icons.bar_chart_outlined, Icons.bar_chart, 'Analytics & Reports'),
                      _buildSidebarItem(8, Icons.security_outlined, Icons.security, 'Audit Trail'),
                      _buildSidebarItem(9, Icons.settings_outlined, Icons.settings, 'Settings'),
                    ],
                  ),
                ),

                // Footer Merchant Quick Status
                const Divider(height: 1, color: AppColors.borderLight),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: InkWell(
                    onTap: widget.onSignOut,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.logout, color: AppColors.error, size: 18),
                          SizedBox(width: 10),
                          Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content View Area
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

  Widget _buildSidebarItem(int index, IconData unselectedIcon, IconData selectedIcon, String label) {
    final isSelected = _currentIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryContainer.withValues(alpha: 0.6) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          isSelected ? selectedIcon : unselectedIcon,
          color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
          ),
        ),
        onTap: () => setState(() => _currentIndex = index),
      ),
    );
  }

  // --- Mobile Adaptive Layout with Floating Action Dock ---
  Widget _buildMobileAdaptiveLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 74),
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ),
          
          // Tactile Floating Bottom Navigation Dock
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDockTab(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
                    _buildDockTab(2, Icons.receipt_long_outlined, Icons.receipt_long, 'Bills'),
                    
                    // Elevated Center POS Quick Trigger
                    _buildCenterPosTrigger(),

                    _buildDockTab(3, Icons.payments_outlined, Icons.payments, 'Payments'),
                    _buildDockMoreTrigger(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDockTab(int index, IconData unselectedIcon, IconData selectedIcon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSelected ? selectedIcon : unselectedIcon,
                color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterPosTrigger() {
    final isPosSelected = _currentIndex == 1;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = 1),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.primaryEmerald,
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF10B981),
              Color(0xFF059669),
            ],
          ),
          border: Border.all(
            color: isPosSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
            width: isPosSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryEmerald.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.point_of_sale,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildDockMoreTrigger() {
    final isMoreSelected = _currentIndex > 3;
    return InkWell(
      onTap: () => _showMoreOptionsSheet(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: isMoreSelected ? AppColors.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.grid_view_rounded,
                color: isMoreSelected ? AppColors.primaryDark : AppColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'More',
              style: TextStyle(
                fontSize: 10,
                fontWeight: isMoreSelected ? FontWeight.w800 : FontWeight.w600,
                color: isMoreSelected ? AppColors.primaryDark : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
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
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 14),
                child: Row(
                  children: [
                    Text(
                      'All Operations',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    Spacer(),
                    Text(
                      'Shortcuts',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                    ),
                  ],
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
                title: 'Products & Inventory',
                subtitle: 'Manage stock, SKU catalog and prices',
                icon: Icons.inventory_2_outlined,
                bgColor: AppColors.pastelSky,
                iconColor: AppColors.deepSky,
                index: 5,
              ),
              _buildMoreTile(
                ctx,
                title: 'Shop Expenses',
                subtitle: 'Log operational expenses and vendor costs',
                icon: Icons.money_off_outlined,
                bgColor: AppColors.pastelCoral,
                iconColor: AppColors.deepCoral,
                index: 6,
              ),
              _buildMoreTile(
                ctx,
                title: 'Reports & Analytics',
                subtitle: 'Daily summary, revenue breakdown & export',
                icon: Icons.bar_chart_outlined,
                bgColor: AppColors.pastelLavender,
                iconColor: AppColors.deepLavender,
                index: 7,
              ),
              _buildMoreTile(
                ctx,
                title: 'Audit Trail & Logs',
                subtitle: 'Security history and cloud sync status',
                icon: Icons.security_outlined,
                bgColor: AppColors.pastelSky,
                iconColor: AppColors.deepSky,
                index: 8,
              ),
              _buildMoreTile(
                ctx,
                title: 'Settings & Profile',
                subtitle: 'Store GSTIN, printing options and logout',
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
        onTap: () {
          Navigator.pop(ctx);
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}
