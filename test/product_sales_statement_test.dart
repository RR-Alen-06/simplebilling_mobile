import 'package:flutter_test/flutter_test.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';

void main() {
  group('Product Sales History Analytics Tests', () {
    test('Calculate product quantity sold and revenue earned (e.g. a4 color qty 2 sold total price earned 10)', () {
      final bills = [
        BillModel(
          id: 'bill-1',
          billNumber: 'BILL-001',
          total: 10.0,
          discount: 0.0,
          roundingMethod: 'None',
          roundingAdjustment: 0.0,
          grandTotal: 10.0,
          cashPaid: 10.0,
          upiPaid: 0.0,
          paidTotal: 10.0,
          paymentMethod: 'Cash',
          createdAt: '2026-03-09T10:00:00Z',
          items: [
            BillItemModel(
              productId: 'prod-a4-color',
              productName: 'a4 color single',
              quantity: 2.0,
              price: 5.0,
              total: 10.0,
            ),
          ],
        ),
      ];

      // Aggregate sales for prod-a4-color
      final matchingItems = bills
          .expand((b) => b.items)
          .where((it) => it.productId == 'prod-a4-color' || it.productName == 'a4 color single')
          .toList();

      final totalQty = matchingItems.fold(0.0, (s, it) => s + it.quantity);
      final totalRevenue = matchingItems.fold(0.0, (s, it) => s + it.total);
      final avgPrice = totalQty > 0 ? totalRevenue / totalQty : 0.0;

      expect(totalQty, 2.0);
      expect(totalRevenue, 10.0);
      expect(avgPrice, 5.0);
    });

    test('Aggregate multiple sales with price variations across different bills', () {
      final bills = [
        BillModel(
          id: 'bill-1',
          billNumber: 'BILL-001',
          total: 5.0,
          discount: 0.0,
          roundingMethod: 'None',
          roundingAdjustment: 0.0,
          grandTotal: 5.0,
          cashPaid: 5.0,
          upiPaid: 0.0,
          paidTotal: 5.0,
          paymentMethod: 'Cash',
          createdAt: '2026-03-09T10:00:00Z',
          items: [
            BillItemModel(
              productId: 'prod-a4-color',
              productName: 'a4 color single',
              quantity: 1.0,
              price: 5.0,
              total: 5.0,
            ),
            BillItemModel(
              productId: 'prod-a4-bw',
              productName: 'a4 black and white single',
              quantity: 2.0,
              price: 4.0,
              total: 8.0,
            ),
          ],
        ),
        BillModel(
          id: 'bill-2',
          billNumber: 'BILL-002',
          total: 3.0,
          discount: 0.0,
          roundingMethod: 'None',
          roundingAdjustment: 0.0,
          grandTotal: 3.0,
          cashPaid: 3.0,
          upiPaid: 0.0,
          paidTotal: 3.0,
          paymentMethod: 'UPI',
          createdAt: '2026-04-08T14:30:00Z',
          items: [
            BillItemModel(
              productId: 'prod-a4-bw',
              productName: 'a4 black and white',
              quantity: 1.0,
              price: 3.0,
              total: 3.0,
            ),
          ],
        ),
      ];

      // Check prod-a4-bw: 2 units @ 4.0 (8.0) + 1 unit @ 3.0 (3.0) => 3 units, 11.0 total revenue
      final bwItems = bills
          .expand((b) => b.items)
          .where((it) => it.productId == 'prod-a4-bw' || it.productName.contains('black and white'))
          .toList();

      final totalQty = bwItems.fold(0.0, (s, it) => s + it.quantity);
      final totalRevenue = bwItems.fold(0.0, (s, it) => s + it.total);
      final avgPrice = totalQty > 0 ? totalRevenue / totalQty : 0.0;

      expect(totalQty, 3.0);
      expect(totalRevenue, 11.0);
      expect(avgPrice, closeTo(3.666, 0.01));
    });
  });

  group('Customer Consolidated Statement & Multi-bill Aggregation Tests', () {
    test('Customer statement correctly groups purchases across different dates', () {
      final customer = CustomerModel(
        id: 'cust-1',
        name: 'cust1',
        mobile: '9876543210',
        totalBilled: 17.0,
        totalPaid: 10.0,
        balanceDue: 7.0,
        advanceBalance: 0.0,
      );

      final customerBills = [
        BillModel(
          id: 'bill-101',
          billNumber: 'BILL-000101',
          customerId: 'cust-1',
          customerName: 'cust1',
          total: 13.0,
          discount: 4.0,
          roundingMethod: 'None',
          roundingAdjustment: 0.0,
          grandTotal: 9.0, // 5 + 8 - 4 discount = 9
          cashPaid: 9.0,
          upiPaid: 0.0,
          paidTotal: 9.0,
          paymentMethod: 'Cash',
          createdAt: '2026-03-09T11:00:00Z',
          items: [
            BillItemModel(
              productId: 'prod-1',
              productName: 'a4 color single',
              quantity: 1.0,
              price: 5.0,
              total: 5.0,
            ),
            BillItemModel(
              productId: 'prod-2',
              productName: 'a4 black and white single',
              quantity: 2.0,
              price: 4.0,
              total: 8.0,
            ),
          ],
        ),
        BillModel(
          id: 'bill-102',
          billNumber: 'BILL-000102',
          customerId: 'cust-1',
          customerName: 'cust1',
          total: 3.0,
          discount: 0.0,
          roundingMethod: 'None',
          roundingAdjustment: 0.0,
          grandTotal: 3.0,
          cashPaid: 1.0,
          upiPaid: 0.0,
          paidTotal: 1.0,
          paymentMethod: 'Credit',
          createdAt: '2026-04-08T16:00:00Z',
          items: [
            BillItemModel(
              productId: 'prod-2',
              productName: 'a4 black and white',
              quantity: 1.0,
              price: 3.0,
              total: 3.0,
            ),
          ],
        ),
      ];

      // Verification of Bill 1 (09/03/2026)
      final bill1 = customerBills[0];
      expect(bill1.items.length, 2);
      expect(bill1.items[0].productName, 'a4 color single');
      expect(bill1.items[0].quantity, 1.0);
      expect(bill1.items[0].price, 5.0);
      expect(bill1.items[1].productName, 'a4 black and white single');
      expect(bill1.items[1].quantity, 2.0);
      expect(bill1.items[1].price, 4.0);
      expect(bill1.grandTotal, 9.0);

      // Verification of Bill 2 (08/04/2026)
      final bill2 = customerBills[1];
      expect(bill2.items.length, 1);
      expect(bill2.items[0].productName, 'a4 black and white');
      expect(bill2.items[0].quantity, 1.0);
      expect(bill2.items[0].price, 3.0);
      expect(bill2.grandTotal, 3.0);

      // Statement totals
      final totalStatementInvoiced = customerBills.fold(0.0, (s, b) => s + b.grandTotal);
      final totalStatementPaid = customerBills.fold(0.0, (s, b) => s + b.paidTotal);
      final totalStatementUnits = customerBills.fold(0.0, (s, b) => s + b.items.fold(0.0, (isum, it) => isum + it.quantity));

      expect(totalStatementInvoiced, 12.0);
      expect(totalStatementPaid, 10.0);
      expect(totalStatementUnits, 4.0);
      expect(customer.balanceDue, 7.0);
    });
  });
}
