import 'package:flutter_test/flutter_test.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

void main() {
  group('POS Cart Price & Quantity Editing Tests', () {
    late CartNotifier cartNotifier;

    setUp(() {
      cartNotifier = CartNotifier();
    });

    test('Add item to cart and verify initial state', () {
      cartNotifier.addItem('A4 B&W Xerox', 2.0, 10, productId: 'prod-1');
      expect(cartNotifier.state.items.length, 1);
      expect(cartNotifier.state.items[0].productName, 'A4 B&W Xerox');
      expect(cartNotifier.state.items[0].price, 2.0);
      expect(cartNotifier.state.items[0].quantity, 10.0);
      expect(cartNotifier.state.items[0].total, 20.0);
      expect(cartNotifier.state.subtotal, 20.0);
    });

    test('Update item quantity with exact integer value (e.g. 250 copies)', () {
      cartNotifier.addItem('A4 Color Print', 10.0, 1, productId: 'prod-2');
      cartNotifier.updateItemQuantity(0, 250);

      expect(cartNotifier.state.items[0].quantity, 250.0);
      expect(cartNotifier.state.items[0].total, 2500.0);
      expect(cartNotifier.state.subtotal, 2500.0);
    });

    test('Update item quantity with decimal value (e.g. 1.5 units)', () {
      cartNotifier.addItem('Custom Paper Stock', 45.0, 1);
      cartNotifier.updateItemQuantity(0, 1.5);

      expect(cartNotifier.state.items[0].quantity, 1.5);
      expect(cartNotifier.state.items[0].total, 67.5);
      expect(cartNotifier.state.subtotal, 67.5);
    });

    test('Update item unit price overrides rate and recalculates item total', () {
      cartNotifier.addItem('Bulk Xerox', 2.0, 500);
      // Give bulk discount price override to 1.50 per page
      cartNotifier.updateItemPrice(0, 1.50);

      expect(cartNotifier.state.items[0].price, 1.50);
      expect(cartNotifier.state.items[0].quantity, 500.0);
      expect(cartNotifier.state.items[0].total, 750.0);
      expect(cartNotifier.state.subtotal, 750.0);
    });

    test('Setting item quantity to 0 removes item from cart', () {
      cartNotifier.addItem('Spiral Binding', 40.0, 2);
      expect(cartNotifier.state.items.length, 1);

      cartNotifier.updateItemQuantity(0, 0);
      expect(cartNotifier.state.items.isEmpty, isTrue);
      expect(cartNotifier.state.subtotal, 0.0);
    });

    test('Setting negative price is ignored', () {
      cartNotifier.addItem('A4 Lamination', 25.0, 2);
      cartNotifier.updateItemPrice(0, -10.0);

      // Price should remain unchanged
      expect(cartNotifier.state.items[0].price, 25.0);
      expect(cartNotifier.state.items[0].total, 50.0);
    });

    test('Multiple items with custom price and decimal quantity subtotal calculation', () {
      cartNotifier.addItem('A4 B&W', 2.0, 100); // 200
      cartNotifier.addItem('Binding', 30.0, 1);  // 30
      cartNotifier.addItem('Special Ink', 120.0, 0.5); // 60

      cartNotifier.updateItemPrice(0, 1.75); // 100 * 1.75 = 175

      expect(cartNotifier.state.items.length, 3);
      expect(cartNotifier.state.items[0].total, 175.0);
      expect(cartNotifier.state.items[1].total, 30.0);
      expect(cartNotifier.state.items[2].total, 60.0);
      expect(cartNotifier.state.subtotal, 265.0);
    });
  });

  group('Simultaneous Percentage & Flat Discount Tests', () {
    late CartNotifier cartNotifier;

    setUp(() {
      cartNotifier = CartNotifier();
      // Add items with subtotal = 1000
      cartNotifier.addItem('Bulk Xerox', 2.0, 500); // subtotal = 1000
    });

    test('Percentage discount only', () {
      cartNotifier.setPercentageDiscount(10.0); // 10% of 1000 = 100
      expect(cartNotifier.state.percentageDiscount, 10.0);
      expect(cartNotifier.state.percentDiscountAmount, 100.0);
      expect(cartNotifier.state.flatDiscount, 0.0);
      expect(cartNotifier.state.manualDiscount, 100.0);
    });

    test('Flat discount only', () {
      cartNotifier.setFlatDiscount(50.0); // 50 flat
      expect(cartNotifier.state.percentageDiscount, 0.0);
      expect(cartNotifier.state.percentDiscountAmount, 0.0);
      expect(cartNotifier.state.flatDiscount, 50.0);
      expect(cartNotifier.state.manualDiscount, 50.0);
    });

    test('Simultaneous Percentage + Flat discount (Independent Sum)', () {
      cartNotifier.setPercentageDiscount(10.0); // 100.0
      cartNotifier.setFlatDiscount(50.0);       // 50.0
      expect(cartNotifier.state.percentDiscountAmount, 100.0);
      expect(cartNotifier.state.flatDiscount, 50.0);
      expect(cartNotifier.state.manualDiscount, 150.0);
    });

    test('Discount clamped to subtotal when exceeding 100%', () {
      cartNotifier.setPercentageDiscount(80.0); // 800.0
      cartNotifier.setFlatDiscount(500.0);      // 500.0 -> total 1300 > 1000
      expect(cartNotifier.state.manualDiscount, 1000.0); // clamped to subtotal
    });

    test('Clear discounts resets both percentage and flat discounts', () {
      cartNotifier.setPercentageDiscount(15.0);
      cartNotifier.setFlatDiscount(75.0);
      expect(cartNotifier.state.manualDiscount, 225.0);

      cartNotifier.clearDiscounts();
      expect(cartNotifier.state.percentageDiscount, 0.0);
      expect(cartNotifier.state.flatDiscount, 0.0);
      expect(cartNotifier.state.manualDiscount, 0.0);
    });
  });

  group('Loyalty Points Redemption & Customer Due Tests', () {
    late CartNotifier cartNotifier;
    final testCustomer = CustomerModel(
      id: 'cust-101',
      name: 'Rohan Sharma',
      mobile: '9876543210',
      loyaltyPoints: 150.0,
      balanceDue: 450.0,
      advanceBalance: 50.0,
    );
    final loyaltySettings = LoyaltySettings(
      enabled: true,
      pointsRequired: 10.0,
      discountValue: 5.0,
    );
    final loyaltyRules = [
      LoyaltyRedemptionRule(id: 'r1', pointsRequired: 50, discountAmount: 30, enabled: true),
      LoyaltyRedemptionRule(id: 'r2', pointsRequired: 20, discountAmount: 10, enabled: true),
    ];

    setUp(() {
      cartNotifier = CartNotifier();
      cartNotifier.addItem('Xerox Job', 2.0, 250); // subtotal = 500
    });

    test('Selecting customer sets customer, advance and resets points to redeem', () {
      cartNotifier.selectCustomer(testCustomer);
      expect(cartNotifier.state.selectedCustomer, isNotNull);
      expect(cartNotifier.state.selectedCustomer!.loyaltyPoints, 150.0);
      expect(cartNotifier.state.selectedCustomer!.balanceDue, 450.0);
      expect(cartNotifier.state.pointsToRedeem, 0.0);
      expect(cartNotifier.state.useAdvance, isTrue);
      expect(cartNotifier.state.advanceUsed, 50.0);
    });

    test('Setting points to redeem calculates tier discount correctly', () {
      cartNotifier.selectCustomer(testCustomer);
      cartNotifier.setPointsToRedeem(100.0); // 2x 50pts = 60 discount

      final discount = cartNotifier.state.calculateLoyaltyDiscount(loyaltySettings, loyaltyRules);
      expect(discount, 60.0);

      final roundingRes = cartNotifier.state.getRoundingResult(discount);
      expect(roundingRes.roundedTotal, 440.0); // 500 - 60 = 440
    });

    test('Clearing points to redeem resets loyalty discount to 0', () {
      cartNotifier.selectCustomer(testCustomer);
      cartNotifier.setPointsToRedeem(50.0);
      expect(cartNotifier.state.pointsToRedeem, 50.0);

      cartNotifier.clearPointsToRedeem();
      expect(cartNotifier.state.pointsToRedeem, 0.0);
      final discount = cartNotifier.state.calculateLoyaltyDiscount(loyaltySettings, loyaltyRules);
      expect(discount, 0.0);
    });
  });
}
