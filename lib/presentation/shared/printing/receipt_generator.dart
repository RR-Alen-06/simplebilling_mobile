import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';

class ReceiptGenerator {
  ReceiptGenerator._();

  static Future<void> printReceipt({
    required BillModel bill,
    required ShopSettings shop,
    required BillingSettings billing,
  }) async {
    final pdf = pw.Document();

    final isThermal = billing.defaultPrinterSize.toLowerCase().contains('80');
    final pageFormat = isThermal
        ? const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm)
        : PdfPageFormat.a4;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  shop.shopName,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              if (shop.address.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    shop.address,
                    style: const pw.TextStyle(fontSize: 9),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              if (shop.phone.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    'Phone: ${shop.phone}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              if (shop.gstNumber.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    'GSTIN: ${shop.gstNumber}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Invoice: ${bill.billNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text(Formatters.parseAndFormatDate(bill.createdAt), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              if (bill.customerName != null)
                pw.Text('Customer: ${bill.customerName} (${bill.customerMobile ?? '-'})', style: const pw.TextStyle(fontSize: 9)),
              pw.Divider(thickness: 0.5),
              pw.Row(
                children: [
                  pw.Expanded(flex: 5, child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  pw.Expanded(flex: 2, child: pw.Text('Qty', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  pw.Expanded(flex: 2, child: pw.Text('Rate', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  pw.Expanded(flex: 3, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                ],
              ),
              pw.Divider(thickness: 0.2),
              ...bill.items.map((it) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                    child: pw.Row(
                      children: [
                        pw.Expanded(flex: 5, child: pw.Text(it.productName, style: const pw.TextStyle(fontSize: 8.5))),
                        pw.Expanded(flex: 2, child: pw.Text(it.quantity.toStringAsFixed(0), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5))),
                        pw.Expanded(flex: 2, child: pw.Text(it.price.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5))),
                        pw.Expanded(flex: 3, child: pw.Text(it.total.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5))),
                      ],
                    ),
                  )),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('₹ ${bill.total.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              if (bill.discount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Discount:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('- ₹ ${bill.discount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              if (bill.roundingAdjustment != 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Rounding:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('₹ ${bill.roundingAdjustment.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('GRAND TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text('₹ ${bill.grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                ],
              ),
              pw.Divider(thickness: 0.5),
              pw.Text('Paid via: ${bill.paymentMethod} (₹ ${bill.paidTotal.toStringAsFixed(2)})', style: const pw.TextStyle(fontSize: 8.5)),
              pw.SizedBox(height: 8),
              if (shop.footerMessage.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    shop.footerMessage,
                    style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice_${bill.billNumber}.pdf',
    );
  }
}
