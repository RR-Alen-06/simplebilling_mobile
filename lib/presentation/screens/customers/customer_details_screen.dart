import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/core/utils/whatsapp_sender.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
import 'package:simplebilling_mobile/data/models/payment_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

class CustomerDetailsScreen extends ConsumerStatefulWidget {
  final CustomerModel customer;

  const CustomerDetailsScreen({super.key, required this.customer});

  @override
  ConsumerState<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends ConsumerState<CustomerDetailsScreen> {
  late CustomerModel _customer;
  List<CustomerLedgerEntryModel> _ledgerEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    setState(() => _isLoading = true);
    try {
      final entries = await ApiRepository.getCustomerLedger(_customer.id);
      final summaries = await ApiRepository.getCustomerSummaries();
      final updatedCust = summaries.firstWhere(
        (c) => c.id == _customer.id,
        orElse: () => _customer,
      );

      if (mounted) {
        setState(() {
          _ledgerEntries = entries;
          _customer = updatedCust;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRecordPaymentDialog() {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String paymentMode = 'Cash';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet, color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Record Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_customer.balanceDue > 0)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Outstanding Due:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(
                          Formatters.currency(_customer.balanceDue),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.error),
                        ),
                      ],
                    ),
                  ),

                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Payment Amount (₹) *',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                const Text('Payment Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Row(
                  children: ['Cash', 'UPI'].map((mode) {
                    final isSelected = paymentMode == mode;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(mode, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppColors.textPrimary)),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          onSelected: (val) {
                            if (val) setDialogState(() => paymentMode = mode);
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Reference (Optional)',
                    hintText: 'e.g. UPI Ref #123456',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                      if (amt <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid payment amount.')),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);

                      final res = await ApiRepository.recordCustomerPayment(
                        customerId: _customer.id,
                        amount: amt,
                        paymentMethod: paymentMode,
                        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      );

                      if (mounted) {
                        nav.pop();
                        if (res != null) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Payment of ₹$amt recorded successfully!')),
                          );
                          ref.invalidate(customerSummariesProvider);
                          ref.invalidate(customersProvider);
                          ref.invalidate(paymentsProvider);
                          _loadLedger();
                        } else {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Failed to record payment.')),
                          );
                        }
                      }
                    },
              child: Text(isSubmitting ? 'Recording...' : 'Record Payment'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCustomerDialog() {
    final nameCtrl = TextEditingController(text: _customer.name);
    final mobileCtrl = TextEditingController(text: _customer.mobile ?? '');
    final emailCtrl = TextEditingController(text: _customer.email ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Customer Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Customer Name *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mobileCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile Number', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      setDialogState(() => isSaving = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);

                      final ok = await ApiRepository.updateCustomer(
                        _customer.id,
                        name: nameCtrl.text.trim(),
                        mobile: mobileCtrl.text.trim().isEmpty ? null : mobileCtrl.text.trim(),
                        email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                      );
                      if (mounted) {
                        nav.pop();
                        if (ok) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Customer updated successfully!')),
                          );
                          ref.invalidate(customersProvider);
                          ref.invalidate(customerSummariesProvider);
                          _loadLedger();
                        }
                      }
                    },
              child: Text(isSaving ? 'Saving...' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: _showEditCustomerDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Ledger',
            onPressed: _loadLedger,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Customer Header Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _customer.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                if (_customer.customerCode != null)
                                  Text(
                                    _customer.customerCode!,
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.stars, color: Colors.amber, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_customer.loyaltyPoints.toStringAsFixed(0)} pts',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_customer.mobile != null && _customer.mobile!.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(_customer.mobile!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            ],
                          ),
                        if (_customer.email != null && _customer.email!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.email_outlined, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(_customer.email!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Financial KPI Cards Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Total Billed',
                          value: Formatters.currency(_customer.totalBilled),
                          icon: Icons.receipt_long,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Total Paid',
                          value: Formatters.currency(_customer.totalPaid),
                          icon: Icons.check_circle_outline,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Balance Due',
                          value: Formatters.currency(_customer.balanceDue),
                          icon: Icons.warning_amber_rounded,
                          color: _customer.balanceDue > 0 ? AppColors.error : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Advance Balance',
                          value: Formatters.currency(_customer.advanceBalance),
                          icon: Icons.account_balance_wallet_outlined,
                          color: _customer.advanceBalance > 0 ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.add_card, size: 18),
                          label: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: _showRecordPaymentDialog,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (_customer.mobile != null && _customer.mobile!.isNotEmpty)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.secondary,
                            side: const BorderSide(color: AppColors.secondary),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.chat_outlined, size: 18),
                          label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () {
                            WhatsAppSender.sendCustomerDueReminder(
                              phone: _customer.mobile!,
                              customerName: _customer.name,
                              pendingBalance: _customer.balanceDue,
                            );
                          },
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Running Ledger Timeline
                  const Text('RUNNING LEDGER HISTORY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),

                  if (_ledgerEntries.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.history, size: 40, color: AppColors.border),
                          SizedBox(height: 10),
                          Text('No transactions recorded yet', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _ledgerEntries.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) {
                        final entry = _ledgerEntries[idx];
                        final isBill = entry.type == 'BILL';

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isBill ? AppColors.primary.withValues(alpha: 0.1) : AppColors.secondary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          entry.type,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isBill ? AppColors.primary : AppColors.secondary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(entry.referenceNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                  Text(
                                    Formatters.parseAndFormatDate(entry.date),
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(entry.description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const Divider(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (entry.billAmount > 0)
                                    Text('Bill: ${Formatters.currency(entry.billAmount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  if (entry.paidAmount > 0)
                                    Text('Paid: ${Formatters.currency(entry.paidAmount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                                  Row(
                                    children: [
                                      const Text('Balance: ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      Text(
                                        entry.runningBalance > 0.01
                                            ? '${Formatters.currency(entry.runningBalance)} Due'
                                            : entry.runningBalance < -0.01
                                                ? '${Formatters.currency(entry.runningBalance.abs())} Adv'
                                                : '₹0.00',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: entry.runningBalance > 0.01 ? AppColors.error : AppColors.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
