import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/core/utils/whatsapp_sender.dart';
import 'package:simplebilling_mobile/core/utils/esc_pos_generator.dart';

class ReceiptGenerator {
  ReceiptGenerator._();

  /// Share invoice receipt directly via WhatsApp
  static Future<bool> shareViaWhatsApp({
    required BillModel bill,
    required ShopSettings shop,
    required BillingSettings billing,
    String? recipientPhone,
  }) async {
    return await WhatsAppSender.sendInvoice(
      bill: bill,
      shop: shop,
      billing: billing,
      recipientPhone: recipientPhone,
    );
  }

  /// Get raw ESC/POS bytes for Bluetooth / Network direct thermal POS printer
  static Uint8List getEscPosBytes({
    required BillModel bill,
    required ShopSettings shop,
    required BillingSettings billing,
    int paperWidthCols = 42,
  }) {
    return EscPosGenerator.generateReceiptBytes(
      bill: bill,
      shop: shop,
      billing: billing,
      paperWidthCols: paperWidthCols,
    );
  }

  /// Print PDF Receipt (80mm Thermal or A4 Tax Invoice)
  static Future<void> printReceipt({
    required BillModel bill,
    required ShopSettings shop,
    required BillingSettings billing,
    bool? forceA4,
  }) async {
    final isThermal = forceA4 == true ? false : billing.defaultPrinterSize.toLowerCase().contains('80');
    final pdf = isThermal ? _generateThermalReceipt(bill, shop, billing) : _generateA4Invoice(bill, shop, billing);

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice_${bill.billNumber}.pdf',
    );
  }

  static pw.Document _generateThermalReceipt(BillModel bill, ShopSettings shop, BillingSettings billing) {
    final pdf = pw.Document();
    final curr = billing.currencySymbol.isNotEmpty ? billing.currencySymbol : 'Rs.';

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  shop.shopName.toUpperCase(),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              if (shop.address.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    shop.address,
                    style: const pw.TextStyle(fontSize: 8.5),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              if (shop.phone.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    'Phone: ${shop.phone}',
                    style: const pw.TextStyle(fontSize: 8.5),
                  ),
                ),
              if (shop.gstNumber.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    'GSTIN: ${shop.gstNumber}',
                    style: const pw.TextStyle(fontSize: 8.5),
                  ),
                ),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Bill: ${bill.billNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                  pw.Text(Formatters.parseAndFormatDate(bill.createdAt), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              if (bill.customerName != null && bill.customerName!.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text('Customer: ${bill.customerName} (${bill.customerMobile ?? '-'})', style: const pw.TextStyle(fontSize: 8.5)),
                ),
              pw.Divider(thickness: 0.5),
              pw.Row(
                children: [
                  pw.Expanded(flex: 5, child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5))),
                  pw.Expanded(flex: 2, child: pw.Text('Qty', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5))),
                  pw.Expanded(flex: 2, child: pw.Text('Rate', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5))),
                  pw.Expanded(flex: 3, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5))),
                ],
              ),
              pw.Divider(thickness: 0.3),
              ...bill.items.map((it) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                    child: pw.Row(
                      children: [
                        pw.Expanded(flex: 5, child: pw.Text(it.productName, style: const pw.TextStyle(fontSize: 8))),
                        pw.Expanded(flex: 2, child: pw.Text(it.quantity.toStringAsFixed(0), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                        pw.Expanded(flex: 2, child: pw.Text(it.price.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                        pw.Expanded(flex: 3, child: pw.Text(it.total.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                      ],
                    ),
                  )),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 8.5)),
                  pw.Text('$curr ${bill.total.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8.5)),
                ],
              ),
              if (bill.discount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Discount:', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.Text('- $curr ${bill.discount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8.5)),
                  ],
                ),
              if (bill.gstAmount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('GST Tax:', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.Text('+ $curr ${bill.gstAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8.5)),
                  ],
                ),
              if (bill.roundingAdjustment != 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Rounding:', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.Text('${bill.roundingAdjustment > 0 ? '+' : ''}$curr ${bill.roundingAdjustment.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8.5)),
                  ],
                ),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('GRAND TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10.5)),
                  pw.Text('$curr ${bill.grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10.5)),
                ],
              ),
              pw.Divider(thickness: 0.5),
              pw.Text('Paid Total: $curr ${bill.paidTotal.toStringAsFixed(2)} (${bill.paymentMethod})', style: const pw.TextStyle(fontSize: 8)),
              if (bill.cashPaid > 0) pw.Text('Cash: $curr ${bill.cashPaid.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7.5)),
              if (bill.upiPaid > 0) pw.Text('UPI: $curr ${bill.upiPaid.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7.5)),
              if (bill.advanceUsed > 0) pw.Text('Advance Used: $curr ${bill.advanceUsed.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7.5)),
              if (bill.advanceEarned > 0) pw.Text('Advance Credited: $curr ${bill.advanceEarned.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7.5)),
              if (bill.loyaltyPointsEarned > 0) pw.Text('Points Earned: +${bill.loyaltyPointsEarned.toStringAsFixed(0)} pts', style: const pw.TextStyle(fontSize: 7.5)),
              pw.SizedBox(height: 6),
              if (shop.footerMessage.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    shop.footerMessage,
                    style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 7.5),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  static pw.Document _generateA4Invoice(BillModel bill, ShopSettings shop, BillingSettings billing) {
    final pdf = pw.Document();
    final curr = billing.currencySymbol.isNotEmpty ? billing.currencySymbol : 'Rs.';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(shop.shopName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: PdfColors.blue800)),
                      if (shop.address.isNotEmpty) pw.Text(shop.address, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      if (shop.phone.isNotEmpty) pw.Text('Phone: ${shop.phone}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      if (shop.email.isNotEmpty) pw.Text('Email: ${shop.email}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      if (shop.gstNumber.isNotEmpty) pw.Text('GSTIN: ${shop.gstNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blueGrey800)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('TAX INVOICE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.grey800)),
                      pw.SizedBox(height: 4),
                      pw.Text('Invoice #: ${bill.billNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.Text('Date: ${Formatters.parseAndFormatDate(bill.createdAt)}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Payment Mode: ${bill.paymentMethod}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              // Customer Box
              if (bill.customerName != null && bill.customerName!.isNotEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Billed To: ${bill.customerName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.Text('Mobile: ${bill.customerMobile ?? '-'}', style: const pw.TextStyle(fontSize: 10)),
                      if (bill.customerEmail != null && bill.customerEmail!.isNotEmpty)
                        pw.Text('Email: ${bill.customerEmail}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              pw.SizedBox(height: 12),
              // Items Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('#', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Item Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Qty', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rate ($curr)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total ($curr)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    ],
                  ),
                  ...bill.items.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final it = entry.value;
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(idx.toString(), style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(it.productName, style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(it.quantity.toStringAsFixed(0), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(it.price.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(it.total.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 12),
              // Summary & Financials
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 6,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Payment Breakdown:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                        pw.SizedBox(height: 2),
                        if (bill.cashPaid > 0) pw.Text('• Cash Paid: $curr ${bill.cashPaid.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                        if (bill.upiPaid > 0) pw.Text('• UPI Paid: $curr ${bill.upiPaid.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                        if (bill.advanceUsed > 0) pw.Text('• Advance Deducted: $curr ${bill.advanceUsed.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                        if (bill.advanceEarned > 0) pw.Text('• Advance Credited: $curr ${bill.advanceEarned.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                        if (bill.loyaltyPointsEarned > 0) pw.Text('• Loyalty Points Earned: +${bill.loyaltyPointsEarned.toStringAsFixed(0)} pts', style: const pw.TextStyle(fontSize: 9)),
                        pw.SizedBox(height: 12),
                        if (shop.footerMessage.isNotEmpty)
                          pw.Text(shop.footerMessage, style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 8.5, color: PdfColors.grey700)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    flex: 5,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5)),
                      child: pw.Column(
                        children: [
                          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                            pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 9.5)),
                            pw.Text('$curr ${bill.total.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9.5)),
                          ]),
                          if (bill.discount > 0) ...[
                            pw.SizedBox(height: 2),
                            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                              pw.Text('Discount:', style: const pw.TextStyle(fontSize: 9.5)),
                              pw.Text('- $curr ${bill.discount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9.5)),
                            ]),
                          ],
                          if (bill.gstAmount > 0) ...[
                            pw.SizedBox(height: 2),
                            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                              pw.Text('GST Tax:', style: const pw.TextStyle(fontSize: 9.5)),
                              pw.Text('+ $curr ${bill.gstAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9.5)),
                            ]),
                          ],
                          if (bill.roundingAdjustment != 0) ...[
                            pw.SizedBox(height: 2),
                            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                              pw.Text('Rounding:', style: const pw.TextStyle(fontSize: 9.5)),
                              pw.Text('${bill.roundingAdjustment > 0 ? '+' : ''}$curr ${bill.roundingAdjustment.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9.5)),
                            ]),
                          ],
                          pw.Divider(thickness: 0.5),
                          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                            pw.Text('GRAND TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                            pw.Text('$curr ${bill.grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          ]),
                          pw.Divider(thickness: 0.5),
                          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                            pw.Text('Amount Paid:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                            pw.Text('$curr ${bill.paidTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Text('E. & O.E.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                ],
              ),
            ],
          );
        },
      ),
    );
    return pdf;
  }
}
