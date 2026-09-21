import 'dart:math';
import '../models/product_model.dart';
import '../models/customer_model.dart';
import '../models/customer_ledger_model.dart';
import '../models/bill_model.dart';
import '../models/expense_model.dart';
import '../models/settings_model.dart';
import '../models/dashboard_stats_model.dart';
import '../models/audit_log_model.dart';

class MockDatabase {
  static final MockDatabase instance = MockDatabase._();
  MockDatabase._() {
    _initDefaultData();
  }

  final List<ProductModel> _products = [];
  final List<CustomerModel> _customers = [];
  final List<BillModel> _bills = [];
  final List<ExpenseModel> _expenses = [];
  final List<CustomerLedgerEntry> _ledgerEntries = [];
  final List<AuditLogModel> _auditLogs = [];
  final Map<String, int> _sequences = {
    'BILL': 1005,
    'PRODUCT': 25,
    'CUSTOMER': 12,
    'EXPENSE': 8,
    'PAYMENT': 104,
  };

  ShopSettings _shopSettings = ShopSettings(
    shopName: 'PrintPro Xerox & Stationery (Demo)',
    address: '123 College Road, Campus Corner, Bangalore',
    phone: '+91 98765 43210',
    email: 'admin@printprodemo.com',
    gstNumber: '29ABCDE1234F1Z5',
    upiId: 'printpro@okaxis',
    logoUrl: '',
    footerMessage: 'Thank you for choosing PrintPro Demo! Visit again.',
  );

  BillingSettings _billingSettings = BillingSettings(
    billPrefix: 'BILL',
    billFormat: 'PREFIX_NUMBER',
    defaultPaymentMethod: 'CASH',
    currencySymbol: '₹',
    decimalPrecision: 2,
    gstEnabled: true,
    gstRate: 18.0,
    defaultPrinterSize: '80MM',
    autoPrint: true,
    roundingMethod: 'NEAREST',
  );

  LoyaltySettings _loyaltySettings = LoyaltySettings(
    enabled: true,
    pointsRequired: 10.0,
    discountValue: 5.0,
  );

  final List<LoyaltyRule> _loyaltyRules = [
    LoyaltyRule(
      id: 'rule_1',
      ruleName: 'Standard Earning',
      minBillAmount: 100.0,
      pointsEarned: 1.0,
      enabled: true,
      sortOrder: 1,
    ),
  ];

  final List<LoyaltyRedemptionRule> _redemptionRules = [
    LoyaltyRedemptionRule(
      id: 'red_1',
      pointsRequired: 10.0,
      discountAmount: 5.0,
      enabled: true,
    ),
  ];

