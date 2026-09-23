import 'package:flutter/material.dart' show DateTimeRange;
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/presentation/shared/printing/receipt_generator.dart';

class PdfInvoiceService {
  PdfInvoiceService._();

  /// Print or preview A4 Tax Invoice PDF
  static Future<void> printA4Invoice({
    required BillModel bill,
    required ShopSettings shop,
    required BillingSettings billing,
  }) async {
    await ReceiptGenerator.printA4Invoice(
      bill: bill,
      shop: shop,
      billing: billing,
    );
  }

  /// Print or preview 80mm Thermal Receipt PDF
  static Future<void> print80mmReceipt({
    required BillModel bill,
    required ShopSettings shop,
    required BillingSettings billing,
  }) async {
    await ReceiptGenerator.print80mmReceipt(
      bill: bill,
      shop: shop,
      billing: billing,
    );
  }

  /// Print or preview 58mm Thermal Receipt PDF
  static Future<void> print58mmReceipt({
    required BillModel bill,
    required ShopSettings shop,
    required BillingSettings billing,
  }) async {
    await ReceiptGenerator.print58mmReceipt(
      bill: bill,
      shop: shop,
      billing: billing,
    );
  }

  /// Print Customer Statement PDF across selected date range
  static Future<void> printCustomerStatementPdf({
    required CustomerModel customer,
    required List<BillModel> customerBills,
    required ShopSettings shop,
    required BillingSettings billing,
    DateTimeRange? dateRange,
  }) async {
    await ReceiptGenerator.printCustomerStatementPdf(
      customer: customer,
      customerBills: customerBills,
      shop: shop,
      billing: billing,
      dateRange: dateRange,
    );
  }

  /// Share PDF invoice file via native OS share sheet
  static Future<void> sharePdfInvoiceFile({
    required BillModel bill,
    required ShopSettings shop,
    required BillingSettings billing,
    bool forceA4 = false,
  }) async {
    await ReceiptGenerator.sharePdfInvoiceFile(
      bill: bill,
      shop: shop,
      billing: billing,
      forceA4: forceA4,
    );
  }

  /// Share Customer Statement PDF via native OS share sheet
  static Future<void> shareCustomerStatementPdfFile({
    required CustomerModel customer,
    required List<BillModel> customerBills,
    required ShopSettings shop,
    required BillingSettings billing,
    DateTimeRange? dateRange,
  }) async {
    await ReceiptGenerator.shareCustomerStatementPdfFile(
      customer: customer,
      customerBills: customerBills,
      shop: shop,
      billing: billing,
      dateRange: dateRange,
    );
  }
}
