import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audit_log_model.dart';
import '../models/bill_model.dart';
import '../models/customer_ledger_model.dart';
import '../models/customer_model.dart';
import '../models/dashboard_stats_model.dart';
import '../models/expense_model.dart';
import '../models/payment_model.dart';
import '../models/product_model.dart';
import '../models/settings_model.dart';

class MockDataStore {
  MockDataStore._();
  static final MockDataStore instance = MockDataStore._();

  static const String _storageKey = 'printpro_mock_sandbox_data_v2';

  bool _initialized = false;

  List<ProductModel> _products = [];
  List<CustomerModel> _customers = [];
  List<BillModel> _bills = [];
  List<PaymentModel> _payments = [];
  List<ExpenseModel> _expenses = [];
  List<AuditLogModel> _auditLogs = [];
  AllSettings? _settings;
  List<LoyaltyRule> _loyaltyRules = [];
  List<LoyaltyRedemptionRule> _loyaltyRedemptionRules = [];
  Map<String, int> _sequenceCounters = {};

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString(_storageKey);
      if (dataStr != null && dataStr.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(dataStr);
        _loadFromJson(data);
      } else {
        _resetCleanState();
        await _persist();
      }
    } catch (e) {
      debugPrint('[MockDataStore] Error loading stored mock data: $e');
      _resetCleanState();
    }
    _initialized = true;
  }

  Future<void> resetToDefaults() async {
    _resetCleanState();
    await _persist();
    debugPrint('[MockDataStore] Reset to clean empty sandbox state.');
  }

  void _resetCleanState() {
    _sequenceCounters = {
      'PRD': 0,
      'CUST': 0,
      'BILL': 0,
      'EXP': 0,
      'PAY': 0,
    };

    _products = [];
    _customers = [];
    _bills = [];
    _payments = [];
    _expenses = [];
    _auditLogs = [];

    _settings = AllSettings(
      shop: ShopSettings(
        shopName: 'SimpleBilling Store',
        address: '',
        phone: '',
        email: '',
        footerMessage: 'Thank you for your business!',
      ),
      billing: BillingSettings(
        billPrefix: 'BILL',
        billFormat: 'BILL-{SEQ}',
        defaultPaymentMethod: 'Cash',
        currencySymbol: '₹',
        decimalPrecision: 2,
        gstEnabled: false,
        gstRate: 0.0,
        roundingMethod: 'None',
      ),
      loyalty: LoyaltySettings(
        enabled: true,
        pointsRequired: 10.0,
        discountValue: 5.0,
      ),
      email: EmailSettings(enabled: false),
    );

    _loyaltyRules = [];
    _loyaltyRedemptionRules = [];
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> data = {
        'products': _products.map((p) => p.toJson()).toList(),
        'customers': _customers.map((c) => c.toJson()).toList(),
        'bills': _bills.map((b) => b.toJson()).toList(),
        'payments': _payments.map((p) => p.toJson()).toList(),
        'expenses': _expenses.map((e) => e.toJson()).toList(),
        'sequences': _sequenceCounters,
        'settings': _settings?.toJson(),
        'loyaltyRules': _loyaltyRules.map((r) => r.toJson()).toList(),
        'loyaltyRedemptionRules': _loyaltyRedemptionRules.map((r) => r.toJson()).toList(),
        'auditLogs': _auditLogs.map((a) => a.toJson()).toList(),
      };
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      debugPrint('[MockDataStore] Error saving mock state: $e');
    }
  }

  void _loadFromJson(Map<String, dynamic> data) {
    if (data['products'] is List) {
      _products = (data['products'] as List).map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    if (data['customers'] is List) {
      _customers = (data['customers'] as List).map((e) => CustomerModel.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    if (data['bills'] is List) {
      _bills = (data['bills'] as List).map((e) => BillModel.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    if (data['payments'] is List) {
      _payments = (data['payments'] as List).map((e) => PaymentModel.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    if (data['expenses'] is List) {
      _expenses = (data['expenses'] as List).map((e) => ExpenseModel.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    if (data['sequences'] is Map) {
      _sequenceCounters = (data['sequences'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    }
    if (data['settings'] is Map) {
      _settings = AllSettings.fromJson(Map<String, dynamic>.from(data['settings']));
    }
    if (data['loyaltyRules'] is List) {
      _loyaltyRules = (data['loyaltyRules'] as List).map((e) => LoyaltyRule.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    if (data['loyaltyRedemptionRules'] is List) {
      _loyaltyRedemptionRules = (data['loyaltyRedemptionRules'] as List).map((e) => LoyaltyRedemptionRule.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    if (data['auditLogs'] is List) {
      _auditLogs = (data['auditLogs'] as List).map((e) => AuditLogModel.fromJson(Map<String, dynamic>.from(e))).toList();
    }
  }

  // --- SEQUENCE GENERATOR ---
  Future<String> getNextSequence(String key) async {
    await initialize();
    final pfx = key.toUpperCase();
    final current = _sequenceCounters[pfx] ?? 0;
    final next = current + 1;
    _sequenceCounters[pfx] = next;
    await _persist();
    return '$pfx-${next.toString().padLeft(6, '0')}';
  }

  // --- PRODUCTS ---
  Future<List<ProductModel>> getProducts() async {
    await initialize();
    return List.unmodifiable(_products);
  }

  Future<ProductModel> createProduct(Map<String, dynamic> productData) async {
    await initialize();
    final id = productData['id'] ?? 'mock_prd_${DateTime.now().millisecondsSinceEpoch}';
    final code = productData['product_code'] ?? await getNextSequence('PRD');
    final product = ProductModel(
      id: id,
      productCode: code,
      name: productData['name'] ?? 'Product',
      category: productData['category'] ?? 'General',
      price: (productData['price'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.now().toIso8601String(),
      clientRef: productData['client_ref'],
    );
    _products.insert(0, product);
    await _persist();
    return product;
  }

  Future<bool> updateProduct(String id, Map<String, dynamic> data) async {
    await initialize();
    final index = _products.indexWhere((p) => p.id == id);
    if (index == -1) return false;
    final existing = _products[index];
    _products[index] = ProductModel(
      id: existing.id,
      productCode: data['product_code'] ?? existing.productCode,
      name: data['name'] ?? existing.name,
      category: data['category'] ?? existing.category,
      price: (data['price'] as num?)?.toDouble() ?? existing.price,
      createdAt: existing.createdAt,
      clientRef: existing.clientRef,
    );
    await _persist();
    return true;
  }

  Future<bool> deleteProduct(String id) async {
    await initialize();
    _products.removeWhere((p) => p.id == id);
    await _persist();
    return true;
  }

  // --- CUSTOMERS ---
  Future<List<CustomerModel>> getCustomers() async {
    await initialize();
    return List.unmodifiable(_customers);
  }

  Future<List<CustomerModel>> getCustomerSummaries() async {
    await initialize();
    return _customers.map((c) {
      final due = (c.totalBilled - c.totalPaid - c.advanceBalance).clamp(0.0, double.infinity);
      return c.copyWith(balanceDue: due);
    }).toList();
  }

  Future<CustomerModel?> getCustomer(String id) async {
    await initialize();
    try {
      return _customers.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<CustomerModel> createCustomer(Map<String, dynamic> customerData) async {
    await initialize();
    final id = customerData['id'] ?? 'mock_cust_${DateTime.now().millisecondsSinceEpoch}';
    final code = customerData['customer_code'] ?? await getNextSequence('CUST');
    final cust = CustomerModel(
      id: id,
      customerCode: code,
      name: customerData['name'] ?? 'Customer',
      mobile: customerData['mobile'],
      email: customerData['email'],
      advanceBalance: (customerData['advance_balance'] as num?)?.toDouble() ?? 0.0,
      loyaltyPoints: (customerData['loyalty_points'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.now().toIso8601String(),
      clientRef: customerData['client_ref'],
    );
    _customers.insert(0, cust);
    await _persist();
    return cust;
  }

  Future<bool> updateCustomer(String id, Map<String, dynamic> data) async {
    await initialize();
    final index = _customers.indexWhere((c) => c.id == id);
    if (index == -1) return false;
    final existing = _customers[index];
    _customers[index] = existing.copyWith(
      name: data['name'] ?? existing.name,
      mobile: data.containsKey('mobile') ? data['mobile'] : existing.mobile,
      email: data.containsKey('email') ? data['email'] : existing.email,
      advanceBalance: data.containsKey('advance_balance') ? (data['advance_balance'] as num).toDouble() : existing.advanceBalance,
      loyaltyPoints: data.containsKey('loyalty_points') ? (data['loyalty_points'] as num).toDouble() : existing.loyaltyPoints,
    );
    await _persist();
    return true;
  }

  // --- BILLS ---
  Future<List<BillModel>> getBills() async {
    await initialize();
    return List.unmodifiable(_bills);
  }

  Future<BillModel> createBill(Map<String, dynamic> billData, List<Map<String, dynamic>> items) async {
    await initialize();
    final id = billData['id'] ?? 'mock_bill_${DateTime.now().millisecondsSinceEpoch}';
    final billNumber = billData['bill_number'] ?? await getNextSequence('BILL');

    final parsedItems = items.map((i) => BillItemModel(
      id: i['id'] ?? 'mock_item_${DateTime.now().millisecondsSinceEpoch}_${items.indexOf(i)}',
      billId: id,
      productId: i['product_id'],
      productName: i['product_name'] ?? 'Item',
      quantity: (i['quantity'] as num?)?.toDouble() ?? 1.0,
      price: (i['price'] as num?)?.toDouble() ?? (i['unit_price'] as num?)?.toDouble() ?? 0.0,
      total: (i['total'] as num?)?.toDouble() ?? 0.0,
    )).toList();

    final bill = BillModel(
      id: id,
      billNumber: billNumber,
      customerId: billData['customer_id'],
      customerName: billData['customer_name'],
      customerMobile: billData['customer_mobile'] ?? billData['customer_phone'],
      customerEmail: billData['customer_email'],
      total: (billData['total'] as num?)?.toDouble() ?? 0.0,
      discount: (billData['discount'] as num?)?.toDouble() ?? 0.0,
      gstAmount: (billData['gst_amount'] as num?)?.toDouble() ?? 0.0,
      roundingMethod: billData['rounding_method'] ?? 'None',
      roundingAdjustment: (billData['rounding_adjustment'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (billData['grand_total'] as num?)?.toDouble() ?? 0.0,
      cashPaid: (billData['cash_paid'] as num?)?.toDouble() ?? 0.0,
      upiPaid: (billData['upi_paid'] as num?)?.toDouble() ?? 0.0,
      cardPaid: (billData['card_paid'] as num?)?.toDouble() ?? 0.0,
      paidTotal: (billData['paid_total'] as num?)?.toDouble() ?? 0.0,
      advanceUsed: (billData['advance_used'] as num?)?.toDouble() ?? 0.0,
      advanceEarned: (billData['advance_earned'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: billData['payment_method'] ?? 'Cash',
      loyaltyPointsEarned: (billData['loyalty_points_earned'] as num?)?.toDouble() ?? 0.0,
      loyaltyPointsRedeemed: (billData['loyalty_points_redeemed'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.now().toIso8601String(),
      clientRef: billData['client_ref'],
      items: parsedItems,
    );

    _bills.insert(0, bill);

    if (bill.customerId != null) {
      final custIdx = _customers.indexWhere((c) => c.id == bill.customerId);
      if (custIdx != -1) {
        final cust = _customers[custIdx];
        final newBilled = cust.totalBilled + bill.grandTotal;
        final newPaid = cust.totalPaid + bill.paidTotal;
        final newAdvance = (cust.advanceBalance - bill.advanceUsed + bill.advanceEarned).clamp(0.0, double.infinity);
        final newLoyalty = (cust.loyaltyPoints + bill.loyaltyPointsEarned - bill.loyaltyPointsRedeemed).clamp(0.0, double.infinity);
        _customers[custIdx] = cust.copyWith(
          totalBilled: newBilled,
          totalPaid: newPaid,
          advanceBalance: newAdvance,
          loyaltyPoints: newLoyalty,
        );
      }
    }

    await _persist();
    return bill;
  }

  Future<bool> updateBillDiscount({
    required String billId,
    required double newDiscount,
    required double newGrandTotal,
    required double newPaidTotal,
    String? reason,
  }) async {
    await initialize();
    final index = _bills.indexWhere((b) => b.id == billId);
    if (index == -1) return false;
    final b = _bills[index];
    _bills[index] = BillModel(
      id: b.id,
      billNumber: b.billNumber,
      customerId: b.customerId,
      customerName: b.customerName,
      customerMobile: b.customerMobile,
      customerEmail: b.customerEmail,
      total: b.total,
      discount: newDiscount,
      gstAmount: b.gstAmount,
      roundingMethod: b.roundingMethod,
      roundingAdjustment: b.roundingAdjustment,
      grandTotal: newGrandTotal,
      cashPaid: b.cashPaid,
      upiPaid: b.upiPaid,
      cardPaid: b.cardPaid,
      paidTotal: newPaidTotal,
      advanceUsed: b.advanceUsed,
      advanceEarned: b.advanceEarned,
      paymentMethod: b.paymentMethod,
      loyaltyPointsEarned: b.loyaltyPointsEarned,
      loyaltyPointsRedeemed: b.loyaltyPointsRedeemed,
      createdAt: b.createdAt,
      clientRef: b.clientRef,
      isEdited: true,
      items: b.items,
    );
    await _persist();
    return true;
  }

  // --- PAYMENTS & CUSTOMER LEDGER ---
  Future<List<PaymentModel>> getPayments() async {
    await initialize();
    return List.unmodifiable(_payments);
  }

  Future<bool> recordCustomerPayment({
    required String customerId,
    required double amount,
    required String paymentMethod,
    String? notes,
    String? billId,
  }) async {
    await initialize();
    final paymentNumber = await getNextSequence('PAY');
    final cust = await getCustomer(customerId);

    final payment = PaymentModel(
      id: 'mock_pay_${DateTime.now().millisecondsSinceEpoch}',
      paymentNumber: paymentNumber,
      customerId: customerId,
      customerName: cust?.name,
      customerMobile: cust?.mobile,
      billId: billId,
      amount: amount,
      paymentMethod: paymentMethod,
      notes: notes,
      createdAt: DateTime.now().toIso8601String(),
    );

    _payments.insert(0, payment);

    if (cust != null) {
      final custIdx = _customers.indexWhere((c) => c.id == customerId);
      if (custIdx != -1) {
        _customers[custIdx] = cust.copyWith(
          totalPaid: cust.totalPaid + amount,
        );
      }
    }

    await _persist();
    return true;
  }

  Future<List<CustomerLedgerEntry>> getCustomerLedger(String customerId) async {
    await initialize();
    final List<CustomerLedgerEntry> entries = [];
    double running = 0.0;

    final customerBills = _bills.where((b) => b.customerId == customerId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final customerPayments = _payments.where((p) => p.customerId == customerId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final allEvents = <Map<String, dynamic>>[];
    for (final b in customerBills) {
      allEvents.add({
        'type': 'bill',
        'date': b.createdAt,
        'ref': b.billNumber,
        'desc': 'Sales Invoice',
        'billAmount': b.grandTotal,
        'paidAmount': b.paidTotal,
        'notes': 'Payment: ${b.paymentMethod}',
      });
    }
    for (final p in customerPayments) {
      allEvents.add({
        'type': 'payment',
        'date': p.createdAt,
        'ref': p.paymentNumber ?? 'PAY',
        'desc': 'Payment Received (${p.paymentMethod})',
        'billAmount': 0.0,
        'paidAmount': p.amount,
        'notes': p.notes,
      });
    }

    allEvents.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    for (final ev in allEvents) {
      final bAmt = ev['billAmount'] as double;
      final pAmt = ev['paidAmount'] as double;
      running += (bAmt - pAmt);

      entries.add(
        CustomerLedgerEntry(
          id: 'ledger_${entries.length + 1}',
          date: ev['date'] as String,
          type: ev['type'] == 'payment' ? LedgerEntryType.payment : LedgerEntryType.bill,
          referenceNumber: ev['ref'] as String,
          description: ev['desc'] as String,
          billAmount: bAmt,
          paidAmount: pAmt,
          runningBalance: running.abs(),
          balanceType: running > 0
              ? LedgerBalanceType.due
              : (running < 0 ? LedgerBalanceType.adv : LedgerBalanceType.settled),
          notes: ev['notes'] as String?,
        ),
      );
    }

    return entries.reversed.toList();
  }

  // --- EXPENSES ---
  Future<List<ExpenseModel>> getExpenses() async {
    await initialize();
    return List.unmodifiable(_expenses);
  }

  Future<ExpenseModel> createExpense(Map<String, dynamic> data) async {
    await initialize();
    final expNo = data['expense_number'] ?? await getNextSequence('EXP');
    final exp = ExpenseModel(
      id: data['id'] ?? 'mock_exp_${DateTime.now().millisecondsSinceEpoch}',
      expenseNumber: expNo,
      title: data['title'] ?? 'Expense',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      category: data['category'] ?? 'Shop Expense',
      paymentMode: data['payment_mode'] ?? 'Cash',
      notes: data['notes'],
      date: data['date'] ?? DateTime.now().toIso8601String(),
      clientRef: data['client_ref'],
    );
    _expenses.insert(0, exp);
    await _persist();
    return exp;
  }

  Future<bool> deleteExpense(String id) async {
    await initialize();
    _expenses.removeWhere((e) => e.id == id);
    await _persist();
    return true;
  }

  // --- SETTINGS ---
  Future<AllSettings> getSettings() async {
    await initialize();
    return _settings ??
        AllSettings(
          shop: ShopSettings(),
          billing: BillingSettings(),
          loyalty: LoyaltySettings(),
        );
  }

  Future<bool> saveSettings(AllSettings settings) async {
    await initialize();
    _settings = settings;
    await _persist();
    return true;
  }

  // --- LOYALTY RULES ---
  Future<List<LoyaltyRule>> getLoyaltyRules() async {
    await initialize();
    return List.unmodifiable(_loyaltyRules);
  }

  Future<List<LoyaltyRedemptionRule>> getLoyaltyRedemptionRules() async {
    await initialize();
    return List.unmodifiable(_loyaltyRedemptionRules);
  }

  Future<bool> saveLoyaltyRules(List<LoyaltyRule> rules) async {
    await initialize();
    _loyaltyRules = List.from(rules);
    await _persist();
    return true;
  }

  Future<bool> saveLoyaltyRedemptionRules(List<LoyaltyRedemptionRule> rules) async {
    await initialize();
    _loyaltyRedemptionRules = List.from(rules);
    await _persist();
    return true;
  }

  // --- DASHBOARD STATS ---
  Future<DashboardStatsModel> getDashboardStats() async {
    await initialize();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    double todaysSales = 0.0;
    int todaysBillsCount = 0;
    double monthlySales = 0.0;
    double totalIncome = 0.0;
    double totalExpense = 0.0;

    for (final b in _bills) {
      final date = DateTime.tryParse(b.createdAt) ?? now;
      totalIncome += b.grandTotal;
      if (date.isAfter(todayStart)) {
        todaysSales += b.grandTotal;
        todaysBillsCount++;
      }
      if (date.isAfter(monthStart)) {
        monthlySales += b.grandTotal;
      }
    }

    for (final e in _expenses) {
      totalExpense += e.amount;
    }

    double pendingBalance = 0.0;
    for (final c in _customers) {
      final due = c.totalBilled - c.totalPaid - c.advanceBalance;
      if (due > 0) pendingBalance += due;
    }

    final avgBill = _bills.isEmpty ? 0.0 : totalIncome / _bills.length;
    final netProfit = totalIncome - totalExpense;

    return DashboardStatsModel(
      todaysSales: todaysSales,
      monthlySales: monthlySales,
      todaysBillsCount: todaysBillsCount,
      pendingBalance: pendingBalance,
      totalCustomers: _customers.length,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netProfit: netProfit,
      billsGenerated: _bills.length,
      averageBillValue: avgBill,
      salesTrend: [],
    );
  }

  // --- AUDIT LOGS ---
  Future<List<AuditLogModel>> getAuditLogs() async {
    await initialize();
    return List.unmodifiable(_auditLogs);
  }

  Future<void> logAudit(String action, String details) async {
    await initialize();
    _auditLogs.insert(
      0,
      AuditLogModel(
        id: 'mock_audit_${DateTime.now().millisecondsSinceEpoch}',
        action: action,
        entity: 'System Activity',
        newValue: details,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    await _persist();
  }

  // --- SEQUENCE CONFIGS ---
  Future<List<SequenceConfigModel>> getSequenceConfigs() async {
    await initialize();
    return [
      SequenceConfigModel(id: 'seq_1', key: 'BILL', prefix: 'BILL', padding: 6, currentVal: _sequenceCounters['BILL'] ?? 0),
      SequenceConfigModel(id: 'seq_2', key: 'PRD', prefix: 'PRD', padding: 6, currentVal: _sequenceCounters['PRD'] ?? 0),
      SequenceConfigModel(id: 'seq_3', key: 'CUST', prefix: 'CUST', padding: 6, currentVal: _sequenceCounters['CUST'] ?? 0),
      SequenceConfigModel(id: 'seq_4', key: 'EXP', prefix: 'EXP', padding: 6, currentVal: _sequenceCounters['EXP'] ?? 0),
      SequenceConfigModel(id: 'seq_5', key: 'PAY', prefix: 'PAY', padding: 6, currentVal: _sequenceCounters['PAY'] ?? 0),
    ];
  }

  Future<bool> saveSequenceConfig(SequenceConfigModel config) async {
    await initialize();
    _sequenceCounters[config.key.toUpperCase()] = config.currentVal;
    await _persist();
    return true;
  }
}
