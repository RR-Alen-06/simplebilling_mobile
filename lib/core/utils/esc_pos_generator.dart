import 'dart:convert';
import 'dart:typed_data';

import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';

class EscPosGenerator {
  EscPosGenerator._();

  // ESC/POS Commands
  static const List<int> initPrinter = [0x1B, 0x40];
  static const List<int> alignLeft = [0x1B, 0x61, 0x00];
  static const List<int> alignCenter = [0x1B, 0x61, 0x01];
  static const List<int> alignRight = [0x1B, 0x61, 0x02];
  static const List<int> boldOn = [0x1B, 0x45, 0x01];
  static const List<int> boldOff = [0x1B, 0x45, 0x00];
  static const List<int> doubleSize = [0x1D, 0x21, 0x11];
  static const List<int> normalSize = [0x1D, 0x21, 0x00];
  static const List<int> cutPaper = [0x1D, 0x56, 0x42, 0x00];
  static const List<int> lineFeed = [0x0A];

  /// Generate raw ESC/POS byte sequence for 58mm / 80mm thermal receipt
  static Uint8List generateReceiptBytes({
    required BillModel bill,
    required ShopSettings shop,
    required BillingSettings billing,
    int paperWidthCols = 42, // 42 cols for 80mm, 32 cols for 58mm
  }) {
    final List<int> bytes = [];
    final curr = billing.currencySymbol.isNotEmpty
        ? billing.currencySymbol
        : 'Rs.';

    void appendLine(String text) {
      bytes.addAll(utf8.encode(text));
      bytes.addAll(lineFeed);
    }

    void appendDivider([String char = '-']) {
      appendLine(char * paperWidthCols);
    }

    void appendRow(String left, String right) {
      final spaceCount = paperWidthCols - left.length - right.length;
      if (spaceCount > 0) {
        appendLine(left + (' ' * spaceCount) + right);
      } else {
        appendLine(left);
        appendLine((' ' * (paperWidthCols - right.length)) + right);
      }
    }

    // Initialize
    bytes.addAll(initPrinter);

    // Header: Shop Name Center Bold Large
    bytes.addAll(alignCenter);
    bytes.addAll(boldOn);
    bytes.addAll(doubleSize);
    appendLine(shop.shopName);
    bytes.addAll(normalSize);
    bytes.addAll(boldOff);

    if (shop.address.isNotEmpty) {
      appendLine(shop.address);
    }
    if (shop.phone.isNotEmpty) {
      appendLine('Ph: ${shop.phone}');
    }
    if (shop.gstNumber.isNotEmpty) {
      appendLine('GSTIN: ${shop.gstNumber}');
    }

    bytes.addAll(alignLeft);
    appendDivider('=');
    appendRow(
      'Inv: ${bill.billNumber}',
      Formatters.parseAndFormatDate(bill.createdAt),
    );
    if (bill.customerName != null && bill.customerName!.isNotEmpty) {
      appendLine(
        'Cust: ${bill.customerName!}${bill.customerMobile != null ? ' (${bill.customerMobile!})' : ''}',
      );
    }
    appendDivider('-');

    // Item Table Header
    // e.g. "Item                     Qty  Rate  Total"
    appendRow('ITEM', 'QTY  RATE  TOTAL');
    appendDivider('-');

    for (final it in bill.items) {
      appendLine(it.productName);
      final qtyStr = it.quantity.toStringAsFixed(0);
      final rateStr = it.price.toStringAsFixed(2);
      final totalStr = it.total.toStringAsFixed(2);
      appendRow('  $qtyStr x $rateStr', '$curr $totalStr');
    }

    appendDivider('-');
    appendRow('Subtotal:', '$curr ${bill.total.toStringAsFixed(2)}');
    if (bill.discount > 0) {
      appendRow('Discount:', '- $curr ${bill.discount.toStringAsFixed(2)}');
    }
    if (bill.gstAmount > 0) {
      appendRow('GST Tax:', '+ $curr ${bill.gstAmount.toStringAsFixed(2)}');
    }
    if (bill.roundingAdjustment != 0) {
      appendRow(
        'Rounding:',
        '${bill.roundingAdjustment > 0 ? '+' : ''}$curr ${bill.roundingAdjustment.toStringAsFixed(2)}',
      );
    }

    appendDivider('=');
    bytes.addAll(boldOn);
    appendRow('GRAND TOTAL:', '$curr ${bill.grandTotal.toStringAsFixed(2)}');
    bytes.addAll(boldOff);
    appendDivider('=');

    appendLine(
      'Paid via: ${bill.paymentMethod} ($curr ${bill.paidTotal.toStringAsFixed(2)})',
    );
    if (bill.advanceUsed > 0) {
      appendLine('Advance Used: $curr ${bill.advanceUsed.toStringAsFixed(2)}');
    }
    if (bill.advanceEarned > 0) {
      appendLine(
        'Advance Credited: $curr ${bill.advanceEarned.toStringAsFixed(2)}',
      );
    }
    if (bill.loyaltyPointsEarned > 0) {
      appendLine(
        'Loyalty Points Earned: +${bill.loyaltyPointsEarned.toStringAsFixed(0)} pts',
      );
    }

    bytes.addAll(alignCenter);
    bytes.addAll(lineFeed);
    if (shop.footerMessage.isNotEmpty) {
      appendLine(shop.footerMessage);
    } else {
      appendLine('Thank you for your visit!');
    }
    appendLine('Powered by SimpleBilling & PrintPro');

    // Feeds & Paper Cut
    bytes.addAll(lineFeed);
    bytes.addAll(lineFeed);
    bytes.addAll(lineFeed);
    bytes.addAll(cutPaper);

    return Uint8List.fromList(bytes);
  }
}
