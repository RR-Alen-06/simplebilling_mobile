import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simplebilling_mobile/core/network/supabase_client.dart';
import 'package:simplebilling_mobile/data/mock/mock_data_store.dart';

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
      final products = await MockDataStore.instance.getProducts();
      final customers = await MockDataStore.instance.getCustomers();
      final bills = await MockDataStore.instance.getBills();

      expect(products.isEmpty, isTrue);
      expect(customers.isEmpty, isTrue);
      expect(bills.isEmpty, isTrue);
    });

    test('Generates sequential mock IDs starting from 1', () async {
      final billSeq1 = await MockDataStore.instance.getNextSequence('BILL');
      final billSeq2 = await MockDataStore.instance.getNextSequence('BILL');

      expect(billSeq1, 'BILL-000001');
      expect(billSeq2, 'BILL-000002');
    });

    test('Creates product and customer in sandbox dynamically', () async {
      final newCustomer = await MockDataStore.instance.createCustomer({
        'name': 'Sandbox Test User',
        'mobile': '9999988888',
        'email': 'sandbox@test.com',
        'initial_advance': 500.0,
      });

      expect(newCustomer.name, 'Sandbox Test User');

      final fetchedCustomer = await MockDataStore.instance.getCustomer(newCustomer.id);
      expect(fetchedCustomer, isNotNull);
      expect(fetchedCustomer!.name, 'Sandbox Test User');
    });

    test('Creates POS Bill and updates customer dues dynamically', () async {
      final customer = await MockDataStore.instance.createCustomer({
        'name': 'Test Customer',
        'mobile': '9876543210',
      });

      final bill = await MockDataStore.instance.createBill(
        {
          'customer_id': customer.id,
          'total': 100.0,
          'discount': 0.0,
          'gst_amount': 0.0,
          'grand_total': 100.0,
          'cash_paid': 50.0,
          'upi_paid': 0.0,
          'card_paid': 0.0,
          'paid_total': 50.0,
          'advance_used': 0.0,
          'payment_method': 'Cash',
        },
        [
          {
            'product_name': 'A4 Color Print Single Side',
            'quantity': 10.0,
            'price': 10.0,
            'total': 100.0,
          },
        ],
      );

      expect(bill.grandTotal, 100.0);
      expect(bill.paidTotal, 50.0);

      final ledger = await MockDataStore.instance.getCustomerLedger(customer.id);
      expect(ledger.isNotEmpty, isTrue);
    });

    test('Reset sandbox clears all created data back to clean state', () async {
      await MockDataStore.instance.createProduct({
        'name': 'Temporary Item',
        'category': 'Test',
        'price': 99.0,
      });
      var products = await MockDataStore.instance.getProducts();
      expect(products.length, 1);

      await MockDataStore.instance.resetToDefaults();
      products = await MockDataStore.instance.getProducts();
      expect(products.isEmpty, isTrue);
    });
  });
}
