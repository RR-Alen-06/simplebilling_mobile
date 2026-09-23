import 'package:flutter_test/flutter_test.dart';
import 'package:simplebilling_mobile/core/utils/fifo_engine.dart';

void main() {
  group('FIFO Payment Settlement Engine Tests', () {
    test('Overpayment settles prior unpaid bills and remainder credits as advance', () {
      final result = calculatePaymentAllocation(
        roundedGrandTotal: 100.0,
        directPaid: 300.0,
        advanceUsed: 0.0,
        priorOutstandingBillsTotal: 150.0,
      );

      expect(result.paidTotalForCurrentBill, 100.0);
      expect(result.allocatedToPriorBills, 150.0);
      expect(result.advanceEarned, 50.0);
    });

    test('Exact payment allocates 0 to prior bills and 0 to advance', () {
      final result = calculatePaymentAllocation(
        roundedGrandTotal: 75.0,
        directPaid: 75.0,
        advanceUsed: 0.0,
        priorOutstandingBillsTotal: 200.0,
      );

      expect(result.paidTotalForCurrentBill, 75.0);
      expect(result.allocatedToPriorBills, 0.0);
      expect(result.advanceEarned, 0.0);
    });

    test('Partial payment on credit ("Pay Later") leaves advance and prior allocations at 0', () {
      final result = calculatePaymentAllocation(
        roundedGrandTotal: 120.0,
        directPaid: 50.0,
        advanceUsed: 0.0,
        priorOutstandingBillsTotal: 80.0,
      );

      expect(result.paidTotalForCurrentBill, 50.0);
      expect(result.allocatedToPriorBills, 0.0);
      expect(result.advanceEarned, 0.0);
    });

    test('Overpayment smaller than prior dues allocates all surplus to prior bills', () {
      final result = calculatePaymentAllocation(
        roundedGrandTotal: 50.0,
        directPaid: 100.0,
        advanceUsed: 0.0,
        priorOutstandingBillsTotal: 100.0,
      );

      expect(result.paidTotalForCurrentBill, 50.0);
      expect(result.allocatedToPriorBills, 50.0);
      expect(result.advanceEarned, 0.0);
    });
  });
}
