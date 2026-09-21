import 'package:flutter_test/flutter_test.dart';
import 'package:simplebilling_mobile/core/utils/csv_exporter.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';

void main() {
  group('CSV Injection (CWE-1236) Security Tests', () {
    test('Neutralizes formula injection characters in customer ledger exports', () {
      final maliciousCustomer = CustomerModel(
        id: 'cust_test_1',
        name: '=cmd|\'/C calc\'!A0',
        mobile: '+919999999999',
        email: '@attacker.com',
        customerCode: '-CUST001',
        totalBilled: 100.0,
        totalPaid: 50.0,
        advanceBalance: 0.0,
        balanceDue: 50.0,
        loyaltyPoints: 10.0,
      );

      final csv = CsvExporter.generateCustomerDuesCsv([maliciousCustomer]);

      // Verify header and neutralized contents
      expect(csv, contains('Customer Code,Customer Name'));
      expect(csv, contains("'-CUST001"));
      expect(csv, contains("'=cmd|'/C calc'!A0"));
      expect(csv, contains("'+919999999999"));
      expect(csv, contains("'@attacker.com"));
    });

    test('Neutralizes formula injection in invoice export', () {
      final maliciousBill = BillModel(
        id: 'bill_test_1',
        billNumber: '=HYPERLINK("http://evil.com")',
        customerName: '@MaliciousUser',
        customerMobile: '+919876543210',
        paymentMethod: 'CASH',
        total: 100.0,
        discount: 0.0,
        gstAmount: 0.0,
        roundingMethod: 'none',
        roundingAdjustment: 0.0,
        grandTotal: 100.0,
        cashPaid: 100.0,
        upiPaid: 0.0,
        cardPaid: 0.0,
        paidTotal: 100.0,
        advanceUsed: 0.0,
        advanceEarned: 0.0,
        loyaltyPointsEarned: 0.0,
        loyaltyPointsRedeemed: 0.0,
        createdAt: '2026-09-21',
        items: [],
      );

      final csv = CsvExporter.generateBillsCsv([maliciousBill]);

      expect(csv, contains('Invoice Number,Date,Customer Name'));
      expect(csv, contains("'=HYPERLINK(\"\"http://evil.com\"\")"));
      expect(csv, contains("'@MaliciousUser"));
      expect(csv, contains("'+919876543210"));
    });
  });
}
