import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simplebilling_mobile/core/network/supabase_client.dart';
import 'package:simplebilling_mobile/core/utils/rounding_engine.dart';
import 'package:simplebilling_mobile/data/mock/mock_data_store.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SupabaseConfig.setMockMode(true);
    await MockDataStore.instance.resetToDefaults();
  });

  group('Mock Sandbox Data Store & Clean State Tests', () {
    test('isMockMode is true when configured or using placeholder credentials', () {
      expect(SupabaseConfig.isMockMode, isTrue);
    });

    test('Starts with clean empty products, customers, and bills in sandbox', () async {
      final products = await ApiRepository.getProducts();
      final customers = await ApiRepository.getCustomers();
      final bills = await ApiRepository.getBills();

      expect(products.isEmpty, isTrue);
      expect(customers.isEmpty, isTrue);
      expect(bills.isEmpty, isTrue);
    });

    test('Generates sequential mock IDs starting from 1', () async {
      final billSeq1 = await ApiRepository.getNextSequence('BILL');
      final billSeq2 = await ApiRepository.getNextSequence('BILL');

      expect(billSeq1, 'BILL-000001');
      expect(billSeq2, 'BILL-000002');
    });

    test('Creates product and customer in sandbox dynamically', () async {
      final newCustomer = await ApiRepository.createCustomer(
        'Sandbox Test User',
        '9999988888',
        email: 'sandbox@test.com',
        initialAdvance: 500.0,
      );

      expect(newCustomer, isNotNull);
      expect(newCustomer!.name, 'Sandbox Test User');
      expect(newCustomer.advanceBalance, 500.0);

      final fetchedCustomer = await ApiRepository.getCustomer(newCustomer.id);
      expect(fetchedCustomer, isNotNull);
      expect(fetchedCustomer!.name, 'Sandbox Test User');
    });

    test('Creates POS Bill and updates customer dues dynamically', () async {
      final customer = await ApiRepository.createCustomer(
        'Test Customer',
        '9876543210',
      );

      final bill = await ApiRepository.createBill(
        customerId: customer!.id,
        total: 100.0,
        discount: 0.0,
        gstAmount: 0.0,
        roundingMethod: RoundingMethod.none,
        roundingAdjustment: 0.0,
        grandTotal: 100.0,
        cashPaid: 50.0,
        upiPaid: 0.0,
        cardPaid: 0.0,
        advanceUsed: 0.0,
        advanceEarned: 0.0,
        paymentMethod: 'Cash',
        loyaltyPointsEarned: 1.0,
        loyaltyPointsRedeemed: 0.0,
        items: [
          BillItemModel(
            productName: 'A4 Color Print Single Side',
            quantity: 10.0,
            price: 10.0,
            total: 100.0,
          ),
        ],
      );

      expect(bill, isNotNull);
      expect(bill!.grandTotal, 100.0);
      expect(bill.paidTotal, 50.0);

      final ledger = await ApiRepository.getCustomerLedger(customer.id);
      expect(ledger.isNotEmpty, isTrue);
    });

    test('Reset sandbox clears all created data back to clean state', () async {
      await ApiRepository.createProduct('Temporary Item', 'Test', 99.0);
      var products = await ApiRepository.getProducts();
      expect(products.length, 1);

      await MockDataStore.instance.resetToDefaults();
      products = await ApiRepository.getProducts();
      expect(products.isEmpty, isTrue);
    });
  });
}
