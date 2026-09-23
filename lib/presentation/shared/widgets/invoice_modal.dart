import 'package:flutter/material.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/core/utils/whatsapp_sender.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/presentation/shared/printing/receipt_generator.dart';

class InvoiceModal {
  InvoiceModal._();

  static void show(
    BuildContext context, {
    required BillModel bill,
    required AllSettings settings,
    double allocatedToPrevDue = 0.0,
    double savedToAdvance = 0.0,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.deepMint, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                bill.billNumber.startsWith('OFFLINE') ? 'Invoice Queued (Offline)' : 'Invoice Details',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Invoice: ${bill.billNumber}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                        Text(Formatters.parseAndFormatDate(bill.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Grand Total:', style: TextStyle(fontWeight: FontWeight.w700)),
                        Text(Formatters.currency(bill.grandTotal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Paid: ${Formatters.currency(bill.paidTotal)} via ${bill.paymentMethod}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    if (bill.customerName != null) ...[
                      const SizedBox(height: 4),
                      Text('Customer: ${bill.customerName} (${bill.customerMobile ?? "-"})', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Items breakdown preview
              if (bill.items.isNotEmpty) ...[
                const Text('Billed Items:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: bill.items.length,
                    separatorBuilder: (c, i) => const Divider(height: 8, color: AppColors.border),
                    itemBuilder: (c, i) {
                      final it = bill.items[i];
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${it.quantity.toStringAsFixed(it.quantity.truncateToDouble() == it.quantity ? 0 : 2)}x ${it.productName}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(Formatters.currency(it.total), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Overpayment feedback badges
              if (allocatedToPrevDue > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.pastelAmber,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.deepAmber),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 14, color: AppColors.deepAmber),
                      const SizedBox(width: 6),
                      Text('₹${allocatedToPrevDue.toStringAsFixed(2)} allocated to previous dues', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.deepAmber)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (savedToAdvance > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.pastelMint,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.deepMint),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppColors.deepMint),
                      const SizedBox(width: 6),
                      Text('₹${savedToAdvance.toStringAsFixed(2)} credited to advance wallet', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.deepMint)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],

              const Text('Print & Distribution Hub:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 8),

              // Actions
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('WhatsApp Text', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    onPressed: () {
                      WhatsAppSender.sendInvoice(
                        bill: bill,
                        shop: settings.shop,
                        billing: settings.billing,
                      );
                    },
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepLavender,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('Share PDF File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    onPressed: () {
                      ReceiptGenerator.sharePdfInvoiceFile(
                        bill: bill,
                        shop: settings.shop,
                        billing: settings.billing,
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.deepMint,
                      side: const BorderSide(color: AppColors.deepMint),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Thermal 80mm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    onPressed: () {
                      ReceiptGenerator.print80mmReceipt(
                        bill: bill,
                        shop: settings.shop,
                        billing: settings.billing,
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.deepSky,
                      side: const BorderSide(color: AppColors.deepSky),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Thermal 58mm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    onPressed: () {
                      ReceiptGenerator.print58mmReceipt(
                        bill: bill,
                        shop: settings.shop,
                        billing: settings.billing,
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.deepLavender,
                      side: const BorderSide(color: AppColors.deepLavender),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                    label: const Text('A4 Tax Invoice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    onPressed: () {
                      ReceiptGenerator.printA4Invoice(
                        bill: bill,
                        shop: settings.shop,
                        billing: settings.billing,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
