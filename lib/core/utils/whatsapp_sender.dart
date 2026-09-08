import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';

class WhatsAppSender {
  WhatsAppSender._();

  /// Clean and format mobile number with default country code (+91 for India if 10 digits)
  static String formatPhoneNumber(String? rawPhone, {String defaultCountryCode = '91'}) {
    if (rawPhone == null || rawPhone.trim().isEmpty) return '';
    String digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length == 10) {
      return defaultCountryCode + digits;
    }
    return digits;
  }

  /// Generate a clean, readable text receipt for WhatsApp
  static String generateInvoiceText({
    required BillModel bill,
    required ShopSettings shop,
    required BillingSettings billing,
  }) {
    final curr = billing.currencySymbol.isNotEmpty ? billing.currencySymbol : 'Rs.';
    final buffer = StringBuffer();

    buffer.writeln('*🧾 ${shop.shopName.toUpperCase()}*');
    if (shop.address.isNotEmpty) buffer.writeln('📍 ${shop.address}');
    if (shop.phone.isNotEmpty) buffer.writeln('📞 ${shop.phone}');
    if (shop.gstNumber.isNotEmpty) buffer.writeln('🏛️ GSTIN: ${shop.gstNumber}');
    buffer.writeln('--------------------------------');
    buffer.writeln('*TAX INVOICE / RECEIPT*');
    buffer.writeln('📄 *Invoice #:* ${bill.billNumber}');
    buffer.writeln('📅 *Date:* ${Formatters.parseAndFormatDate(bill.createdAt)}');
    if (bill.customerName != null && bill.customerName!.isNotEmpty) {
      buffer.writeln('👤 *Customer:* ${bill.customerName}');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('*ITEMS:*');

    for (int i = 0; i < bill.items.length; i++) {
      final item = bill.items[i];
      buffer.writeln('${i + 1}. ${item.productName}');
      buffer.writeln('    ${item.quantity.toStringAsFixed(0)} x $curr ${item.price.toStringAsFixed(2)} = *$curr ${item.total.toStringAsFixed(2)}*');
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('Subtotal: $curr ${bill.total.toStringAsFixed(2)}');
    if (bill.discount > 0) {
      buffer.writeln('Discount: - $curr ${bill.discount.toStringAsFixed(2)}');
    }
    if (bill.gstAmount > 0) {
      buffer.writeln('GST Tax: + $curr ${bill.gstAmount.toStringAsFixed(2)}');
    }
    if (bill.roundingAdjustment != 0) {
      buffer.writeln('Rounding: ${bill.roundingAdjustment > 0 ? '+' : ''}$curr ${bill.roundingAdjustment.toStringAsFixed(2)}');
    }
    buffer.writeln('*GRAND TOTAL: $curr ${bill.grandTotal.toStringAsFixed(2)}*');
    buffer.writeln('--------------------------------');
    buffer.writeln('💳 *Paid:* $curr ${bill.paidTotal.toStringAsFixed(2)} via ${bill.paymentMethod}');
    if (bill.advanceUsed > 0) {
      buffer.writeln('Advance Used: $curr ${bill.advanceUsed.toStringAsFixed(2)}');
    }
    if (bill.advanceEarned > 0) {
      buffer.writeln('Advance Credited: $curr ${bill.advanceEarned.toStringAsFixed(2)}');
    }
    if (bill.loyaltyPointsEarned > 0) {
      buffer.writeln('🎁 *Loyalty Points Earned:* +${bill.loyaltyPointsEarned.toStringAsFixed(0)} pts');
    }
    buffer.writeln('--------------------------------');
    if (shop.footerMessage.isNotEmpty) {
      buffer.writeln('_${shop.footerMessage}_');
    } else {
      buffer.writeln('_Thank you for your business!_');
    }

    return buffer.toString();
  }

  /// Launch WhatsApp with pre-filled message
  static Future<bool> sendInvoice({
    required BillModel bill,
    required ShopSettings shop,
    required BillingSettings billing,
    String? recipientPhone,
  }) async {
    try {
      final phone = formatPhoneNumber(recipientPhone ?? bill.customerMobile);
      final text = generateInvoiceText(bill: bill, shop: shop, billing: billing);
      final encodedText = Uri.encodeComponent(text);

      final Uri uri;
      if (phone.isNotEmpty) {
        uri = Uri.parse('https://wa.me/$phone?text=$encodedText');
      } else {
        uri = Uri.parse('https://api.whatsapp.com/send?text=$encodedText');
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        // Fallback to web browser
        final webUri = Uri.parse('https://web.whatsapp.com/send?text=$encodedText');
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
      return false;
    }
  }
}
