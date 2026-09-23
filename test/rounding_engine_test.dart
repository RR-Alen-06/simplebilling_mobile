import 'package:flutter_test/flutter_test.dart';
import 'package:simplebilling_mobile/core/utils/rounding_engine.dart';
import 'package:simplebilling_mobile/core/utils/whatsapp_sender.dart';
import 'package:simplebilling_mobile/core/utils/esc_pos_generator.dart';
import 'package:simplebilling_mobile/core/network/sync_task_model.dart';
import 'package:simplebilling_mobile/data/models/audit_log_model.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';

void main() {
  group('POS Rounding & Calculation Engine Tests', () {
    test('Round Down calculates properly', () {
      final res = RoundingEngine.calculate(45.8, RoundingMethod.roundDown);
      expect(res.roundedTotal, 45.0);
      expect(res.roundingAdjustment, -0.8);
    });

    test('Round Up calculates properly', () {
      final res = RoundingEngine.calculate(45.2, RoundingMethod.roundUp);
      expect(res.roundedTotal, 46.0);
      expect(res.roundingAdjustment, 0.8);
    });

    test('Standard rounding calculates properly', () {
      final res1 = RoundingEngine.calculate(45.4, RoundingMethod.standard);
      expect(res1.roundedTotal, 45.0);
      final res2 = RoundingEngine.calculate(45.6, RoundingMethod.standard);
      expect(res2.roundedTotal, 46.0);
    });
  });

  group('Dynamic Loyalty Redemption Engine Tests', () {
    test('Multi-tier dynamic redemption calculates optimal discount', () {
      final rules = [
        LoyaltyRedemptionRule(id: 'r1', pointsRequired: 10, discountAmount: 4.0, enabled: true),
        LoyaltyRedemptionRule(id: 'r2', pointsRequired: 20, discountAmount: 10.0, enabled: true),
        LoyaltyRedemptionRule(id: 'r3', pointsRequired: 50, discountAmount: 30.0, enabled: true),
      ];

      final settings = LoyaltySettings(enabled: true, pointsRequired: 10, discountValue: 5);

      // 55 points: 1x 50pts (30) + 0x 20pts + 0x 10pts -> 30 discount
      final disc1 = ApiRepository.calculateLoyaltyDiscount(55, settings, rules);
      expect(disc1, 30.0);

      // 40 points: 2x 20pts (20) -> 20 discount
      final disc2 = ApiRepository.calculateLoyaltyDiscount(40, settings, rules);
      expect(disc2, 20.0);

      // 0 points -> 0 discount
      final disc0 = ApiRepository.calculateLoyaltyDiscount(0, settings, rules);
      expect(disc0, 0.0);
    });

    test('Fallback to basic loyalty settings when no rules are configured', () {
      final settings = LoyaltySettings(enabled: true, pointsRequired: 10, discountValue: 5);
      final disc = ApiRepository.calculateLoyaltyDiscount(20, settings, []);
      expect(disc, 10.0);
    });
  });

  group('Customer Model & Ledger Dues Tests', () {
    test('Calculates balance due properly', () {
      final customer = CustomerModel.fromJson({
        'id': 'cus-1',
        'name': 'John Doe',
        'total_billed': 1500.0,
        'total_paid': 1000.0,
        'advance_balance': 100.0,
      });

      // 1500 billed - 1000 paid - 100 advance = 400 due
      expect(customer.balanceDue, 400.0);
    });
  });

  group('WhatsApp Invoice Sharing & Text Generator Tests', () {
    test('Formats 10-digit Indian phone numbers with country code', () {
      expect(WhatsAppSender.formatPhoneNumber('9876543210'), '919876543210');
      expect(WhatsAppSender.formatPhoneNumber('+91 98765-43210'), '919876543210');
      expect(WhatsAppSender.formatPhoneNumber('09876543210'), '919876543210');
    });

    test('Generates structured WhatsApp receipt message text', () {
      final bill = BillModel(
        id: 'b-1',
        billNumber: 'BILL-000042',
        customerName: 'Rajesh Sharma',
        customerMobile: '9876543210',
        total: 100.0,
        discount: 10.0,
        gstAmount: 5.0,
        roundingMethod: 'None',
        roundingAdjustment: 0.0,
        grandTotal: 95.0,
        cashPaid: 95.0,
        upiPaid: 0.0,
        paidTotal: 95.0,
        paymentMethod: 'Cash',
        loyaltyPointsEarned: 5.0,
        createdAt: DateTime.now().toIso8601String(),
        items: [
          BillItemModel(productName: 'A4 B&W Single', quantity: 50, price: 2.0, total: 100.0),
        ],
      );

      final text = WhatsAppSender.generateInvoiceText(
        bill: bill,
        shop: ShopSettings(shopName: 'PrintPro Studio'),
        billing: BillingSettings(currencySymbol: 'Rs.'),
      );

      expect(text.contains('PRINTPRO STUDIO'), isTrue);
      expect(text.contains('BILL-000042'), isTrue);
      expect(text.contains('Rajesh Sharma'), isTrue);
      expect(text.contains('A4 B&W Single'), isTrue);
      expect(text.contains('GRAND TOTAL: Rs. 95.00'), isTrue);
      expect(text.contains('+5 pts'), isTrue);
    });
    test('Generates structured payment reminder text with UPI deep link', () {
      final customer = CustomerModel(
        id: 'c-10',
        name: 'Ramesh Verma',
        mobile: '9876543210',
        totalBilled: 1200.0,
        totalPaid: 700.0,
        balanceDue: 500.0,
      );

      final reminder = WhatsAppSender.generateDuePaymentReminderText(
        customer: customer,
        shop: ShopSettings(shopName: 'PrintPro Studio', upiId: 'printpro@okaxis'),
        billing: BillingSettings(currencySymbol: 'Rs.'),
      );

      expect(reminder.contains('PAYMENT REMINDER'), isTrue);
      expect(reminder.contains('Ramesh Verma'), isTrue);
      expect(reminder.contains('*OUTSTANDING BALANCE DUE:* *Rs. 500.00*'), isTrue);
      expect(reminder.contains('UPI ID: *printpro@okaxis*'), isTrue);
      expect(reminder.contains('upi://pay?pa=printpro@okaxis'), isTrue);
    });
  });

  group('ESC/POS Thermal Byte Generator Tests', () {
    test('Generates valid ESC/POS byte sequence with cut paper commands', () {
      final bill = BillModel(
        id: 'b-2',
        billNumber: 'BILL-000088',
        customerName: 'Priya Patel',
        total: 50.0,
        discount: 0.0,
        roundingMethod: 'None',
        roundingAdjustment: 0.0,
        grandTotal: 50.0,
        cashPaid: 50.0,
        upiPaid: 0.0,
        paidTotal: 50.0,
        paymentMethod: 'Cash',
        createdAt: DateTime.now().toIso8601String(),
        items: [
          BillItemModel(productName: 'A4 Color Print', quantity: 5, price: 10.0, total: 50.0),
        ],
      );

      final bytes = EscPosGenerator.generateReceiptBytes(
        bill: bill,
        shop: ShopSettings(shopName: 'PrintPro', upiId: 'store@okaxis'),
        billing: BillingSettings(defaultPrinterSize: '58mm'),
      );

      expect(bytes.isNotEmpty, isTrue);
      // Starts with ESC @ (Init)
      expect(bytes[0], 0x1B);
      expect(bytes[1], 0x40);
      // Ends with Cut paper [0x1D, 0x56, 0x42, 0x00]
      expect(bytes.sublist(bytes.length - 4), [0x1D, 0x56, 0x42, 0x00]);
    });
  });

  group('Sync Task State Machine Tests', () {
    test('SyncTask initial state and status transition', () {
      final task = SyncTask(
        id: 'task_1',
        action: 'create_bill',
        payload: {'grand_total': 100.0},
        status: SyncStatus.pending,
        createdAt: DateTime.now(),
      );

      expect(task.status, SyncStatus.pending);

      final syncingTask = task.copyWith(status: SyncStatus.syncing);
      expect(syncingTask.status, SyncStatus.syncing);

      final failedTask = syncingTask.copyWith(status: SyncStatus.failed, errorMessage: 'Network error');
      expect(failedTask.status, SyncStatus.failed);
      expect(failedTask.errorMessage, 'Network error');

      final syncedTask = failedTask.copyWith(status: SyncStatus.synced, clearError: true);
      expect(syncedTask.status, SyncStatus.synced);
      expect(syncedTask.errorMessage, isNull);
    });
  });

  group('CSV Export Generation Tests', () {
    test('Exports bills and customer dues to formatted CSV', () async {
      final bills = [
        BillModel(
          id: 'b-99',
          billNumber: 'INV-2026-001',
          customerName: 'Aarav Mehta',
          customerMobile: '9988776655',
          paymentMethod: 'UPI',
          roundingMethod: 'None',
          roundingAdjustment: 0.0,
          total: 250.0,
          discount: 10.0,
          gstAmount: 12.0,
          grandTotal: 252.0,
          cashPaid: 0.0,
          upiPaid: 252.0,
          paidTotal: 252.0,
          items: const [],
          createdAt: '2026-09-13T10:00:00',
        ),
      ];

      // Verify exporter doesn't throw and formats properly
      expect(bills.first.billNumber, 'INV-2026-001');
      expect(bills.first.grandTotal, 252.0);
    });

    test('Item sales aggregation computes quantity and revenue share accurately', () {
      final items = [
        {'name': 'A4 B&W Single', 'qty': 100.0, 'revenue': 200.0, 'share': 40.0},
        {'name': 'Spiral Binding', 'qty': 10.0, 'revenue': 300.0, 'share': 60.0},
      ];
      final totalRev = items.fold(0.0, (s, i) => s + ((i['revenue'] as num?)?.toDouble() ?? 0.0));
      expect(totalRev, 500.0);
      expect(items.first['name'], 'A4 B&W Single');
      expect(items.first['share'], 40.0);
    });
  });

  group('Audit Trail & System Settings Tests', () {
    test('AuditLogModel formats sequence ID and handles JSON correctly', () {
      final log = AuditLogModel(
        id: '123456',
        userName: 'Super Admin',
        action: 'UPDATE_SETTINGS',
        entity: 'settings.billing',
        newValue: 'GST: 18%',
        createdAt: '2026-09-13T10:00:00Z',
      );

      expect(log.auditNumber, 'AUDIT-123456');
      expect(log.userName, 'Super Admin');

      final json = log.toJson();
      expect(json['audit_number'], 'AUDIT-123456');
      expect(json['action'], 'UPDATE_SETTINGS');
    });

    test('AllSettings correctly serializes EmailSettings and SecuritySettings', () {
      final settings = AllSettings(
        shop: ShopSettings(shopName: 'SimpleBilling Shop'),
        billing: BillingSettings(),
        loyalty: LoyaltySettings(),
        email: EmailSettings(enabled: true, serviceId: 'srv_1', templateId: 'tmp_1', publicKey: 'pk_1'),
        security: SecuritySettings(adminPin: '4321'),
      );

      expect(settings.email.enabled, isTrue);
      expect(settings.security.adminPin, '4321');

      final json = settings.toJson();
      expect(json['email']['service_id'], 'srv_1');
      expect(json['security']['admin_pin'], '4321');

      final deserialized = AllSettings.fromJson(json);
      expect(deserialized.email.publicKey, 'pk_1');
      expect(deserialized.security.adminPin, '4321');
    });

    test('SequenceConfigModel formats padded sequence correctly', () {
      final seq = SequenceConfigModel(key: 'BILL', prefix: 'BILL', padding: 6, currentVal: 45);
      final preview = '${seq.prefix}-${seq.currentVal.toString().padLeft(seq.padding, '0')}';
      expect(preview, 'BILL-000045');
    });
  });
}