  void _initDefaultData() {
    _products.clear();
    _products.addAll([
      ProductModel(id: 'prd_1', productCode: 'PRD-000001', name: 'A4 B&W Single Side', category: 'Xerox & Print', price: 2.00),
      ProductModel(id: 'prd_2', productCode: 'PRD-000002', name: 'A4 B&W Both Sides', category: 'Xerox & Print', price: 3.00),
      ProductModel(id: 'prd_3', productCode: 'PRD-000003', name: 'A4 Color Print Single', category: 'Xerox & Print', price: 10.00),
      ProductModel(id: 'prd_4', productCode: 'PRD-000004', name: 'A4 Color Both Sides', category: 'Xerox & Print', price: 18.00),
      ProductModel(id: 'prd_5', productCode: 'PRD-000005', name: 'Legal B&W Print', category: 'Xerox & Print', price: 3.00),
      ProductModel(id: 'prd_6', productCode: 'PRD-000006', name: 'A3 B&W Print', category: 'Xerox & Print', price: 5.00),
      ProductModel(id: 'prd_7', productCode: 'PRD-000007', name: 'A3 Color Print', category: 'Xerox & Print', price: 25.00),
      ProductModel(id: 'prd_8', productCode: 'PRD-000008', name: 'Glossy Photo Print 4x6', category: 'Xerox & Print', price: 15.00),
      ProductModel(id: 'prd_9', productCode: 'PRD-000009', name: 'PVC ID Card Print', category: 'Xerox & Print', price: 50.00),
      ProductModel(id: 'prd_10', productCode: 'PRD-000010', name: 'A4 Document Lamination', category: 'Lamination & Binding', price: 30.00),
      ProductModel(id: 'prd_11', productCode: 'PRD-000011', name: 'A3 Certificate Lamination', category: 'Lamination & Binding', price: 50.00),
      ProductModel(id: 'prd_12', productCode: 'PRD-000012', name: 'Spiral Binding (Up to 100 pgs)', category: 'Lamination & Binding', price: 40.00),
      ProductModel(id: 'prd_13', productCode: 'PRD-000013', name: 'Hard Cover Project Binding', category: 'Lamination & Binding', price: 200.00),
      ProductModel(id: 'prd_14', productCode: 'PRD-000014', name: 'Ballpoint Pen (Blue/Black)', category: 'Stationery', price: 10.00),
      ProductModel(id: 'prd_15', productCode: 'PRD-000015', name: 'Gel Pen 0.5mm (Pilot/Uniball)', category: 'Stationery', price: 25.00),
      ProductModel(id: 'prd_16', productCode: 'PRD-000016', name: 'A4 75GSM Copier Paper Ream', category: 'Paper & Envelopes', price: 280.00),
      ProductModel(id: 'prd_17', productCode: 'PRD-000017', name: 'Long Ruled Notebook 180 Pgs', category: 'Stationery', price: 60.00),
      ProductModel(id: 'prd_18', productCode: 'PRD-000018', name: 'A4 Clear Display Folder (20 Pockets)', category: 'Stationery', price: 80.00),
    ]);

    _customers.clear();
    _customers.addAll([
      CustomerModel(
        id: 'cust_1',
        customerCode: 'CUS-000001',
        name: 'Rajesh Sharma (College Staff)',
        mobile: '9876543210',
        email: 'rajesh.sharma@campus.edu',
        advanceBalance: 200.00,
        loyaltyPoints: 45.0,
        totalBilled: 1450.0,
        totalPaid: 1250.0,
        balanceDue: 200.0,
      ),
      CustomerModel(
        id: 'cust_2',
        customerCode: 'CUS-000002',
        name: 'Priya Patel (Architecture Student)',
        mobile: '9876543211',
        email: 'priya.patel@student.edu',
        advanceBalance: 50.00,
        loyaltyPoints: 30.0,
        totalBilled: 890.0,
        totalPaid: 840.0,
        balanceDue: 50.0,
      ),
      CustomerModel(
        id: 'cust_3',
        customerCode: 'CUS-000003',
        name: 'Apex Coaching Center (Monthly Account)',
        mobile: '9876543212',
        email: 'admin@apexcoaching.org',
        advanceBalance: 0.00,
        loyaltyPoints: 120.0,
        totalBilled: 3500.0,
        totalPaid: 2700.0,
        balanceDue: 800.0,
      ),
      CustomerModel(
        id: 'cust_4',
        customerCode: 'CUS-000004',
        name: 'Walk-in Customer (Standard)',
        mobile: '9876500000',
        advanceBalance: 0.00,
        loyaltyPoints: 5.0,
        totalBilled: 320.0,
        totalPaid: 320.0,
        balanceDue: 0.0,
      ),
    ]);

    final now = DateTime.now();
    _bills.clear();
    _bills.addAll([
      BillModel(
        id: 'bill_1001',
        billNumber: 'BILL-001001',
        customerId: 'cust_3',
        customerName: 'Apex Coaching Center (Monthly Account)',
        customerMobile: '9876543212',
        total: 1200.0,
        discount: 50.0,
        gstAmount: 0.0,
        roundingMethod: 'NEAREST',
        roundingAdjustment: 0.0,
        grandTotal: 1150.0,
        cashPaid: 500.0,
        upiPaid: 0.0,
        paidTotal: 500.0,
        paymentMethod: 'CASH',
        loyaltyPointsEarned: 11.0,
        createdAt: now.subtract(const Duration(hours: 3)).toIso8601String(),
        items: [
          BillItemModel(
            id: 'item_1',
            productId: 'prd_1',
            productName: 'A4 B&W Single Side',
            quantity: 500.0,
            price: 2.0,
            total: 1000.0,
          ),
          BillItemModel(
            id: 'item_2',
            productId: 'prd_12',
            productName: 'Spiral Binding (Up to 100 pgs)',
            quantity: 5.0,
            price: 40.0,
            total: 200.0,
          ),
        ],
      ),
      BillModel(
        id: 'bill_1002',
        billNumber: 'BILL-001002',
        customerId: 'cust_1',
        customerName: 'Rajesh Sharma (College Staff)',
        customerMobile: '9876543210',
        total: 350.0,
        discount: 0.0,
        gstAmount: 0.0,
        roundingMethod: 'NEAREST',
        roundingAdjustment: 0.0,
        grandTotal: 350.0,
        cashPaid: 0.0,
        upiPaid: 350.0,
        paidTotal: 350.0,
        paymentMethod: 'UPI',
        loyaltyPointsEarned: 3.0,
        createdAt: now.subtract(const Duration(hours: 1, minutes: 20)).toIso8601String(),
        items: [
          BillItemModel(
            id: 'item_3',
            productId: 'prd_3',
            productName: 'A4 Color Print Single',
            quantity: 15.0,
            price: 10.0,
            total: 150.0,
          ),
          BillItemModel(
            id: 'item_4',
            productId: 'prd_13',
            productName: 'Hard Cover Project Binding',
            quantity: 1.0,
            price: 200.0,
            total: 200.0,
          ),
        ],
      ),
    ]);

    _expenses.clear();
    _expenses.addAll([
      ExpenseModel(
        id: 'exp_1',
        expenseNumber: 'EXP-000001',
        title: 'Copier Paper Ream Stock (10 Reams)',
        amount: 2800.0,
        category: 'Supplies & Paper',
        paymentMode: 'UPI',
        date: now.subtract(const Duration(days: 1)).toIso8601String(),
      ),
      ExpenseModel(
        id: 'exp_2',
        expenseNumber: 'EXP-000002',
        title: 'Black Toner Cartridge Refill',
        amount: 850.0,
        category: 'Maintenance & Toner',
        paymentMode: 'Cash',
        date: now.toIso8601String(),
      ),
      ExpenseModel(
        id: 'exp_3',
        expenseNumber: 'EXP-000003',
        title: 'Staff Afternoon Refreshments & Tea',
        amount: 120.0,
        category: 'Tea & Refreshments',
        paymentMode: 'Cash',
        date: now.toIso8601String(),
      ),
    ]);

    _ledgerEntries.clear();
    _ledgerEntries.addAll([
      CustomerLedgerEntry(
        id: 'led_1',
        date: now.subtract(const Duration(days: 3)).toIso8601String(),
        type: LedgerEntryType.bill,
        referenceNumber: 'BILL-001000',
        description: 'Invoice billed (Cash)',
        billAmount: 1500.0,
        paidAmount: 700.0,
        runningBalance: 800.0,
        balanceType: LedgerBalanceType.due,
      ),
      CustomerLedgerEntry(
        id: 'led_2',
        date: now.subtract(const Duration(days: 1)).toIso8601String(),
        type: LedgerEntryType.payment,
        referenceNumber: 'PAY-000101',
        description: 'Direct Payment (UPI)',
        billAmount: 0.0,
        paidAmount: 300.0,
        runningBalance: 500.0,
        balanceType: LedgerBalanceType.due,
      ),
    ]);
  }

