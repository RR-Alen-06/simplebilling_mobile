import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';
import 'package:simplebilling_mobile/presentation/screens/customers/customer_details_screen.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  CustomerModel? _selectedCustomer;
  final TextEditingController _cashCtrl = TextEditingController();
  final TextEditingController _upiCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _cashCtrl.dispose();
    _upiCtrl.dispose();
    _notesCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  double get _enteredCash => double.tryParse(_cashCtrl.text.trim()) ?? 0.0;
  double get _enteredUpi => double.tryParse(_upiCtrl.text.trim()) ?? 0.0;
  double get _totalEntered => _enteredCash + _enteredUpi;

  void _quickFill(String mode, double amount) {
    setState(() {
      if (mode == 'cash') {
        _cashCtrl.text = amount.toStringAsFixed(2);
        _upiCtrl.clear();
      } else {
        _upiCtrl.text = amount.toStringAsFixed(2);
        _cashCtrl.clear();
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer first.')),
      );
      return;
    }

    if (_totalEntered <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter cash or UPI amount.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_enteredCash > 0) {
        await ApiRepository.recordCustomerPayment(
          customerId: _selectedCustomer!.id,
          amount: _enteredCash,
          paymentMethod: 'Cash',
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
      }

      if (_enteredUpi > 0) {
        await ApiRepository.recordCustomerPayment(
          customerId: _selectedCustomer!.id,
          amount: _enteredUpi,
          paymentMethod: 'UPI',
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment of ₹${_totalEntered.toStringAsFixed(2)} recorded successfully!')),
        );

        _cashCtrl.clear();
        _upiCtrl.clear();
        _notesCtrl.clear();
        setState(() => _selectedCustomer = null);

        ref.invalidate(paymentsProvider);
        ref.invalidate(customerSummariesProvider);
        ref.invalidate(customersProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record payment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerSummariesProvider);
    final paymentsAsync = ref.watch(paymentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payments & Collections', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(paymentsProvider);
              ref.invalidate(customerSummariesProvider);
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLarge = constraints.maxWidth >= 850;

          if (isLarge) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Record Payment Form (40%)
                SizedBox(
                  width: 380,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildPaymentForm(customersAsync),
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                // Right Column: Payments Ledger (60%)
                Expanded(
                  child: _buildPaymentsLedger(paymentsAsync),
                ),
              ],
            );
          }

          // Mobile View: Scrollable single column
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPaymentForm(customersAsync),
                const SizedBox(height: 20),
                _buildPaymentsLedger(paymentsAsync, shrinkWrap: true),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentForm(AsyncValue<List<CustomerModel>> customersAsync) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_card, color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Record Payment / Advance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Divider(height: 20),

          // Customer Selector
          customersAsync.when(
            data: (customers) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Customer *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<CustomerModel>(
                    initialValue: _selectedCustomer,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: 'Choose customer...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: customers.map((c) {
                      return DropdownMenuItem<CustomerModel>(
                        value: c,
                        child: Text(
                          '${c.name} ${c.mobile != null ? '(${c.mobile})' : ''}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCustomer = val;
                      });
                    },
                  ),

                  // Selected Customer Balance Overview
                  if (_selectedCustomer != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Balance Due:', style: TextStyle(fontSize: 12)),
                              Text(
                                Formatters.currency(_selectedCustomer!.balanceDue),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedCustomer!.balanceDue > 0 ? AppColors.error : AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Advance Balance:', style: TextStyle(fontSize: 12)),
                              Text(
                                Formatters.currency(_selectedCustomer!.advanceBalance),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                          if (_selectedCustomer!.balanceDue > 0) ...[
                            const Divider(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.secondary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () => _quickFill('cash', _selectedCustomer!.balanceDue),
                                    child: Text('⚡ Settle Cash (${Formatters.currency(_selectedCustomer!.balanceDue)})'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () => _quickFill('upi', _selectedCustomer!.balanceDue),
                                    child: Text('⚡ Settle UPI (${Formatters.currency(_selectedCustomer!.balanceDue)})'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, s) => Text('Error: $e'),
          ),

          const SizedBox(height: 16),

          // Payment Split Inputs
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cashCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Cash Paid (₹)',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _upiCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'UPI Paid (₹)',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Total Feedback
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Payment Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondary)),
                Text(
                  Formatters.currency(_totalEntered),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondary),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notes / Reference (Optional)',
              hintText: 'e.g. GPay ref #123456',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _isSubmitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline, size: 20),
            label: Text(
              _isSubmitting ? 'Recording Payment...' : 'Record Payment (${Formatters.currency(_totalEntered)})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            onPressed: (_isSubmitting || _totalEntered <= 0 || _selectedCustomer == null) ? null : _handleSubmit,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsLedger(AsyncValue<List<dynamic>> paymentsAsync, {bool shrinkWrap = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.history, color: AppColors.textPrimary, size: 20),
                  SizedBox(width: 8),
                  Text('Recent Payment Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              SizedBox(
                width: 160,
                height: 36,
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(fontSize: 12),
                  onChanged: (v) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search receipt...',
                    prefixIcon: const Icon(Icons.search, size: 16),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          paymentsAsync.when(
            data: (payments) {
              final query = _searchCtrl.text.toLowerCase().trim();
              final filtered = payments.where((p) {
                final matchNum = (p.paymentNumber ?? '').toLowerCase().contains(query);
                final matchCust = (p.customerName ?? '').toLowerCase().contains(query);
                final matchMethod = (p.paymentMethod ?? '').toLowerCase().contains(query);
                return matchNum || matchCust || matchMethod;
              }).toList();

              if (filtered.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.border),
                        SizedBox(height: 8),
                        Text('No payment records found', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: shrinkWrap,
                physics: shrinkWrap ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final pay = filtered[idx];
                  final isCash = pay.paymentMethod == 'Cash';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCash ? AppColors.secondary.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        pay.paymentMethod,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isCash ? AppColors.secondary : AppColors.primary,
                        ),
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          pay.customerName ?? 'Customer',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          Formatters.currency(pay.amount),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    subtitle: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          pay.paymentNumber ?? 'PAY-REC',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'monospace'),
                        ),
                        Text(
                          Formatters.parseAndFormatDate(pay.createdAt),
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    onTap: () {
                      if (pay.customerId.isNotEmpty) {
                        final customers = ref.read(customerSummariesProvider).value ?? [];
                        final cust = customers.firstWhere((c) => c.id == pay.customerId, orElse: () => CustomerModel(id: pay.customerId, name: pay.customerName ?? 'Customer'));
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (ctx) => CustomerDetailsScreen(customer: cust)),
                        );
                      }
                    },
                  );
                },
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, s) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }
}
