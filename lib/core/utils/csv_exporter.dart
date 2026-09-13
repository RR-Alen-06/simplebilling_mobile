import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
import 'package:simplebilling_mobile/data/models/expense_model.dart';

class CsvExporter {
  CsvExporter._();

  /// Trigger download or sharing of CSV file across Web and Mobile
  static Future<bool> downloadCsv({
    required String filename,
    required String csvContent,
  }) async {
    try {
      if (kIsWeb) {
        // On Web, launching a data URL triggers an immediate browser file download
        final uri = Uri.parse(
          'data:text/csv;charset=utf-8,' + Uri.encodeComponent(csvContent),
        );
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri);
        }
      }

      // Universal fallback (uses Printing share sheet or native file saver)
      final bytes = Uint8List.fromList(utf8.encode(csvContent));
      return await Printing.sharePdf(
        bytes: bytes,
        filename: filename.endsWith('.csv') ? filename : '$filename.csv',
      );
    } catch (e) {
      debugPrint('Error exporting CSV: $e');
      return false;
    }
  }

  /// Generate and download CSV for Bills list
  static Future<bool> exportBills(List<BillModel> bills, {String filename = 'sales_bills_report.csv'}) async {
    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln('Invoice Number,Date,Customer Name,Customer Phone,Payment Method,Subtotal,Discount,GST Amount,Grand Total,Cash Paid,UPI Paid');

    for (final b in bills) {
      final inv = _escape(b.billNumber);
      final date = _escape(b.createdAt);
      final name = _escape(b.customerName ?? 'Walk-in');
      final phone = _escape(b.customerMobile ?? '-');
      final method = _escape(b.paymentMethod);
      final subtotal = b.total.toStringAsFixed(2);
      final discount = b.discount.toStringAsFixed(2);
      final gst = b.gstAmount.toStringAsFixed(2);
      final grand = b.grandTotal.toStringAsFixed(2);
      final cash = b.cashPaid.toStringAsFixed(2);
      final upi = b.upiPaid.toStringAsFixed(2);

      buffer.writeln('$inv,$date,$name,$phone,$method,$subtotal,$discount,$gst,$grand,$cash,$upi');
    }

    return await downloadCsv(filename: filename, csvContent: buffer.toString());
  }

  /// Generate and download CSV for Customer Ledger / Dues report
  static Future<bool> exportCustomerDues(List<CustomerModel> customers, {String filename = 'customer_dues_ledger.csv'}) async {
    final buffer = StringBuffer();
    buffer.writeln('Customer Code,Customer Name,Mobile Phone,Email,Total Invoiced,Total Paid,Advance Balance,Balance Due,Loyalty Points');

    for (final c in customers) {
      final code = _escape(c.customerCode ?? '-');
      final name = _escape(c.name);
      final mobile = _escape(c.mobile ?? '-');
      final email = _escape(c.email ?? '-');
      final billed = c.totalBilled.toStringAsFixed(2);
      final paid = c.totalPaid.toStringAsFixed(2);
      final advance = c.advanceBalance.toStringAsFixed(2);
      final due = c.balanceDue.toStringAsFixed(2);
      final pts = c.loyaltyPoints.toStringAsFixed(0);

      buffer.writeln('$code,$name,$mobile,$email,$billed,$paid,$advance,$due,$pts');
    }

    return await downloadCsv(filename: filename, csvContent: buffer.toString());
  }

  /// Generate and download CSV for Expenses report
  static Future<bool> exportExpenses(List<ExpenseModel> expenses, {String filename = 'expenses_report.csv'}) async {
    final buffer = StringBuffer();
    buffer.writeln('Expense Number,Date Time,Description,Category,Payment Mode,Notes,Amount (INR)');

    for (final e in expenses) {
      final num = _escape(e.expenseNumber ?? '-');
      final date = _escape(e.date);
      final desc = _escape(e.title);
      final cat = _escape(e.category);
      final mode = _escape(e.paymentMode);
      final notes = _escape(e.notes ?? '-');
      final amt = e.amount.toStringAsFixed(2);

      buffer.writeln('$num,$date,$desc,$cat,$mode,$notes,$amt');
    }

    return await downloadCsv(filename: filename, csvContent: buffer.toString());
  }

  /// Generate and download CSV for Product / Item sales breakdown
  static Future<bool> exportItemSales(List<Map<String, dynamic>> items, {String filename = 'item_sales_report.csv'}) async {
    final buffer = StringBuffer();
    buffer.writeln('Product / Item Name,Total Quantity Sold,Revenue Generated (INR),Revenue Share (%)');

    for (final it in items) {
      final name = _escape(it['name'] as String? ?? 'Item');
      final qty = (it['qty'] as num?)?.toStringAsFixed(2) ?? '0.00';
      final rev = (it['revenue'] as num?)?.toStringAsFixed(2) ?? '0.00';
      final share = (it['share'] as num?)?.toStringAsFixed(1) ?? '0.0';

      buffer.writeln('$name,$qty,$rev,$share');
    }

    return await downloadCsv(filename: filename, csvContent: buffer.toString());
  }

  static String _escape(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}

