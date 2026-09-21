import 'package:flutter_test/flutter_test.dart';
import 'package:simplebilling_mobile/core/utils/customer_calculator.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';

void main() {
  group('CustomerCalculator Unit Tests', () {
    test('calculateBalances correctly calculates billed, paid, and balance due', () {
      final bills = [
        {'grand_total': 1000.0, 'paid_total': 400.0},
        {'grand_total': 500.0, 'paid_total': 500.0},
      ];

      final directPayments = [
        {'amount': 100.0},
      ];

      final result = CustomerCalculator.calculateBalances(
        advanceBalance: 50.0,
        bills: bills,
        directPayments: directPayments,
      );

      // Total Billed: 1000 + 500 = 1500
      // Total Paid: 400 + 500 + 100 = 1000
      // Advance: 50
      // Balance Due: 1500 - 1000 - 50 = 450
      expect(result.totalBilled, 1500.0);
      expect(result.totalPaid, 1000.0);
      expect(result.balanceDue, 450.0);
    });

    test('calculateBalances clamps balanceDue to 0 when overpaid or advance exceeds due', () {
      final bills = [
        {'grand_total': 200.0, 'paid_total': 200.0},
      ];

      final directPayments = [
        {'amount': 100.0},
      ];

      final result = CustomerCalculator.calculateBalances(
        advanceBalance: 50.0,
        bills: bills,
        directPayments: directPayments,
      );

      expect(result.totalBilled, 200.0);
      expect(result.totalPaid, 300.0);
      expect(result.balanceDue, 0.0);
    });

    test('applyBalances returns updated CustomerModel with calculated totals', () {
      final customer = CustomerModel(
        id: 'c1',
        name: 'Test Customer',
        advanceBalance: 100.0,
      );

      final bills = [
        {'grand_total': 800.0, 'paid_total': 200.0},
      ];

      final directPayments = <Map<String, dynamic>>[];

      final updated = CustomerCalculator.applyBalances(
        customer: customer,
        bills: bills,
        directPayments: directPayments,
      );

      expect(updated.totalBilled, 800.0);
      expect(updated.totalPaid, 200.0);
      expect(updated.balanceDue, 500.0); // 800 - 200 - 100 = 500
    });
  });
}