  // --- Sequences ---
  String getNextSequence(String key) {
    final k = key.toUpperCase();
    final current = _sequences[k] ?? 1;
    _sequences[k] = current + 1;
    final prefix = k.length > 3 ? k.substring(0, 3) : k;
    return '$prefix-${(current + 1).toString().padLeft(6, '0')}';
  }

  List<SequenceConfigModel> getSequenceConfigs() {
    return _sequences.entries
        .map((e) => SequenceConfigModel(
              key: e.key,
              prefix: e.key.length > 3 ? e.key.substring(0, 3) : e.key,
              padding: 6,
              currentVal: e.value,
            ))
        .toList();
  }

  void updateSequenceConfig(String key, String prefix, int padding, int currentVal) {
    _sequences[key.toUpperCase()] = currentVal;
  }

  // --- Products ---
  List<ProductModel> getProducts() => List.unmodifiable(_products);

  ProductModel createProduct(String name, String category, double price, {String? productCode}) {
    final code = productCode ?? getNextSequence('PRODUCT');
    final product = ProductModel(
      id: 'prd_${DateTime.now().millisecondsSinceEpoch}',
      productCode: code,
      name: name,
      category: category,
      price: price,
      createdAt: DateTime.now().toIso8601String(),
    );
    _products.add(product);
    return product;
  }

