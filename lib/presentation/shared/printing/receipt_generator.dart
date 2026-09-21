import 'dart:typed_data';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
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

  /// Print 80mm Thermal Receipt
  static Future<void> print80mmReceipt({
    required BillModel bill,
    required ShopSettings shop,
    required BillingSettings billing,
  }) async {
    final pdf = _generateThermalReceipt(bill, shop, billing, paperWidthMm: 80);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Receipt_80mm_${bill.billNumber}.pdf',
    );
  }

  /// Print 58mm Thermal Receipt
  static Future<void> print58mmReceipt({
    required BillModel bill,
    required ShopSettings shop,
    required BillingSettings billing,
  }) async {
    final pdf = _generateThermalReceipt(bill, shop, billing, paperWidthMm: 58);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Receipt_58mm_${bill.billNumber}.pdf',
    );
  }

  /// Print Standard A4 Tax Invoice
  static Future<void> printA4Invoice({
    required BillModel bill,
    required ShopSettings shop,
    required BillingSettings billing,
  }) async {
    final pdf = _generateA4Invoice(bill, shop, billing);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice_A4_${bill.billNumber}.pdf',
    );
  }

  /// Print Standard A4 Customer Consolidated Purchase Statement PDF
  static Future<void> printCustomerStatementPdf({
    required CustomerModel customer,
    required List<BillModel> customerBills,
    required ShopSettings shop,
    required BillingSettings billing,
    DateTimeRange? dateRange,
  }) async {
    final pdf = _generateCustomerStatementPdf(
      customer: customer,
      bills: customerBills,
      shop: shop,
      billing: billing,
      dateRange: dateRange,
    );
    final safeCustName = customer.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Statement_${safeCustName}_${DateTime.now().toIso8601String().split('T')[0]}.pdf',
    );
  }

  /// Print PDF Receipt (80mm Thermal or A4 Tax Invoice based on settings)
  static Future<void> printReceipt({
    required BillModel bill,
    required ShopSettings shop,
    required BillingSettings billing,
    bool? forceA4,
  }) async {
    if (forceA4 == true) {
      await printA4Invoice(bill: bill, shop: shop, billing: billing);
      return;
    }
    if (billing.defaultPrinterSize == '58mm') {
      await print58mmReceipt(bill: bill, shop: shop, billing: billing);
    } else {
      await print80mmReceipt(bill: bill, shop: shop, billing: billing);
    }
  }

  static pw.Document _generateThermalReceipt(
    BillModel bill,
    ShopSettings shop,
    BillingSettings billing, {
    double paperWidthMm = 80,
  }) {
    final pdf = pw.Document();
    final curr = billing.currencySymbol.isNotEmpty ? billing.currencySymbol : 'Rs.';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(paperWidthMm * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
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

  /// Print A4 Business Sales Report PDF
  static Future<void> printSalesReport({
    required List<BillModel> bills,
    required ShopSettings shop,
    required BillingSettings billing,
    required String periodTitle,
  }) async {
    final pdf = pw.Document();
    final curr = billing.currencySymbol.isNotEmpty ? billing.currencySymbol : 'Rs.';
    final totalSales = bills.fold(0.0, (s, b) => s + b.grandTotal);
    final totalCash = bills.fold(0.0, (s, b) => s + b.cashPaid);
    final totalUpi = bills.fold(0.0, (s, b) => s + b.upiPaid);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) => [
          // Business Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(shop.shopName.isNotEmpty ? shop.shopName : 'SIMPLE BILLING', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  if (shop.address.isNotEmpty) pw.Text(shop.address, style: const pw.TextStyle(fontSize: 9)),
                  if (shop.phone.isNotEmpty) pw.Text('Phone: ${shop.phone}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('SALES & INVOICES REPORT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  pw.Text('Period: $periodTitle', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Text('Generated: ${DateTime.now().toString().split('.')[0]}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
          pw.Divider(thickness: 1, height: 16),
          // KPI Summary Box
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(children: [
                  pw.Text('TOTAL SALES', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('$curr ${totalSales.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${bills.length} Bills', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                ]),
                pw.Column(children: [
                  pw.Text('CASH PAID', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('$curr ${totalCash.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ]),
                pw.Column(children: [
                  pw.Text('UPI PAID', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('$curr ${totalUpi.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ]),
                pw.Column(children: [
                  pw.Text('AVG BILL VALUE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('$curr ${(bills.isNotEmpty ? totalSales / bills.length : 0.0).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          // Transaction Table
          pw.TableHelper.fromTextArray(
            headers: ['Bill No', 'Date & Time', 'Customer', 'Method', 'Cash', 'UPI', 'Total', 'Status'],
            data: bills.map((b) => [
              b.billNumber,
              b.createdAt.length >= 16 ? b.createdAt.substring(0, 16).replaceAll('T', ' ') : b.createdAt,
              b.customerName ?? 'Walk-in',
              b.paymentMethod,
              '$curr ${b.cashPaid.toStringAsFixed(2)}',
              '$curr ${b.upiPaid.toStringAsFixed(2)}',
              '$curr ${b.grandTotal.toStringAsFixed(2)}',
              b.balanceDue <= 0 ? 'Fully Paid' : 'Pending',
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.center,
            },
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Sales_Report_${periodTitle.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Print A4 Item Sales Breakdown PDF
  static Future<void> printItemSalesReport({
    required List<Map<String, dynamic>> itemSales,
    required ShopSettings shop,
    required BillingSettings billing,
    required String periodTitle,
    required double totalPeriodRevenue,
  }) async {
    final pdf = pw.Document();
    final curr = billing.currencySymbol.isNotEmpty ? billing.currencySymbol : 'Rs.';
    final totalUnits = itemSales.fold(0.0, (s, i) => s + ((i['qty'] as num?)?.toDouble() ?? 0.0));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) => [
          // Business Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(shop.shopName.isNotEmpty ? shop.shopName : 'SIMPLE BILLING', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  if (shop.address.isNotEmpty) pw.Text(shop.address, style: const pw.TextStyle(fontSize: 9)),
                  if (shop.phone.isNotEmpty) pw.Text('Phone: ${shop.phone}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('PRODUCT & SERVICE PERFORMANCE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  pw.Text('Period: $periodTitle', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Text('Generated: ${DateTime.now().toString().split('.')[0]}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
          pw.Divider(thickness: 1, height: 16),
          // KPI Summary Box
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(children: [
                  pw.Text('TOTAL REVENUE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('$curr ${totalPeriodRevenue.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ]),
                pw.Column(children: [
                  pw.Text('TOTAL UNITS SOLD', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${totalUnits.toStringAsFixed(0)} Units', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ]),
                pw.Column(children: [
                  pw.Text('UNIQUE ITEMS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${itemSales.length} Items', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          // Item Breakdown Table
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Product / Service Name', 'Units Sold', 'Revenue Generated', 'Revenue Share (%)'],
            data: itemSales.asMap().entries.map((e) {
              final idx = e.key + 1;
              final it = e.value;
              final qty = (it['qty'] as num?)?.toDouble() ?? 0.0;
              final rev = (it['revenue'] as num?)?.toDouble() ?? 0.0;
              final share = (it['share'] as num?)?.toDouble() ?? 0.0;
              return [
                '$idx',
                it['name']?.toString() ?? 'Item',
                qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2),
                '$curr ${rev.toStringAsFixed(2)}',
                '${share.toStringAsFixed(1)}%',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Item_Sales_Report_${periodTitle.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Print A4 Customer Outstanding Dues PDF
  static Future<void> printCustomerDuesReport({
    required List<CustomerModel> dueCustomers,
    required ShopSettings shop,
    required BillingSettings billing,
    required double totalUncollectedDues,
  }) async {
    final pdf = pw.Document();
    final curr = billing.currencySymbol.isNotEmpty ? billing.currencySymbol : 'Rs.';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) => [
          // Business Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(shop.shopName.isNotEmpty ? shop.shopName : 'SIMPLE BILLING', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  if (shop.address.isNotEmpty) pw.Text(shop.address, style: const pw.TextStyle(fontSize: 9)),
                  if (shop.phone.isNotEmpty) pw.Text('Phone: ${shop.phone}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('CUSTOMER OUTSTANDING DUES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  pw.Text('Audited: ${DateTime.now().toString().split('.')[0]}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
          pw.Divider(thickness: 1, height: 16),
          // KPI Summary Box
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(children: [
                  pw.Text('TOTAL UNCOLLECTED DUES', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('$curr ${totalUncollectedDues.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                ]),
                pw.Column(children: [
                  pw.Text('CUSTOMERS WITH DUES', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${dueCustomers.length} Accounts', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          // Customer Dues Table
          pw.TableHelper.fromTextArray(
            headers: ['Customer Name', 'Mobile / Contact', 'Total Billed', 'Total Paid', 'Pending Balance Due'],
            data: dueCustomers.map((c) => [
              c.name,
              c.mobile ?? c.email ?? '-',
              '$curr ${c.totalBilled.toStringAsFixed(2)}',
              '$curr ${c.totalPaid.toStringAsFixed(2)}',
              '$curr ${c.balanceDue.toStringAsFixed(2)}',
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Customer_Due_List_${DateTime.now().toIso8601String().split('T')[0]}.pdf',
    );
  }

  static pw.Document _generateCustomerStatementPdf({
    required CustomerModel customer,
    required List<BillModel> bills,
    required ShopSettings shop,
    required BillingSettings billing,
    DateTimeRange? dateRange,
  }) {
    final pdf = pw.Document();
    final curr = billing.currencySymbol.isNotEmpty ? billing.currencySymbol : 'Rs.';

    final filteredBills = bills.where((b) {
      if (dateRange == null) return true;
      if (b.createdAt.isEmpty) return false;
      final dt = DateTime.tryParse(b.createdAt);
      if (dt == null) return false;
      return (dt.isAfter(dateRange.start) || dt.isAtSameMomentAs(dateRange.start)) &&
          (dt.isBefore(dateRange.end) || dt.isAtSameMomentAs(dateRange.end));
    }).toList();

    filteredBills.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final totalPeriodInvoiced = filteredBills.fold(0.0, (s, b) => s + b.grandTotal);
    final totalPeriodPaid = filteredBills.fold(0.0, (s, b) => s + b.paidTotal);
    final totalPeriodUnits = filteredBills.fold(0.0, (s, b) => s + b.items.fold(0.0, (isum, it) => isum + it.quantity));

    String dateRangeStr = 'All Invoices (Complete History)';
    if (dateRange != null) {
      final startFmt = Formatters.parseAndFormatDate(dateRange.start.toIso8601String());
      final endFmt = Formatters.parseAndFormatDate(dateRange.end.toIso8601String());
      dateRangeStr = '$startFmt to $endFmt';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) => [
          // Business Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    shop.shopName.isNotEmpty ? shop.shopName.toUpperCase() : 'SIMPLE BILLING',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.blue800),
                  ),
                  if (shop.address.isNotEmpty)
                    pw.Text(shop.address, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  if (shop.phone.isNotEmpty)
                    pw.Text('Phone: ${shop.phone}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  if (shop.email.isNotEmpty)
                    pw.Text('Email: ${shop.email}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  if (shop.gstNumber.isNotEmpty)
                    pw.Text('GSTIN: ${shop.gstNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.blueGrey800)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blueGrey800,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      'CONSOLIDATED STATEMENT',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.white),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Period: $dateRangeStr', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                  pw.Text('Generated: ${Formatters.parseAndFormatDate(DateTime.now().toIso8601String())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
          pw.Divider(thickness: 1, height: 16),

          // Customer Profile Info Card
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('CUSTOMER ACCOUNT', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                    pw.SizedBox(height: 2),
                    pw.Text(customer.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.blueGrey900)),
                    if (customer.customerCode != null && customer.customerCode!.isNotEmpty)
                      pw.Text('Code: ${customer.customerCode}', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('CONTACT DETAILS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                    pw.SizedBox(height: 2),
                    pw.Text('Mobile: ${customer.mobile ?? '-'}', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Email: ${customer.email ?? '-'}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('OVERALL LEDGER DUE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: customer.balanceDue > 0 ? PdfColors.red700 : PdfColors.green700)),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '$curr ${customer.balanceDue.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                        color: customer.balanceDue > 0 ? PdfColors.red700 : PdfColors.green700,
                      ),
                    ),
                    if (customer.advanceBalance > 0)
                      pw.Text('Advance: $curr ${customer.advanceBalance.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.blue700)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Period Financial Metrics Strip
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColors.blue200),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(children: [
                  pw.Text('TOTAL INVOICED', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey700)),
                  pw.Text('$curr ${totalPeriodInvoiced.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                ]),
                pw.Column(children: [
                  pw.Text('PAYMENTS RECEIVED', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey700)),
                  pw.Text('$curr ${totalPeriodPaid.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                ]),
                pw.Column(children: [
                  pw.Text('INVOICES COUNT', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey700)),
                  pw.Text('${filteredBills.length} Bills', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                ]),
                pw.Column(children: [
                  pw.Text('TOTAL UNITS BOUGHT', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey700)),
                  pw.Text('${totalPeriodUnits.toStringAsFixed(totalPeriodUnits % 1 == 0 ? 0 : 2)} Qty', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // Itemized Purchase History Header
          pw.Text('ITEMIZED PURCHASE HISTORY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blueGrey900)),
          pw.SizedBox(height: 6),

          if (filteredBills.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              alignment: pw.Alignment.center,
              child: pw.Text('No purchase transactions recorded in this period.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            )
          else
            ...filteredBills.map((b) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Bill Banner
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                        borderRadius: pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(5),
                          topRight: pw.Radius.circular(5),
                        ),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Row(
                            children: [
                              pw.Text('Date: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                              pw.Text(Formatters.parseAndFormatDate(b.createdAt), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.blue800)),
                              pw.Text('  |  Bill #: ', style: const pw.TextStyle(fontSize: 8.5)),
                              pw.Text(b.billNumber, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                            ],
                          ),
                          pw.Text(
                            'Mode: ${b.paymentMethod} ${b.balanceDue > 0 ? "• (Pending Due)" : "• (Paid)"}',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: b.balanceDue > 0 ? PdfColors.red800 : PdfColors.green800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bill Items Table
                    pw.Table(
                      border: const pw.TableBorder(
                        horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                      ),
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.grey50),
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: pw.Text('#', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: pw.Text('Product / Service Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: pw.Text('Qty', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: pw.Text('Unit Price ($curr)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: pw.Text('Line Total ($curr)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                          ],
                        ),
                        ...b.items.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final it = entry.value;
                          return pw.TableRow(
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: pw.Text(idx.toString(), style: const pw.TextStyle(fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: pw.Text(it.productName, style: const pw.TextStyle(fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: pw.Text(it.quantity.toStringAsFixed(it.quantity % 1 == 0 ? 0 : 2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: pw.Text(it.price.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: pw.Text(it.total.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                            ],
                          );
                        }),
                      ],
                    ),
                    // Bill Summary Footer
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.only(
                          bottomLeft: pw.Radius.circular(5),
                          bottomRight: pw.Radius.circular(5),
                        ),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          if (b.discount > 0)
                            pw.Text('Discount: - $curr ${b.discount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.red700))
                          else
                            pw.SizedBox(),
                          pw.Row(
                            children: [
                              pw.Text('Bill Total: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                              pw.Text('$curr ${b.grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.blue800)),
                              pw.Text('  |  Paid: $curr ${b.paidTotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8.5)),
                              if (b.balanceDue > 0) ...[
                                pw.Text('  |  Balance: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.red700)),
                                pw.Text('$curr ${b.balanceDue.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.red700)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

          // Final Consolidated Statement Summary Footer
          pw.Divider(thickness: 1, height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('STATEMENT RECONCILIATION SUMMARY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.blueGrey800)),
                    pw.SizedBox(height: 2),
                    pw.Text('Total Period Purchases: $curr ${totalPeriodInvoiced.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.Text('Total Period Payments: $curr ${totalPeriodPaid.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8.5)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('CURRENT OUTSTANDING BALANCE DUE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: customer.balanceDue > 0 ? PdfColors.red700 : PdfColors.green700)),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '$curr ${customer.balanceDue.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: customer.balanceDue > 0 ? PdfColors.red700 : PdfColors.green700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (shop.footerMessage.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(shop.footerMessage, style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 8, color: PdfColors.grey700)),
            ),
          ],
        ],
      ),
    );

    return pdf;
  }
}
