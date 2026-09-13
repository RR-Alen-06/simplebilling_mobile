import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/core/utils/whatsapp_sender.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
import 'package:simplebilling_mobile/data/models/customer_ledger_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

final customerDetailProvider = FutureProvider.family<CustomerModel?, String>((ref, id) async {
  return await ApiRepository.getCustomer(id);
});

final customerLedgerProvider = FutureProvider.family<List<CustomerLedgerEntry>, String>((ref, id) async {
  return await ApiRepository.getCustomerLedger(id);
});

class CustomerLedgerScreen extends ConsumerStatefulWidget {
  final String customerId;
  const CustomerLedgerScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends ConsumerState<CustomerLedgerScreen> {
  void _showRecordPaymentDialog(CustomerModel customer) {
    final amountCtrl = TextEditingController(
      text: customer.balanceDue > 0 ? customer.balanceDue.toStringAsFixed(2) : '',
    );
    final notesCtrl = TextEditingController(text: 'Credit settlement against pending dues');
    String paymentMode = 'Cash';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.pastelMint,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.deepMint),
                ),
                child: const Icon(Icons.payments_rounded, color: AppColors.deepMint, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Record Credit Payment', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Outstanding Dues:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      Text(
                        Formatters.currency(customer.balanceDue),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.deepCoral),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Payment Amount (₹) *',
                    prefixIcon: const Icon(Icons.currency_rupee, color: AppColors.primary, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Payment Mode:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.attach_money_rounded, size: 16, color: AppColors.deepMint),
                        label: const Center(child: Text('Cash', style: TextStyle(fontWeight: FontWeight.w800))),
                        selected: paymentMode == 'Cash',
                        selectedColor: AppColors.pastelMint,
                        onSelected: (val) {
                          if (val) setModalState(() => paymentMode = 'Cash');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.qr_code_2_rounded, size: 16, color: AppColors.deepSky),
                        label: const Center(child: Text('UPI / QR', style: TextStyle(fontWeight: FontWeight.w800))),
                        selected: paymentMode == 'UPI',
                        selectedColor: AppColors.pastelSky,
                        onSelected: (val) {
                          if (val) setModalState(() => paymentMode = 'UPI');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(
                    labelText: 'Notes / Remarks (Optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                      if (amt <= 0) return;

                      setModalState(() => isSubmitting = true);
                      final success = await ApiRepository.recordCustomerPayment(
                        customerId: customer.id,
                        amount: amt,
                        paymentMode: paymentMode,
                        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      );

                      if (mounted) {
                        ref.invalidate(customerDetailProvider(widget.customerId));
                        ref.invalidate(customerLedgerProvider(widget.customerId));
                        ref.invalidate(customerSummariesProvider);
                        ref.invalidate(customersProvider);
                        ref.invalidate(billsListProvider);

                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Payment of ₹${amt.toStringAsFixed(2)} recorded & settled! 💰'
                                  : 'Failed to record payment.',
                            ),
                          ),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm Payment'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(customerDetailProvider(widget.customerId));
    final ledgerAsync = ref.watch(customerLedgerProvider(widget.customerId));
    final settings = ref.watch(settingsProvider).valueOrNull ??
        AllSettings(shop: ShopSettings(), billing: BillingSettings(), loyalty: LoyaltySettings());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Customer Ledger & Statement',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Ledger',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: () {
              ref.invalidate(customerDetailProvider(widget.customerId));
              ref.invalidate(customerLedgerProvider(widget.customerId));
            },
          ),
        ],
      ),
      body: customerAsync.when(
        data: (customer) {
          if (customer == null) {
            return const Center(child: Text('Customer not found.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A. Account Header & Profile Card
                _buildCustomerProfileHeader(customer, settings),
                const SizedBox(height: 12),

                // Aggregated Financial Metrics (KPI Cards)
                _buildKpiMetricsRow(customer),
                const SizedBox(height: 14),

                // B. Chronological Ledger History Timeline
                _buildLedgerTimelineSection(ledgerAsync),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Error loading customer: $err')),
      ),
    );
  }

  // --- A. PROFILE HEADER ---
  Widget _buildCustomerProfileHeader(CustomerModel customer, AllSettings settings) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neoBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.pastelLavender,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLavender),
                ),
                child: Center(
                  child: Text(
                    customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.deepLavender),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            customer.name,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (customer.customerCode != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.pastelSky,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                customer.customerCode!,
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.deepSky),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${customer.mobile ?? "No phone"} • ${customer.email ?? "No email"}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.payments_rounded, size: 16),
                label: const Text('+ Record Payment', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                onPressed: () => _showRecordPaymentDialog(customer),
              ),
              if (customer.balanceDue > 0)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.deepCoral,
                    backgroundColor: AppColors.pastelCoral.withValues(alpha: 0.5),
                    side: const BorderSide(color: AppColors.deepCoral, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 15),
                  label: const Text('Send WhatsApp Due Reminder', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  onPressed: () {
                    WhatsAppSender.sendDuePaymentReminder(
                      customer: customer,
                      shop: settings.shop,
                      billing: settings.billing,
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- KPI CARDS ROW ---
  Widget _buildKpiMetricsRow(CustomerModel customer) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;

        final cards = [
          _buildMetricCard(
            title: 'TOTAL BILLED',
            value: Formatters.currency(customer.totalBilled),
            subtitle: 'Lifetime invoices',
            icon: Icons.receipt_long_rounded,
            bgColor: AppColors.pastelSky,
            textColor: AppColors.deepSky,
            borderColor: AppColors.borderSky,
          ),
          _buildMetricCard(
            title: 'TOTAL PAID',
            value: Formatters.currency(customer.totalPaid),
            subtitle: 'Direct settlements',
            icon: Icons.check_circle_outline_rounded,
            bgColor: AppColors.pastelMint,
            textColor: AppColors.deepMint,
            borderColor: AppColors.borderMint,
          ),
          _buildMetricCard(
            title: 'CURRENT BALANCE DUE',
            value: Formatters.currency(customer.balanceDue),
            subtitle: customer.balanceDue > 0 ? 'Outstanding Udhar' : 'Fully Cleared ✓',
            icon: Icons.pending_actions_rounded,
            bgColor: customer.balanceDue > 0 ? AppColors.pastelCoral : AppColors.pastelMint,
            textColor: customer.balanceDue > 0 ? AppColors.deepCoral : AppColors.deepMint,
            borderColor: customer.balanceDue > 0 ? AppColors.borderCoral : AppColors.borderMint,
          ),
          _buildMetricCard(
            title: 'ADVANCE WALLET',
            value: Formatters.currency(customer.advanceBalance),
            subtitle: 'Store credit balance',
            icon: Icons.account_balance_wallet_rounded,
            bgColor: AppColors.pastelAmber,
            textColor: AppColors.deepAmber,
            borderColor: AppColors.borderAmber,
          ),
        ];

        if (isWide) {
          return Row(
            children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
          );
        }

        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cards,
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: textColor), overflow: TextOverflow.ellipsis),
              ),
              Icon(icon, size: 16, color: textColor),
            ],
          ),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: textColor)),
          Text(subtitle, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor.withValues(alpha: 0.85))),
        ],
      ),
    );
  }

  // --- B. CHRONOLOGICAL LEDGER HISTORY TIMELINE ---
  Widget _buildLedgerTimelineSection(AsyncValue<List<CustomerLedgerEntry>> ledgerAsync) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neoBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, color: AppColors.deepSky, size: 20),
              SizedBox(width: 8),
              Text('Chronological Account Statement', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          ledgerAsync.when(
            data: (entries) {
              if (entries.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No ledger history recorded for this customer.', style: TextStyle(color: AppColors.textMuted)),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                separatorBuilder: (c, i) => const Divider(height: 16, color: AppColors.border),
                itemBuilder: (ctx, i) {
                  final entry = entries[i];
                  final isBill = entry.type == LedgerEntryType.bill;
                  final parsedDate = DateTime.tryParse(entry.date) ?? DateTime.now();
                  final dateFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(parsedDate);

                  Color badgeBg = isBill ? AppColors.pastelSky : AppColors.pastelMint;
                  Color badgeText = isBill ? AppColors.deepSky : AppColors.deepMint;

                  Color balanceColor = entry.balanceType == LedgerBalanceType.due
                      ? AppColors.deepCoral
                      : (entry.balanceType == LedgerBalanceType.adv ? AppColors.deepMint : AppColors.textSecondary);

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isBill ? 'BILL' : 'PAYMENT',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10.5, color: badgeText),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entry.referenceNumber} • ${entry.description}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateFormatted,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            if (entry.notes != null && entry.notes!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Note: ${entry.notes}',
                                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Debit / Credit & Running Balance
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (isBill)
                            Text(
                              '+ ₹${entry.billAmount.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary),
                            )
                          else
                            Text(
                              '- ₹${entry.paidAmount.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.deepMint),
                            ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: entry.balanceType == LedgerBalanceType.due
                                  ? AppColors.pastelCoral
                                  : (entry.balanceType == LedgerBalanceType.adv ? AppColors.pastelMint : AppColors.background),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              entry.balanceType == LedgerBalanceType.due
                                  ? '₹${entry.runningBalance.toStringAsFixed(2)} DUE'
                                  : (entry.balanceType == LedgerBalanceType.adv
                                      ? '₹${entry.runningBalance.toStringAsFixed(2)} ADV'
                                      : '₹0.00 SETTLED'),
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: balanceColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            error: (err, _) => Text('Error loading statement: $err'),
          ),
        ],
      ),
    );
  }
}