  bool updateProduct(String id, String name, String category, double price) {
    final idx = _products.indexWhere((p) => p.id == id);
    if (idx == -1) return false;
    _products[idx] = ProductModel(
      id: id,
      productCode: _products[idx].productCode,
      name: name,
      category: category,
      price: price,
      createdAt: _products[idx].createdAt,
    );
    return true;
  }

  bool deleteProduct(String id) {
    _products.removeWhere((p) => p.id == id);
    return true;
  }

  // --- Customers ---
  List<CustomerModel> getCustomers() => List.unmodifiable(_customers);

  List<CustomerModel> getCustomerSummaries() {
    return _customers.map((c) {
      final custBills = _bills.where((b) => b.customerId == c.id);
      final totalBilled = custBills.fold<double>(0.0, (sum, b) => sum + b.grandTotal);
      final totalPaid = custBills.fold<double>(0.0, (sum, b) => sum + b.paidTotal);
      final balanceDue = max(0.0, totalBilled - totalPaid - c.advanceBalance);
      return c.copyWith(
        totalBilled: totalBilled > 0 ? totalBilled : c.totalBilled,
        totalPaid: totalPaid > 0 ? totalPaid : c.totalPaid,
        balanceDue: balanceDue > 0 ? balanceDue : c.balanceDue,
      );
    }).toList();
  }

