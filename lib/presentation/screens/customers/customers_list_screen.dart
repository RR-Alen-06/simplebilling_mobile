import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/network/sync_queue_manager.dart';
import 'package:simplebilling_mobile/core/network/sync_task_model.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/core/utils/whatsapp_sender.dart';
import 'package:simplebilling_mobile/core/utils/csv_exporter.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';
import 'package:simplebilling_mobile/presentation/screens/customers/customer_ledger_screen.dart';
import 'package:simplebilling_mobile/presentation/shared/widgets/sync_status_badge.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

class CustomersListScreen extends ConsumerStatefulWidget {
  const CustomersListScreen({super.key});

  @override
  ConsumerState<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends ConsumerState<CustomersListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchTerm = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  SyncStatus _getCustomerSyncStatus(
    String? clientRef,
    String id,
    List<SyncTask> tasks,
  ) {
    for (final task in tasks) {
      if (task.action == 'create_customer') {
        if ((clientRef != null && task.clientRef == clientRef) ||
            task.id == id ||
            task.clientRef == id) {
          return task.status;
        }
      }
    }
    return SyncStatus.synced;
  }

  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final advanceCtrl = TextEditingController(text: '0.0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_add_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Register New Customer', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Customer Full Name *',
                  hintText: 'e.g. Rahul Sharma',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: mobileCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  hintText: 'e.g. 9876543210',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address (Optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: advanceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Initial Advance Wallet Deposit (₹)',
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
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final mobile = mobileCtrl.text.trim().isEmpty ? null : mobileCtrl.text.trim();
              final email = emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim();
              final advance = double.tryParse(advanceCtrl.text) ?? 0.0;
              if (name.isEmpty) return;

              final created = await ApiRepository.createCustomer(
                name,
                mobile,
                email: email,
                initialAdvance: advance,
              );
              if (created == null) {
                // Offline fallback queue
                final clientRef = const Uuid().v4();
                await SyncQueueManager.instance.enqueueTask('create_customer', {
                  'client_ref': clientRef,
                  'name': name,
                  'mobile': mobile,
                  'email': email,
                  'advance_balance': advance,
                  'loyalty_points': 0.0,
                }, clientRef: clientRef);
              }

              if (mounted) {
                ref.invalidate(customersProvider);
                ref.invalidate(customerSummariesProvider);
                if (ctx.mounted) Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Customer "$name" registered successfully! 🎉'),
                  ),
                );
              }
            },
            child: const Text('Save Customer'),
          ),
        ],
      ),
    );
  }

  void _showEditCustomerDialog(CustomerModel customer) {
    final nameCtrl = TextEditingController(text: customer.name);
    final mobileCtrl = TextEditingController(text: customer.mobile ?? '');
    final emailCtrl = TextEditingController(text: customer.email ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: AppColors.deepSky),
            const SizedBox(width: 8),
            Text('Edit: ${customer.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Customer Full Name *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: mobileCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepSky,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) return;

              final updated = await ApiRepository.updateCustomer(
                customer.id,
                name: newName,
                mobile: mobileCtrl.text.trim().isEmpty ? null : mobileCtrl.text.trim(),
                email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
              );

              if (mounted) {
                ref.invalidate(customersProvider);
                ref.invalidate(customerSummariesProvider);
                if (ctx.mounted) Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(updated ? 'Customer updated! ✏️' : 'Failed to update customer.'),
                  ),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerSummariesProvider);
    final settings = ref.watch(settingsProvider).valueOrNull ??
        AllSettings(shop: ShopSettings(), billing: BillingSettings(), loyalty: LoyaltySettings());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer Directory & Ledger',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary),
            ),
            Text(
              'Accounts, outstanding balances, and running statements',
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
            tooltip: 'Export Customer Ledger as CSV',
            icon: const Icon(Icons.download_rounded, color: AppColors.deepLavender),
            onPressed: () async {
              final customers = customersAsync.valueOrNull ?? [];
              if (customers.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No customers available to export.')),
                );
                return;
              }
              await CsvExporter.exportCustomerDues(customers, filename: 'customers_ledger.csv');
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Customer ledger CSV exported successfully! 👥')),
              );
            },
          ),
          IconButton(
            tooltip: 'Add Customer',
            icon: const Icon(Icons.person_add_rounded, color: AppColors.deepSky),
            onPressed: _showAddCustomerDialog,
          ),
          IconButton(
            tooltip: 'Refresh Customers',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: () => ref.invalidate(customerSummariesProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('+ Add Customer', style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: _showAddCustomerDialog,
      ),
      body: Column(
        children: [
          // High-contrast Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by customer name, mobile, or code...',
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                ),
              ),
              onChanged: (v) => setState(() => _searchTerm = v),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<SyncTask>>(
              valueListenable: SyncQueueManager.instance.tasksNotifier,
              builder: (ctx, tasks, _) {
                return customersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (err, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 44, color: AppColors.deepCoral),
                        const SizedBox(height: 8),
                        Text('Error loading customers: $err', style: const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(customerSummariesProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (customers) {
                    final filtered = customers.where((c) {
                      if (_searchTerm.isEmpty) return true;
                      final q = _searchTerm.toLowerCase();
                      return c.name.toLowerCase().contains(q) ||
                          (c.mobile != null && c.mobile!.toLowerCase().contains(q)) ||
                          (c.customerCode != null && c.customerCode!.toLowerCase().contains(q)) ||
                          (c.email != null && c.email!.toLowerCase().contains(q));
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.pastelSky,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.people_outline_rounded,
                                size: 48,
                                color: AppColors.deepSky,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchTerm.isEmpty
                                  ? 'No customers in directory yet'
                                  : 'No customers matching "$_searchTerm"',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final cust = filtered[i];
                        final syncStatus = _getCustomerSyncStatus(
                          cust.clientRef,
                          cust.id,
                          tasks,
                        );

                        return InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CustomerLedgerScreen(customerId: cust.id),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border, width: 1.5),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: AppColors.pastelLavender,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: AppColors.borderLavender),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  cust.name.isNotEmpty ? cust.name[0].toUpperCase() : 'C',
                                                  style: const TextStyle(
                                                    color: AppColors.deepLavender,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          cust.name,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w800,
                                                            fontSize: 14,
                                                            color: AppColors.textPrimary,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      if (cust.customerCode != null)
                                                        Padding(
                                                          padding: const EdgeInsets.only(left: 6),
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: AppColors.pastelSky,
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: Text(
                                                              cust.customerCode!,
                                                              style: const TextStyle(
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                                color: AppColors.deepSky,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  Text(
                                                    cust.mobile != null && cust.mobile!.isNotEmpty
                                                        ? '${cust.mobile!} ${cust.email != null ? "• " + cust.email! : ""}'
                                                        : (cust.email ?? 'No contact registered'),
                                                    style: const TextStyle(
                                                      color: AppColors.textSecondary,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                                            tooltip: 'Edit Customer',
                                            onPressed: () => _showEditCustomerDialog(cust),
                                          ),
                                          SyncStatusBadge(status: syncStatus),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Divider(height: 1, color: AppColors.border),
                                  const SizedBox(height: 8),

                                  // Financial Summary Card Row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildStatBadge(
                                        label: 'Total Billed',
                                        value: Formatters.currency(cust.totalBilled),
                                        bgColor: AppColors.pastelSky,
                                        textColor: AppColors.deepSky,
                                        borderColor: AppColors.borderSky,
                                      ),
                                      _buildStatBadge(
                                        label: 'Total Paid',
                                        value: Formatters.currency(cust.totalPaid),
                                        bgColor: AppColors.pastelMint,
                                        textColor: AppColors.deepMint,
                                        borderColor: AppColors.borderMint,
                                      ),
                                      _buildStatBadge(
                                        label: 'Balance Due',
                                        value: Formatters.currency(cust.balanceDue),
                                        bgColor: cust.balanceDue > 0 ? AppColors.pastelCoral : AppColors.background,
                                        textColor: cust.balanceDue > 0 ? AppColors.deepCoral : AppColors.deepMint,
                                        borderColor: cust.balanceDue > 0 ? AppColors.borderCoral : AppColors.border,
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  // Action Buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.pastelLavender,
                                            foregroundColor: AppColors.deepLavender,
                                            elevation: 0,
                                            side: const BorderSide(color: AppColors.deepLavender),
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.account_balance_wallet_rounded, size: 15),
                                          label: const Text('View Ledger Statement', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => CustomerLedgerScreen(customerId: cust.id),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      if (cust.balanceDue > 0) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          style: IconButton.styleFrom(
                                            backgroundColor: AppColors.pastelCoral,
                                            side: const BorderSide(color: AppColors.deepCoral),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.send_rounded, size: 16, color: AppColors.deepCoral),
                                          tooltip: 'Send WhatsApp Due Reminder',
                                          onPressed: () {
                                            WhatsAppSender.sendDuePaymentReminder(
                                              customer: cust,
                                              shop: settings.shop,
                                              billing: settings.billing,
                                            );
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge({
    required String label,
    required String value,
    required Color bgColor,
    required Color textColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
