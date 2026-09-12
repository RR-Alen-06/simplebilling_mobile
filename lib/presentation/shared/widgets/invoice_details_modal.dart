import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/presentation/shared/printing/receipt_generator.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

class InvoiceDetailsModal extends ConsumerWidget {
  final BillModel bill;

  const InvoiceDetailsModal({super.key, required this.bill});

  static void show(BuildContext context, BillModel bill) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => InvoiceDetailsModal(bill: bill),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final shopSettings = settingsAsync.value?.shop;

    final remainingBalance = (bill.grandTotal - bill.paidTotal).clamp(0.0, double.infinity);
    final isFullyPaid = remainingBalance <= 0.01;
    final isPartiallyPaid = bill.paidTotal > 0 && remainingBalance > 0.01;

    final statusText = isFullyPaid
        ? 'Fully Paid'
        : isPartiallyPaid
            ? 'Partially Paid'
            : 'Payment Pending';

    final statusColor = isFullyPaid
        ? AppColors.secondary
        : isPartiallyPaid
            ? AppColors.warning
            : AppColors.error;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bill.billNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          Formatters.parseAndFormatDate(bill.createdAt),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Scrollable Receipt Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Shop & Customer Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              shopSettings?.shopName.isNotEmpty == true
                                  ? shopSettings!.shopName
                                  : 'SimpleBilling POS',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusColor),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (shopSettings?.address.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(shopSettings!.address, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                        if (shopSettings?.phone.isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text('Phone: ${shopSettings!.phone}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('CUSTOMER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  bill.customerName?.isNotEmpty == true ? bill.customerName! : 'Walk-in Customer',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                if (bill.customerMobile?.isNotEmpty == true)
                                  Text(bill.customerMobile!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('PAYMENT MODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  bill.paymentMethod,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Items List Table
                  const Text('ITEMS BREAKDOWN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                          ),
                          child: const Row(
                            children: [
                              Expanded(flex: 4, child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Expanded(flex: 2, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Expanded(flex: 2, child: Text('Price', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: bill.items.length,
                          separatorBuilder: (c, i) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final it = bill.items[idx];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Text(it.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text('${it.quantity % 1 == 0 ? it.quantity.toInt() : it.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text('₹${it.price.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text('₹${it.total.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bill Total & Breakdown
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow('Subtotal', Formatters.currency(bill.total)),
                        if (bill.discount > 0)
                          _buildSummaryRow('Discount', '- ${Formatters.currency(bill.discount)}', valueColor: AppColors.error),
                        if (bill.gstAmount > 0)
                          _buildSummaryRow('GST Tax', '+ ${Formatters.currency(bill.gstAmount)}'),
                        if (bill.roundingAdjustment != 0)
                          _buildSummaryRow(
                            'Rounding Adjustment',
                            '${bill.roundingAdjustment > 0 ? '+' : ''}${Formatters.currency(bill.roundingAdjustment)}',
                          ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(
                              Formatters.currency(bill.grandTotal),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3-Part Financial Summary (Ledger, Payment, Balance)
                  const Text('FINANCIAL SUMMARY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Payment Summary Box
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('1. Payments', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                              const SizedBox(height: 6),
                              _buildMiniRow('Cash:', Formatters.currency(bill.cashPaid)),
                              _buildMiniRow('UPI:', Formatters.currency(bill.upiPaid)),
                              if (bill.advanceUsed > 0)
                                _buildMiniRow('Advance:', Formatters.currency(bill.advanceUsed)),
                              const Divider(height: 10),
                              _buildMiniRow('Total Paid:', Formatters.currency(bill.paidTotal), isBold: true, color: AppColors.secondary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Balance Summary Box
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isFullyPaid ? AppColors.secondary.withValues(alpha: 0.05) : AppColors.warning.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isFullyPaid ? AppColors.secondary.withValues(alpha: 0.3) : AppColors.warning.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('2. Balance', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                              const SizedBox(height: 6),
                              _buildMiniRow('Status:', statusText, isBold: true, color: statusColor),
                              _buildMiniRow('Remaining:', Formatters.currency(remainingBalance), isBold: true, color: isFullyPaid ? AppColors.textPrimary : AppColors.error),
                              if (bill.advanceEarned > 0)
                                _buildMiniRow('Adv Added:', '+ ${Formatters.currency(bill.advanceEarned)}', color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Loyalty Summary (if earned/redeemed)
                  if (bill.loyaltyPointsEarned > 0 || bill.loyaltyPointsRedeemed > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.card_giftcard, color: Colors.amber, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Loyalty Reward', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                Text(
                                  'Earned: +${bill.loyaltyPointsEarned.toStringAsFixed(0)} pts'
                                  '${bill.loyaltyPointsRedeemed > 0 ? ' | Redeemed: -${bill.loyaltyPointsRedeemed.toStringAsFixed(0)} pts' : ''}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Action Buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: AppColors.secondary,
                      side: const BorderSide(color: AppColors.secondary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('WhatsApp Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      final shop = shopSettings ?? ShopSettings();
                      final billing = settingsAsync.value?.billing ?? BillingSettings();
                      ReceiptGenerator.shareViaWhatsApp(
                        bill: bill,
                        shop: shop,
                        billing: billing,
                        recipientPhone: bill.customerMobile,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('Print Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      final shop = shopSettings ?? ShopSettings();
                      final billing = settingsAsync.value?.billing ?? BillingSettings();
                      ReceiptGenerator.printReceipt(
                        bill: bill,
                        shop: shop,
                        billing: billing,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
