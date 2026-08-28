import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';
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

  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add New Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Customer Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mobileCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile Number', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final mobile = mobileCtrl.text.trim();
              if (name.isEmpty) return;

              final created = await ApiRepository.createCustomer(name, mobile);
              if (created != null && mounted) {
                ref.invalidate(customersProvider);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
              }
            },
            child: const Text('Save Customer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customers & Balances', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(customersProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _showAddCustomerDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Customer'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search customer name or mobile...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                fillColor: Colors.white,
                filled: true,
              ),
              onChanged: (val) => setState(() => _searchTerm = val.toLowerCase()),
            ),
          ),
          Expanded(
            child: customersAsync.when(
              data: (customers) {
                final filtered = customers.where((c) =>
                    c.name.toLowerCase().contains(_searchTerm) ||
                    (c.mobile?.toLowerCase().contains(_searchTerm) ?? false)).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No customers found'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final customer = filtered[idx];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surfaceVariant,
                          child: Text(
                            customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                        title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(customer.mobile ?? 'No Mobile'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Adv: ${Formatters.currency(customer.advanceBalance)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary, fontSize: 13),
                            ),
                            Text(
                              '${customer.loyaltyPoints.toStringAsFixed(0)} pts',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, s) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