  CustomerModel? getCustomer(String id) {
    try {
      return _customers.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  CustomerModel createCustomer(String name, {String? mobile, String? email, double advance = 0.0}) {
    final code = getNextSequence('CUSTOMER');
    final cust = CustomerModel(
      id: 'cust_${DateTime.now().millisecondsSinceEpoch}',
      customerCode: code,
      name: name,
      mobile: mobile,
      email: email,
      advanceBalance: advance,
      loyaltyPoints: 0.0,
      createdAt: DateTime.now().toIso8601String(),
    );
    _customers.add(cust);
    return cust;
  }

  bool updateCustomer(String id, {required String name, String? mobile, String? email, double? advanceBalance, double? loyaltyPoints}) {
    final idx = _customers.indexWhere((c) => c.id == id);
    if (idx == -1) return false;
    final curr = _customers[idx];
    _customers[idx] = CustomerModel(
      id: id,
      customerCode: curr.customerCode,
      name: name,
      mobile: mobile ?? curr.mobile,
      email: email ?? curr.email,
      advanceBalance: advanceBalance ?? curr.advanceBalance,
      loyaltyPoints: loyaltyPoints ?? curr.loyaltyPoints,
      totalBilled: curr.totalBilled,
      totalPaid: curr.totalPaid,
      balanceDue: curr.balanceDue,
      createdAt: curr.createdAt,
    );
    return true;
  }

  bool deleteCustomer(String id) {
    _customers.removeWhere((c) => c.id == id);
    return true;
  }

  List<CustomerLedgerEntry> getCustomerLedger(String customerId) {
    return List.unmodifiable(_ledgerEntries);
  }

  bool recordCustomerPayment({
    required String customerId,
    required double amount,
    required String paymentMode,
    String? notes,
  }) {
    final custIdx = _customers.indexWhere((c) => c.id == customerId);
    if (custIdx != -1) {
      final cust = _customers[custIdx];
      final newDue = max(0.0, cust.balanceDue - amount);
      final extraAdv = amount > cust.balanceDue ? (amount - cust.balanceDue) : 0.0;
      _customers[custIdx] = cust.copyWith(
        balanceDue: newDue,
        advanceBalance: cust.advanceBalance + extraAdv,
        totalPaid: cust.totalPaid + amount,
      );
    }
    _ledgerEntries.add(
      CustomerLedgerEntry(
        id: 'led_${DateTime.now().millisecondsSinceEpoch}',
        date: DateTime.now().toIso8601String(),
        type: LedgerEntryType.payment,
        referenceNumber: 'PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        description: 'Direct Payment ($paymentMode)',
        billAmount: 0.0,
        paidAmount: amount,
        runningBalance: 0.0,
        balanceType: LedgerBalanceType.settled,
        notes: notes,
      ),
    );
    return true;
  }

  // --- Bills ---
  List<BillModel> getBills() => List.unmodifiable(_bills);

  BillModel? getBill(String id) {
    try {
      return _bills.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  BillModel createBill({
    required List<BillItemModel> items,
    String? customerId,
    String? customerName,
    String? customerMobile,
    String? customerEmail,
    required double total,
    required double discount,
    required double gstAmount,
    required String roundingMethod,
    required double roundingAdjustment,
    required double grandTotal,
    required double cashPaid,
    required double upiPaid,
    double cardPaid = 0.0,
    required double paidTotal,
    double advanceUsed = 0.0,
    double advanceEarned = 0.0,
    required String paymentMethod,
    double loyaltyPointsEarned = 0.0,
    double loyaltyPointsRedeemed = 0.0,
  }) {
    final billNumber = getNextSequence('BILL');
    final bill = BillModel(
      id: 'bill_${DateTime.now().millisecondsSinceEpoch}',
      billNumber: billNumber,
      customerId: customerId,
      customerName: customerName,
      customerMobile: customerMobile,
      customerEmail: customerEmail,
      total: total,
      discount: discount,
      gstAmount: gstAmount,
      roundingMethod: roundingMethod,
      roundingAdjustment: roundingAdjustment,
      grandTotal: grandTotal,
      cashPaid: cashPaid,
      upiPaid: upiPaid,
      cardPaid: cardPaid,
      paidTotal: paidTotal,
      advanceUsed: advanceUsed,
      advanceEarned: advanceEarned,
      paymentMethod: paymentMethod,
      loyaltyPointsEarned: loyaltyPointsEarned,
      loyaltyPointsRedeemed: loyaltyPointsRedeemed,
      createdAt: DateTime.now().toIso8601String(),
      items: items,
    );

    _bills.insert(0, bill);

    if (customerId != null) {
      final custIdx = _customers.indexWhere((c) => c.id == customerId);
      if (custIdx != -1) {
        final cust = _customers[custIdx];
        final dueInc = max(0.0, grandTotal - paidTotal - advanceUsed);
        _customers[custIdx] = cust.copyWith(
          totalBilled: cust.totalBilled + grandTotal,
          totalPaid: cust.totalPaid + paidTotal,
          balanceDue: cust.balanceDue + dueInc,
          advanceBalance: max(0.0, cust.advanceBalance - advanceUsed + advanceEarned),
          loyaltyPoints: max(0.0, cust.loyaltyPoints - loyaltyPointsRedeemed + loyaltyPointsEarned),
        );
      }
    }

    return bill;
  }

  bool updateBillDiscount({
    required String billId,
    required double newDiscount,
    required String reason,
    required String adminPin,
  }) {
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx == -1) return false;
    final old = _bills[idx];
    final grand = max(0.0, old.total - newDiscount + old.gstAmount);
    _bills[idx] = BillModel(
      id: old.id,
      billNumber: old.billNumber,
      customerId: old.customerId,
      customerName: old.customerName,
      customerMobile: old.customerMobile,
      customerEmail: old.customerEmail,
      total: old.total,
      discount: newDiscount,
      gstAmount: old.gstAmount,
      roundingMethod: old.roundingMethod,
      roundingAdjustment: old.roundingAdjustment,
      grandTotal: grand,
      cashPaid: old.cashPaid,
      upiPaid: old.upiPaid,
      cardPaid: old.cardPaid,
      paidTotal: old.paidTotal,
      advanceUsed: old.advanceUsed,
      advanceEarned: old.advanceEarned,
      paymentMethod: old.paymentMethod,
      loyaltyPointsEarned: old.loyaltyPointsEarned,
      loyaltyPointsRedeemed: old.loyaltyPointsRedeemed,
      createdAt: old.createdAt,
      isEdited: true,
      items: old.items,
    );
    return true;
  }

  bool deleteBill(String id) {
    _bills.removeWhere((b) => b.id == id);
    return true;
  }

  // --- Expenses ---
  List<ExpenseModel> getExpenses() => List.unmodifiable(_expenses);

  ExpenseModel createExpense({
    required String title,
    required double amount,
    String category = 'Shop Expense',
    String paymentMode = 'Cash',
    String? notes,
    required String date,
  }) {
    final exp = ExpenseModel(
      id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
      expenseNumber: getNextSequence('EXPENSE'),
      title: title,
      amount: amount,
      category: category,
      paymentMode: paymentMode,
      notes: notes,
      date: date,
    );
    _expenses.insert(0, exp);
    return exp;
  }

  bool deleteExpense(String id) {
    _expenses.removeWhere((e) => e.id == id);
    return true;
  }

  // --- Settings ---
  AllSettings getSettings() {
    return AllSettings(
      shop: _shopSettings,
      billing: _billingSettings,
      loyalty: _loyaltySettings,
    );
  }

  bool updateShopSettings(ShopSettings settings) {
    _shopSettings = settings;
    return true;
  }

  bool updateBillingSettings(BillingSettings settings) {
    _billingSettings = settings;
    return true;
  }

  bool updateLoyaltySettings(LoyaltySettings settings) {
    _loyaltySettings = settings;
    return true;
  }

  List<LoyaltyRule> getLoyaltyRules() => List.unmodifiable(_loyaltyRules);
  bool saveLoyaltyRule(LoyaltyRule rule) {
    final idx = _loyaltyRules.indexWhere((r) => r.id == rule.id);
    if (idx != -1) {
      _loyaltyRules[idx] = rule;
    } else {
      _loyaltyRules.add(rule);
    }
    return true;
  }

  List<LoyaltyRedemptionRule> getLoyaltyRedemptionRules() => List.unmodifiable(_redemptionRules);
  bool saveLoyaltyRedemptionRule(LoyaltyRedemptionRule rule) {
    final idx = _redemptionRules.indexWhere((r) => r.id == rule.id);
    if (idx != -1) {
      _redemptionRules[idx] = rule;
    } else {
      _redemptionRules.add(rule);
    }
    return true;
  }

  // --- Dashboard Stats ---
  DashboardStatsModel getDashboardStats() {
    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T')[0];

    final todaysBills = _bills.where((b) => b.createdAt.startsWith(todayStr)).toList();
    final todaysSales = todaysBills.fold<double>(0.0, (s, b) => s + b.grandTotal);
    final monthlySales = _bills.fold<double>(0.0, (s, b) => s + b.grandTotal);
    final pendingBalance = _customers.fold<double>(0.0, (s, c) => s + c.balanceDue);
    final totalExpense = _expenses.fold<double>(0.0, (s, e) => s + e.amount);
    final netProfit = monthlySales - totalExpense;

    return DashboardStatsModel(
      todaysSales: todaysSales,
      monthlySales: monthlySales,
      todaysBillsCount: todaysBills.length,
      pendingBalance: pendingBalance,
      totalCustomers: _customers.length,
      totalIncome: monthlySales,
      totalExpense: totalExpense,
      netProfit: netProfit,
      billsGenerated: _bills.length,
      averageBillValue: _bills.isEmpty ? 0.0 : monthlySales / _bills.length,
      salesTrend: [
        {'date': 'Mon', 'sales': 1450.0},
        {'date': 'Tue', 'sales': 2100.0},
        {'date': 'Wed', 'sales': 1800.0},
        {'date': 'Thu', 'sales': 2400.0},
        {'date': 'Fri', 'sales': 3100.0},
        {'date': 'Sat', 'sales': 4200.0},
        {'date': 'Sun', 'sales': 1500.0},
      ],
    );
  }

  // --- Audit Logs ---
  List<AuditLogModel> getAuditLogs() => List.unmodifiable(_auditLogs);

  void logAudit({required String action, required String entity, String? previousValue, String? newValue}) {
    _auditLogs.insert(
      0,
      AuditLogModel(
        id: 'aud_${DateTime.now().millisecondsSinceEpoch}',
        action: action,
        entity: entity,
        previousValue: previousValue,
        newValue: newValue,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  // --- Backup & Purge ---
  Map<String, dynamic> exportDatabaseBackup() {
    return {
      'exported_at': DateTime.now().toIso8601String(),
      'mode': 'DEMO_MOCK',
      'shop_settings': _shopSettings.toJson(),
      'billing_settings': _billingSettings.toJson(),
      'loyalty_settings': _loyaltySettings.toJson(),
      'products': _products.map((p) => p.toJson()).toList(),
      'customers': _customers.map((c) => c.toJson()).toList(),
      'bills': _bills.map((b) => b.toJson()).toList(),
      'expenses': _expenses.map((e) => e.toJson()).toList(),
    };
  }

  bool purgeBusinessData() {
    _bills.clear();
    _expenses.clear();
    _ledgerEntries.clear();
    for (int i = 0; i < _customers.length; i++) {
      _customers[i] = _customers[i].copyWith(
        totalBilled: 0.0,
        totalPaid: 0.0,
        balanceDue: 0.0,
      );
    }
    return true;
  }
}
