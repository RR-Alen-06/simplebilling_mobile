import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simplebilling_mobile/core/network/supabase_client.dart';
import 'package:simplebilling_mobile/core/utils/fifo_engine.dart';
import 'package:simplebilling_mobile/core/utils/rounding_engine.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/main.dart';
import 'package:simplebilling_mobile/presentation/screens/main_shell_screen.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TASK 6: Quality & Readiness Widget and Logic Tests', () {
    testWidgets('App starts safely with no Supabase config and renders Offline/Guest login without crashing',
        (WidgetTester tester) async {
      // Set phone viewport dimensions (390 x 844)
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Ensure SupabaseConfig reports unconfigured in testing environment without crashing
      expect(SupabaseConfig.isConfigured, isFalse);

      await tester.pumpWidget(
        const ProviderScope(
          child: SimpleBillingApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the Login / Offline entry screen is displayed cleanly
      expect(find.text('SimpleBilling'), findsWidgets);
      expect(find.text('Merchant Sign In'), findsOneWidget);
      expect(find.text('Cloud backend not configured. You can use the app offline via Guest Mode.'), findsOneWidget);

      final guestBtn = find.text('Continue as Guest (Offline Mode)');
      expect(guestBtn, findsOneWidget);

      // Scroll to make sure button is fully visible and tap it
      await tester.ensureVisible(guestBtn);
      await tester.pumpAndSettle();
      await tester.tap(guestBtn);
      await tester.pumpAndSettle();

      // Verify entry into MainShellScreen and POS Wizard
      expect(find.byType(MainShellScreen), findsOneWidget);
      expect(find.text('POS Billing Wizard'), findsOneWidget);
    });

    test('CartNotifier accurately computes subtotals, manual percentage & flat discounts, and GST', () {
      final notifier = CartNotifier();

      // 1. Initial state
      expect(notifier.state.items, isEmpty);
      expect(notifier.state.subtotal, 0.0);

      // 2. Add 2 units of Item A @ Rs. 150 each
      notifier.addItem('Item A', 150.0, 2.0);
      expect(notifier.state.items.length, 1);
      expect(notifier.state.subtotal, 300.0);

      // 3. Add 1 unit of Item B @ Rs. 50
      notifier.addItem('Item B', 50.0, 1.0);
      expect(notifier.state.items.length, 2);
      expect(notifier.state.subtotal, 350.0);

      // 4. Update quantity of Item A to 3 units (Subtotal = 3 * 150 + 50 = 500)
      notifier.updateItemQuantity(0, 3.0);
      expect(notifier.state.subtotal, 500.0);

      // 5. Apply 10% discount (10% of 500 = 50.0)
      notifier.setPercentageDiscount(10.0);
      expect(notifier.state.percentDiscountAmount, 50.0);
      expect(notifier.state.manualDiscount, 50.0);

      // 6. Add flat discount of Rs. 20 (Total manual discount = 50 + 20 = 70.0)
      notifier.setFlatDiscount(20.0);
      expect(notifier.state.manualDiscount, 70.0);

      // 7. Verify GST calculation on discounted total (Net = 500 - 70 = 430, 18% GST = 77.40)
      final billingSettings = BillingSettings(gstEnabled: true, gstRate: 18.0);
      final totalAfterDiscount = notifier.state.subtotal - notifier.state.manualDiscount;
      final gst = notifier.state.calculateGst(billingSettings, totalAfterDiscount);
      expect(gst, 77.40);

      // 8. Verify Rounding Engine
      notifier.setRoundingMethod(RoundingMethod.roundUp);
      final roundingRes = notifier.state.getRoundingResult(0.0, gstAmount: gst);
      expect(roundingRes.roundedTotal, 508.0); // 430 + 77.40 = 507.40 -> roundUp = 508.0
      expect(roundingRes.roundingAdjustment, closeTo(0.60, 0.01));
    });

    test('FIFO Payment Allocation logic handles exact, overpayment, and credit settlements correctly', () {
      // Scenario A: Exact payment on current bill with prior dues -> All goes to current bill
      final exactAllocation = calculatePaymentAllocation(
        roundedGrandTotal: 250.0,
        directPaid: 250.0,
        advanceUsed: 0.0,
        priorOutstandingBillsTotal: 500.0,
      );
      expect(exactAllocation.paidTotalForCurrentBill, 250.0);
      expect(exactAllocation.allocatedToPriorBills, 0.0);
      expect(exactAllocation.advanceEarned, 0.0);

      // Scenario B: Overpayment of Rs. 200 (Total paid 450 on 250 bill) when customer has Rs. 150 prior due
      // Expect: 250 to current bill, 150 allocated to prior dues, 50 saved to advance wallet
      final overpaymentAllocation = calculatePaymentAllocation(
        roundedGrandTotal: 250.0,
        directPaid: 450.0,
        advanceUsed: 0.0,
        priorOutstandingBillsTotal: 150.0,
      );
      expect(overpaymentAllocation.paidTotalForCurrentBill, 250.0);
      expect(overpaymentAllocation.allocatedToPriorBills, 150.0);
      expect(overpaymentAllocation.advanceEarned, 50.0);

      // Scenario C: Partial credit payment (Tendered 100 on 300 bill) -> 100 paid to bill, 0 to prior/advance
      final partialCredit = calculatePaymentAllocation(
        roundedGrandTotal: 300.0,
        directPaid: 100.0,
        advanceUsed: 0.0,
        priorOutstandingBillsTotal: 100.0,
      );
      expect(partialCredit.paidTotalForCurrentBill, 100.0);
      expect(partialCredit.allocatedToPriorBills, 0.0);
      expect(partialCredit.advanceEarned, 0.0);
    });
  });
}
