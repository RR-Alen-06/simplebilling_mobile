import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';
import 'package:simplebilling_mobile/presentation/screens/customers/customer_ledger_screen.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

final recentPaymentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final response = await ApiRepository.client
        .from('payments')
        .select('*, customers(name, mobile)')
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(response as List);
  } catch (e) {
    debugPrint('Error fetching recent payments: $e');
    return [];
  }
});

class PaymentCollectionScreen extends ConsumerStatefulWidget {
  final CustomerModel? initialCustomer;
  const PaymentCollectionScreen({super.key, this.initialCustomer});

  @override
  ConsumerState<PaymentCollectionScreen> createState() => _PaymentCollectionScreenState();
}

class _PaymentCollectionScreenState extends ConsumerState<PaymentCollectionScreen> {
  CustomerModel? _selectedCustomer;
  final TextEditingController _cashCtrl = TextEditingController();
  final TextEditingController _upiCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchTerm = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.initialCustomer;
  }

  @override
  void dispose() {
    _cashCtrl.dispose();
    _upiCtrl.dispose();
    _notesCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  double get _cashAmount => double.tryParse(_cashCtrl.text.trim()) ?? 0.0;
  double get _upiAmount => double.tryParse(_upiCtrl.text.trim()) ?? 0.0;
  double get _totalCollection => _cashAmount + _upiAmount;

  void _autofillFullCashDue() {
    if (_selectedCustomer == null) return;
    setState(() {
      _cashCtrl.text = _selectedCustomer!.balanceDue.toStringAsFixed(2);
      _upiCtrl.clear();
    });
  }

  void _autofillFullUpiDue() {
    if (_selectedCustomer == null) return;
    setState(() {
      _upiCtrl.text = _selectedCustomer!.balanceDue.toStringAsFixed(2);
      _cashCtrl.clear();
    });
  }

  Future<void> _handleRecordPayment() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer first.')),
      );
      return;
    }

    if (_totalCollection <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Cash or UPI payment amount.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    String paymentMode = 'Cash';
    if (_cashAmount > 0 && _upiAmount > 0) {
      paymentMode = 'Split (Cash+UPI)';
    } else if (_upiAmount > 0) {
      paymentMode = 'UPI';
    }

    final success = await ApiRepository.recordCustomerPayment(
      customerId: _selectedCustomer!.id,
      amount: _totalCollection,
      paymentMode: paymentMode,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
    );

    setState(() => _isProcessing = false);

    if (!mounted) return;

    if (success) {
      ref.invalidate(customersProvider);
      ref.invalidate(recentPaymentsProvider);
      ref.invalidate(billsListProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.deepMint,
          content: Text('Successfully collected ${Formatters.currency(_totalCollection)} for ${_selectedCustomer!.name}! 💰'),
        ),
      );

      setState(() {
        _cashCtrl.clear();
        _upiCtrl.clear();
        _notesCtrl.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to record payment. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    final paymentsAsync = ref.watch(recentPaymentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Payment Collection Desk',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh Desk',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: () {
              ref.invalidate(customersProvider);
              ref.invalidate(recentPaymentsProvider);
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTwoColumn = constraints.maxWidth >= 850;

          if (isTwoColumn) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Collection Desk
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildCollectionDesk(customersAsync),
                  ),
                ),
                const VerticalDivider(width: 1, color: AppColors.border),
                // Right Column: Recent Payment Transaction Log
                Expanded(
                  flex: 5,
                  child: _buildRecentPaymentsLog(paymentsAsync),
                ),
              ],
            );
          }

          // Single column view for mobile
          return SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildCollectionDesk(customersAsync),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                SizedBox(
                  height: 450,
                  child: _buildRecentPaymentsLog(paymentsAsync),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCollectionDesk(AsyncValue<List<CustomerModel>> customersAsync) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neoBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowLight, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.pastelMint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderMint),
                ),
                child: const Icon(Icons.point_of_sale_rounded, color: AppColors.deepMint, size: 20),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Collect Customer Payment', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text('Direct dues settlement or advance wallet credit', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const Divider(height: 24),

          // 1. Customer Selector with Pending Dues optgroup styling
          const Text('Select Customer Account (*)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
          const SizedBox(height: 6),
          customersAsync.when(
            data: (customers) {
              final dueCustomers = customers.where((c) => c.balanceDue > 0).toList();
              final clearCustomers = customers.where((c) => c.balanceDue <= 0).toList();

              return DropdownButtonFormField<String>(
                value: _selectedCustomer?.id,
                decoration: InputDecoration(
                  hintText: 'Choose a customer...',
                  prefixIcon: const Icon(Icons.person_search_rounded, size: 20, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                ),
                items: [
                  if (dueCustomers.isNotEmpty) ...[
                    const DropdownMenuItem<String>(
                      enabled: false,
                      value: '__header_due__',
                      child: Text('⚠️ CUSTOMERS WITH PENDING DUES', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.deepCoral, fontSize: 11)),
                    ),
                    ...dueCustomers.map((c) => DropdownMenuItem<String>(
                          value: c.id,
                          child: Text('${c.name} — Due: ${Formatters.currency(c.balanceDue)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        )),
                  ],
                  if (clearCustomers.isNotEmpty) ...[
                    const DropdownMenuItem<String>(
                      enabled: false,
                      value: '__header_clear__',
                      child: Text('✅ OTHER CUSTOMERS', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textSecondary, fontSize: 11)),
                    ),
                    ...clearCustomers.map((c) => DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        )),
                  ],
                ],
                onChanged: (id) {
                  if (id != null && !id.startsWith('__header')) {
                    setState(() {
                      _selectedCustomer = customers.firstWhere((c) => c.id == id);
                    });
                  }
                },
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (err, _) => Text('Error loading customers: $err'),
          ),
          const SizedBox(height: 14),

          // 2. Customer Balance Snapshot Card
          if (_selectedCustomer != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedCustomer!.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          Text('Mobile: ${_selectedCustomer!.mobile ?? "-"}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                        ],
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
                        ),
                        icon: const Icon(Icons.receipt_long_rounded, size: 14, color: AppColors.deepLavender),
                        label: const Text('Ledger Statement', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.deepLavender)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => CustomerLedgerScreen(customerId: _selectedCustomer!.id)),
                          );
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricTile('PREVIOUS DUES', Formatters.currency(_selectedCustomer!.balanceDue), _selectedCustomer!.balanceDue > 0 ? AppColors.deepCoral : AppColors.deepMint),
                      _buildMetricTile('AVAILABLE ADVANCE', Formatters.currency(_selectedCustomer!.advanceBalance), AppColors.deepSky),
                      _buildMetricTile('LOYALTY PTS', '${_selectedCustomer!.loyaltyPoints.toStringAsFixed(0)} ⭐', AppColors.deepAmber),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Quick Pay Buttons
            if (_selectedCustomer!.balanceDue > 0) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.pastelSky.withOpacity(0.4),
                        side: const BorderSide(color: AppColors.deepSky, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _autofillFullCashDue,
                      icon: const Icon(Icons.bolt_rounded, size: 16, color: AppColors.deepSky),
                      label: const Text('⚡ Pay Full Cash Due', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: AppColors.deepSky)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.pastelLavender.withOpacity(0.4),
                        side: const BorderSide(color: AppColors.deepLavender, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _autofillFullUpiDue,
                      icon: const Icon(Icons.qr_code_2_rounded, size: 16, color: AppColors.deepLavender),
                      label: const Text('⚡ Pay Full UPI Due', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: AppColors.deepLavender)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
          ],

          // 3. Payment Split Amount Inputs
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cashCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: _inputDecoration('Cash Amount (₹)', Icons.payments_rounded),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _upiCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: _inputDecoration('UPI Amount (₹)', Icons.qr_code_2_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4. Notes / Reference Input
          TextField(
            controller: _notesCtrl,
            decoration: _inputDecoration('Notes / Reference (Optional)', Icons.notes_rounded),
          ),
          const SizedBox(height: 16),

          // 5. Total & Record Button
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.pastelMint.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.deepMint),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Collection Amount:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.deepMint)),
                Text(
                  Formatters.currency(_totalCollection),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.deepMint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepMint,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isProcessing ? null : _handleRecordPayment,
              icon: _isProcessing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_rounded),
              label: const Text('Record Customer Payment', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPaymentsLog(AsyncValue<List<Map<String, dynamic>>> paymentsAsync) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neoBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowLight, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.history_rounded, size: 20, color: AppColors.deepLavender),
                  SizedBox(width: 8),
                  Text('Recent Payment Log', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                onPressed: () => ref.invalidate(recentPaymentsProvider),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchTerm = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search payments by number, customer, mode...',
              hintStyle: const TextStyle(fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              isDense: true,
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: paymentsAsync.when(
              data: (payments) {
                final filtered = payments.where((p) {
                  if (_searchTerm.isEmpty) return true;
                  final num = (p['payment_number'] ?? '').toString().toLowerCase();
                  final cust = (p['customers']?['name'] ?? '').toString().toLowerCase();
                  final mode = (p['payment_method'] ?? '').toString().toLowerCase();
                  return num.contains(_searchTerm) || cust.contains(_searchTerm) || mode.contains(_searchTerm);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No payments recorded yet', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final pay = filtered[idx];
                    final payNum = pay['payment_number'] ?? 'PAY-${pay['id'].toString().substring(0, 6)}';
                    final custName = pay['customers']?['name'] ?? 'Walk-in Customer';
                    final amt = (pay['amount'] as num?)?.toDouble() ?? 0.0;
                    final mode = pay['payment_method'] ?? 'Cash';
                    final date = Formatters.parseAndFormatDate(pay['created_at'] ?? '');

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(num, style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'monospace', fontSize: 11.5, color: AppColors.deepLavender)),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Text(mode, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(custName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                              Text(date, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                            ],
                          ),
                          Text(
                            Formatters.currency(amt),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.deepMint),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
    );
  }
}
