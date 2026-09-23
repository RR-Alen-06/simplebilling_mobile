import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/core/utils/whatsapp_sender.dart';

class WhatsAppShareService {
  WhatsAppShareService._();

  /// Send formatted tax invoice / receipt to customer via WhatsApp
  static Future<bool> sendInvoice({
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

  /// Send pending due payment reminder with UPI deep-link intent
  static Future<bool> sendDuePaymentReminder({
    required CustomerModel customer,
    required ShopSettings shop,
    required BillingSettings billing,
  }) async {
    return await WhatsAppSender.sendDuePaymentReminder(
      customer: customer,
      shop: shop,
      billing: billing,
    );
  }
}
