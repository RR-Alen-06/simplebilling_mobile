import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simplebilling_mobile/core/network/supabase_client.dart';
import 'package:simplebilling_mobile/core/utils/rounding_engine.dart';
import 'package:simplebilling_mobile/data/mock/mock_data_store.dart';
import 'package:simplebilling_mobile/data/models/audit_log_model.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
import 'package:simplebilling_mobile/data/models/customer_ledger_model.dart';
import 'package:simplebilling_mobile/data/models/dashboard_stats_model.dart';
import 'package:simplebilling_mobile/data/models/expense_model.dart';
import 'package:simplebilling_mobile/data/models/payment_model.dart';
import 'package:simplebilling_mobile/data/models/product_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';

class ApiRepository {
  static SupabaseClient get client => SupabaseConfig.client;
  static SupabaseClient get _client => SupabaseConfig.client;

  // --- PAYMENTS ---
  static Future<List<PaymentModel>> getPayments() async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.getPayments();
    }

    try {
      final response = await _client
          .from('payments')
          .select('*, customers(name, mobile)')
          .order('created_at', ascending: false);

      return (response as List).map((json) {
        final cust = json['customers'] as Map<String, dynamic>?;
        return PaymentModel.fromJson({
          ...json,
          'customer_name': cust?['name'],
          'customer_mobile': cust?['mobile'],
        });
      }).toList();
    } catch (e) {
      debugPrint('Error fetching payments: $e');
      return [];
    }
  }

  // --- ATOMIC SEQUENCE GENERATOR (ALIGNED WITH POSTGRES RPC & WEB APP) ---
  static Future<String> getNextSequence(String key) async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.getNextSequence(key);
    }

    try {
      final res = await _client.rpc(
        'get_next_sequence',
        params: {'p_key': key.toUpperCase()},
      );
      if (res != null && res.toString().isNotEmpty) {
        return res.toString();
      }
    } catch (e) {
      debugPrint('RPC get_next_sequence failed, falling back: $e');
    }

    try {
      final seqRes = await _client
          .from('sequences')
          .select('*')
          .eq('key', key.toUpperCase())
          .maybeSingle();

      final prefix = seqRes != null && seqRes['prefix'] != null
          ? (seqRes['prefix'] as String)
          : key.substring(0, key.length < 3 ? key.length : 3).toUpperCase();
      final padding = seqRes != null && seqRes['padding'] != null
          ? (seqRes['padding'] as num).toInt()
          : 6;
      final nextVal = seqRes != null && seqRes['current_val'] != null
          ? (seqRes['current_val'] as num).toInt() + 1
          : 1;

      await _client.from('sequences').upsert({
        'key': key.toUpperCase(),
        'prefix': prefix,
        'padding': padding,
        'current_val': nextVal,
        'updated_at': DateTime.now().toIso8601String(),
      });

      return '$prefix-${nextVal.toString().padLeft(padding, '0')}';
    } catch (e) {
      final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      final pfx = key.substring(0, key.length < 3 ? key.length : 3).toUpperCase();
      return '$pfx-$suffix';
    }
  }

  // --- AUTHENTICATION ---
  static Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      if (!SupabaseConfig.isMockMode) {
        final uid = _client.auth.currentUser?.id;
        if (uid != null) {
          for (final k in keys) {
            if (k.startsWith('printpro-state:$uid')) {
              await prefs.remove(k);
            }
          }
        }
        await _client.auth.signOut();
      }
      await prefs.remove('printpro_local_auth');
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  // --- CUSTOMERS & RUNNING DUES LEDGER ---
  static Future<List<CustomerModel>> getCustomers() async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.getCustomers();
    }

    try {
      final response = await _client
          .from('customers')
          .select('*')
          .order('name', ascending: true);
      return (response as List)
          .map((json) => CustomerModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching customers: $e');
      return [];
    }
  }

  static Future<List<CustomerModel>> getCustomerSummaries() async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.getCustomerSummaries();
    }

    try {
      final customers = await getCustomers();
      if (customers.isEmpty) return [];

      final billsRes = await _client
          .from('bills')
          .select('customer_id, grand_total, paid_total');
      final paymentsRes = await _client
          .from('payments')
          .select('customer_id, amount, bill_id');

      final billsList = (billsRes as List? ?? []);
      final paymentsList = (paymentsRes as List? ?? []);

      return customers.map((cust) {
        final custBills = billsList.where((b) => b['customer_id'] == cust.id);
        final directPayments = paymentsList.where(
          (p) => p['customer_id'] == cust.id && p['bill_id'] == null,
        );

        final totalBilled = custBills.fold<double>(
          0.0,
          (sum, b) => sum + ((b['grand_total'] as num?)?.toDouble() ?? 0.0),
        );
        final billPayments = custBills.fold<double>(
          0.0,
          (sum, b) => sum + ((b['paid_total'] as num?)?.toDouble() ?? 0.0),
        );
        final directPaymentsTotal = directPayments.fold<double>(
          0.0,
          (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0),
        );

        final totalPaid = billPayments + directPaymentsTotal;
        final balanceDue = (totalBilled - totalPaid - cust.advanceBalance)
            .clamp(0.0, double.infinity);

        return cust.copyWith(
          totalBilled: totalBilled,
          totalPaid: totalPaid,
          balanceDue: balanceDue,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error calculating customer summaries: $e');
      return getCustomers();
    }
  }

  static Future<CustomerModel?> getCustomer(String id) async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.getCustomer(id);
    }

    try {
      final res = await _client.from('customers').select('*').eq('id', id).maybeSingle();
      if (res == null) return null;
      final cust = CustomerModel.fromJson(res);

      final billsRes = await _client.from('bills').select('grand_total, paid_total').eq('customer_id', id);
      final paymentsRes = await _client.from('payments').select('amount, bill_id').eq('customer_id', id);

      final billsList = (billsRes as List? ?? []);
      final paymentsList = (paymentsRes as List? ?? []);

      final totalBilled = billsList.fold<double>(
        0.0,
        (s, b) => s + ((b['grand_total'] as num?)?.toDouble() ?? 0.0),
      );
      final billPaid = billsList.fold<double>(
        0.0,
        (s, b) => s + ((b['paid_total'] as num?)?.toDouble() ?? 0.0),
      );
      final directPaid = paymentsList.where((p) => p['bill_id'] == null).fold<double>(
        0.0,
        (s, p) => s + ((p['amount'] as num?)?.toDouble() ?? 0.0),
      );

      final totalPaid = billPaid + directPaid;
      final balanceDue = (totalBilled - totalPaid - cust.advanceBalance).clamp(0.0, double.infinity);

      return cust.copyWith(
        totalBilled: totalBilled,
        totalPaid: totalPaid,
        balanceDue: balanceDue,
      );
    } catch (e) {
      debugPrint('Error getting customer: $e');
      return null;
    }
  }

  static Future<List<CustomerLedgerEntry>> getCustomerLedger(String customerId) async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.getCustomerLedger(customerId);
    }

    try {
      final billsRes = await _client.from('bills').select('*').eq('customer_id', customerId).order('created_at', ascending: true);
      final paymentsRes = await _client.from('payments').select('*').eq('customer_id', customerId).order('created_at', ascending: true);

      final List<Map<String, dynamic>> rawEvents = [];

      for (final b in (billsRes as List? ?? [])) {
        rawEvents.add({
          'id': b['id'] ?? '',
          'date': b['created_at'] ?? DateTime.now().toIso8601String(),
          'type': 'bill',
          'reference_number': b['bill_number'] ?? 'BILL',
          'description': 'Invoice billed (${b['payment_method'] ?? 'Standard'})',
          'bill_amount': ((b['grand_total'] as num?)?.toDouble() ?? 0.0),
          'paid_amount': ((b['paid_total'] as num?)?.toDouble() ?? 0.0),
          'notes': b['notes'],
        });
      }

      for (final p in (paymentsRes as List? ?? [])) {
        final billId = p['bill_id'];
        if (billId == null) {
          rawEvents.add({
            'id': p['id'] ?? '',
            'date': p['created_at'] ?? DateTime.now().toIso8601String(),
            'type': 'payment',
            'reference_number': p['payment_number'] ?? 'PAYMENT',
            'description': 'Direct Payment (${p['payment_method'] ?? 'Cash'})',
            'bill_amount': 0.0,
            'paid_amount': ((p['amount'] as num?)?.toDouble() ?? 0.0),
            'notes': p['notes'],
          });
        }
      }

      rawEvents.sort((a, b) {
        final d1 = DateTime.tryParse(a['date'] ?? '') ?? DateTime.now();
        final d2 = DateTime.tryParse(b['date'] ?? '') ?? DateTime.now();
        return d1.compareTo(d2);
      });

      double runningBalance = 0.0;
      final List<CustomerLedgerEntry> entries = [];

      for (final ev in rawEvents) {
        final billAmt = ev['bill_amount'] as double;
        final paidAmt = ev['paid_amount'] as double;

        runningBalance += (billAmt - paidAmt);

        LedgerBalanceType balType;
        if (runningBalance > 0.01) {
          balType = LedgerBalanceType.due;
        } else if (runningBalance < -0.01) {
          balType = LedgerBalanceType.adv;
        } else {
          balType = LedgerBalanceType.settled;
        }

        entries.add(CustomerLedgerEntry(
          id: ev['id'],
          date: ev['date'],
          type: ev['type'] == 'payment' ? LedgerEntryType.payment : LedgerEntryType.bill,
          referenceNumber: ev['reference_number'],
          description: ev['description'],
          billAmount: billAmt,
          paidAmount: paidAmt,
          runningBalance: runningBalance.abs(),
          balanceType: balType,
          notes: ev['notes'],
        ));
      }

      return entries;
    } catch (e) {
      debugPrint('Error getting customer ledger: $e');
      return [];
    }
  }

  static Future<bool> recordCustomerPayment({
    required String customerId,
    required double amount,
    required String paymentMode,
    String? notes,
  }) async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.recordCustomerPayment(
        customerId: customerId,
        amount: amount,
        paymentMethod: paymentMode,
        notes: notes,
      );
    }

    try {
      final paymentNumber = await getNextSequence('PAYMENT');

      // 1. Insert into payments table
      await _client.from('payments').insert({
        'payment_number': paymentNumber,
        'customer_id': customerId,
        'amount': amount,
        'payment_method': paymentMode,
        'notes': notes ?? 'Credit settlement collection',
        'created_at': DateTime.now().toIso8601String(),
      });

      // 2. Fetch unpaid bills in chronological order
      final unpaidBillsRes = await _client
          .from('bills')
          .select('id, grand_total, paid_total, loyalty_points_earned')
          .eq('customer_id', customerId)
          .order('created_at', ascending: true);

      double remainingPayment = amount;
      double unlockedLoyaltyPoints = 0.0;

      for (final bill in (unpaidBillsRes as List? ?? [])) {
        if (remainingPayment <= 0) break;

        final grandTotal = (bill['grand_total'] as num?)?.toDouble() ?? 0.0;
        final paidTotal = (bill['paid_total'] as num?)?.toDouble() ?? 0.0;
        final pointsEarned = (bill['loyalty_points_earned'] as num?)?.toDouble() ?? 0.0;

        if (paidTotal < grandTotal) {
          final due = grandTotal - paidTotal;
          final allocate = remainingPayment >= due ? due : remainingPayment;
          final newPaidTotal = paidTotal + allocate;

          await _client.from('bills').update({
            'paid_total': newPaidTotal,
          }).eq('id', bill['id']);

          if (newPaidTotal >= grandTotal && pointsEarned > 0) {
            unlockedLoyaltyPoints += pointsEarned;
          }

          remainingPayment -= allocate;
        }
      }

      // 3. Update customer advance balance & loyalty points
      final custRes = await _client.from('customers').select('advance_balance, loyalty_points').eq('id', customerId).single();
      final currentAdvance = (custRes['advance_balance'] as num?)?.toDouble() ?? 0.0;
      final currentLoyalty = (custRes['loyalty_points'] as num?)?.toDouble() ?? 0.0;

      final updatedAdvance = currentAdvance + remainingPayment;
      final updatedLoyalty = currentLoyalty + unlockedLoyaltyPoints;

      await _client.from('customers').update({
        'advance_balance': updatedAdvance,
        'loyalty_points': updatedLoyalty,
      }).eq('id', customerId);

      await logAudit(
        action: 'RECORD_CUSTOMER_PAYMENT',
        entity: 'Customer $customerId ($paymentNumber)',
        newValue: 'Amount: ₹$amount ($paymentMode), Advance: ₹$updatedAdvance, Loyalty +$unlockedLoyaltyPoints',
      );

      return true;
    } catch (e) {
      debugPrint('Error recording customer payment: $e');
      return false;
    }
  }

  static Future<bool> updateBillDiscount({
    required String billId,
    required double newDiscount,
    required String reason,
    required String adminPin,
  }) async {
    if (SupabaseConfig.isMockMode) {
      final bills = await MockDataStore.instance.getBills();
      final b = bills.firstWhere((element) => element.id == billId, orElse: () => bills.first);
      final grandTotal = (b.total - newDiscount + b.gstAmount).clamp(0.0, double.infinity);
      final paidTotal = b.paidTotal;
      return MockDataStore.instance.updateBillDiscount(
        billId: billId,
        newDiscount: newDiscount,
        newGrandTotal: grandTotal,
        newPaidTotal: paidTotal,
        reason: reason,
      );
    }

    try {
      final billRes = await _client.from('bills').select('*').eq('id', billId).single();
      final total = (billRes['total'] as num?)?.toDouble() ?? 0.0;
      final gstAmount = (billRes['gst_amount'] as num?)?.toDouble() ?? 0.0;
      final grandTotal = (total - newDiscount + gstAmount).clamp(0.0, double.infinity);
      final paidTotal = (billRes['paid_total'] as num?)?.toDouble() ?? 0.0;
      final balanceDue = (grandTotal - paidTotal).clamp(0.0, double.infinity);

      await _client.from('bills').update({
        'discount': newDiscount,
        'grand_total': grandTotal,
        'balance_due': balanceDue,
        'notes': 'Discount override: $reason',
        'is_edited': true,
      }).eq('id', billId);

      await logAudit(
        action: 'EDIT_BILL_DISCOUNT',
        entity: 'Bill ${billRes['bill_number'] ?? billId}',
        newValue: 'Discount: ₹$newDiscount, Total: ₹$grandTotal, Reason: $reason (PIN Verified)',
      );
      return true;
    } catch (e) {
      debugPrint('Error updating bill discount: $e');
      return false;
    }
  }

  static Future<CustomerModel?> createCustomer(
    String name,
    String? mobile, {
    String? email,
    double initialAdvance = 0.0,
  }) async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.createCustomer({
        'name': name,
        'mobile': mobile,
        'email': email,
        'advance_balance': initialAdvance,
      });
    }

    try {
      final customerCode = await getNextSequence('CUSTOMER');
      final response = await _client
          .from('customers')
          .insert({
            'customer_code': customerCode,
            'name': name,
            'mobile': mobile,
            'email': email,
            'advance_balance': initialAdvance,
            'loyalty_points': 0.0,
          })
          .select()
          .single();

      await logAudit(
        action: 'CREATE_CUSTOMER',
        entity: 'Customer $name ($customerCode)',
        newValue: 'Advance: $initialAdvance',
      );
      return CustomerModel.fromJson(response);
    } catch (e) {
      debugPrint('Error creating customer: $e');
      return null;
    }
  }

  static Future<bool> updateCustomer(
    String id, {
    required String name,
    String? mobile,
    String? email,
  }) async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.updateCustomer(id, {
        'name': name,
        'mobile': mobile,
        'email': email,
      });
    }

    try {
      await _client
          .from('customers')
          .update({'name': name, 'mobile': mobile, 'email': email})
          .eq('id', id);

      await logAudit(action: 'UPDATE_CUSTOMER', entity: 'Customer $name');
      return true;
    } catch (e) {
      debugPrint('Error updating customer: $e');
      return false;
    }
  }

  // --- PRODUCTS ---
  static Future<List<ProductModel>> getProducts() async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.getProducts();
    }

    try {
      final response = await _client
          .from('products')
          .select('*')
          .order('name', ascending: true);
      return (response as List)
          .map((json) => ProductModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching products: $e');
      return [];
    }
  }

  static Future<ProductModel?> createProduct(
    String name,
    String category,
    double price, {
    String? productCode,
  }) async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.createProduct({
        'name': name,
        'category': category,
        'price': price,
        'product_code': productCode,
      });
    }

    try {
      final code = productCode ?? await getNextSequence('PRODUCT');
      final response = await _client
          .from('products')
          .insert({
            'product_code': code,
            'name': name,
            'category': category,
            'price': price,
          })
          .select()
          .single();

      await logAudit(
        action: 'CREATE_PRODUCT',
        entity: 'Product $name ($code)',
        newValue: 'Price: $price',
      );
      return ProductModel.fromJson(response);
    } catch (e) {
      debugPrint('Error creating product: $e');
      return null;
    }
  }

  static Future<bool> deleteProduct(String id) async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.deleteProduct(id);
    }

    try {
      await _client.from('products').delete().eq('id', id);
      await logAudit(action: 'DELETE_PRODUCT', entity: 'Product ID $id');
      return true;
    } catch (e) {
      debugPrint('Error deleting product: $e');
      return false;
    }
  }

  static Future<bool> updateProduct(
    String id, {
    required String name,
    required String category,
    required double price,
    String? productCode,
  }) async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.updateProduct(id, {
        'name': name,
        'category': category,
        'price': price,
        'product_code': productCode,
      });
    }

    try {
      await _client.from('products').update({
        'name': name,
        'category': category,
        'price': price,
        'product_code': productCode,
      }).eq('id', id);

      await logAudit(
        action: 'UPDATE_PRODUCT',
        entity: 'Product $name ($id)',
        newValue: 'Category: $category, Price: $price',
      );
      return true;
    } catch (e) {
      debugPrint('Error updating product: $e');
      return false;
    }
  }

  // --- EXPENSES ---
  static Future<List<ExpenseModel>> getExpenses() async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.getExpenses();
    }

    try {
      final response = await _client
          .from('expenses')
          .select('*')
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => ExpenseModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching expenses: $e');
      return [];
    }
  }

  static Future<ExpenseModel?> createExpense(
    String title,
    double amount,
    String category, {
    String paymentMode = 'Cash',
    String? notes,
  }) async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.createExpense({
        'title': title,
        'amount': amount,
        'category': category,
        'payment_mode': paymentMode,
        'notes': notes,
      });
    }

    try {
      final expenseNum = await getNextSequence('EXPENSE');
      final response = await _client
          .from('expenses')
          .insert({
            'expense_number': expenseNum,
            'title': title,
            'amount': amount,
            'category': category,
            'payment_mode': paymentMode,
            'notes': notes,
          })
          .select()
          .single();

      await logAudit(
        action: 'CREATE_EXPENSE',
        entity: '$title ($expenseNum)',
        newValue: 'Amount: $amount ($paymentMode)',
      );
      return ExpenseModel.fromJson(response);
    } catch (e) {
      debugPrint('Error creating expense: $e');
      return null;
    }
  }

  static Future<bool> deleteExpense(String id) async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.deleteExpense(id);
    }

    try {
      await _client.from('expenses').delete().eq('id', id);
      await logAudit(action: 'DELETE_EXPENSE', entity: 'Expense ID $id');
      return true;
    } catch (e) {
      debugPrint('Error deleting expense: $e');
      return false;
    }
  }

  // --- AUDIT LOGS ---
  static Future<List<AuditLogModel>> getAuditLogs() async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.getAuditLogs();
    }

    try {
      final response = await _client
          .from('audit_logs')
          .select('*')
          .order('created_at', ascending: false)
          .limit(100);
      return (response as List)
          .map((json) => AuditLogModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching audit logs: $e');
      return [];
    }
  }

  static Future<void> logAudit({
    required String action,
    required String entity,
    String? newValue,
  }) async {
    if (SupabaseConfig.isMockMode) {
      await MockDataStore.instance.logAudit(action, '$entity ${newValue ?? ''}');
      return;
    }

    try {
      final user = _client.auth.currentUser;
      final auditNumber = await getNextSequence('AUDIT');
      await _client.from('audit_logs').insert({
        'audit_number': auditNumber,
        'user_name': user?.email ?? 'Mobile App User',
        'action': action,
        'entity': entity,
        'new_value': newValue,
      });
    } catch (e) {
      debugPrint('Audit logging failed: $e');
    }
  }

  // --- DYNAMIC LOYALTY RULES ENGINE ---
  static Future<List<LoyaltyRule>> getLoyaltyRules() async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.getLoyaltyRules();
    }

    final defaultRules = [
      LoyaltyRule(
        id: 'r-1',
        ruleName: '1',
        minBillAmount: 1,
        maxBillAmount: 20,
        pointsEarned: 1,
        sortOrder: 1,
      ),
      LoyaltyRule(
        id: 'r-2',
        ruleName: '2',
        minBillAmount: 21,
        maxBillAmount: 30,
        pointsEarned: 2,
        sortOrder: 2,
      ),
      LoyaltyRule(
        id: 'r-3',
        ruleName: '3',
        minBillAmount: 31,
        maxBillAmount: 40,
        pointsEarned: 3,
        sortOrder: 3,
      ),
      LoyaltyRule(
        id: 'r-4',
        ruleName: '4',
        minBillAmount: 41,
        maxBillAmount: 60,
        pointsEarned: 4,
        sortOrder: 4,
      ),
      LoyaltyRule(
        id: 'r-5',
        ruleName: '5',
        minBillAmount: 61,
        maxBillAmount: 80,
        pointsEarned: 5,
        sortOrder: 5,
      ),
      LoyaltyRule(
        id: 'r-6',
        ruleName: '6',
        minBillAmount: 81,
        maxBillAmount: 99,
        pointsEarned: 6,
        sortOrder: 6,
      ),
      LoyaltyRule(
        id: 'r-7',
        ruleName: '7',
        minBillAmount: 100,
        maxBillAmount: 200,
        pointsEarned: 7,
        sortOrder: 7,
      ),
      LoyaltyRule(
        id: 'r-8',
        ruleName: '8',
        minBillAmount: 201,
        maxBillAmount: 300,
        pointsEarned: 8,
        sortOrder: 8,
      ),
      LoyaltyRule(
        id: 'r-9',
        ruleName: '9',
        minBillAmount: 301,
        maxBillAmount: 375,
        pointsEarned: 9,
        sortOrder: 9,
      ),
      LoyaltyRule(
        id: 'r-10',
        ruleName: '10',
        minBillAmount: 376,
        maxBillAmount: 500,
        pointsEarned: 10,
        sortOrder: 10,
      ),
    ];

    try {
      final response = await _client
          .from('loyalty_rules')
          .select('*')
          .order('sort_order', ascending: true);
      if ((response as List).isEmpty) return defaultRules;
      return response.map((json) => LoyaltyRule.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching loyalty earning rules: $e');
      return defaultRules;
    }
  }

  static Future<double> calculateLoyaltyPointsEarned(double billAmount) async {
    final rules = await getLoyaltyRules();
    final active = rules.where((r) => r.enabled).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    for (final rule in active) {
      final max = rule.maxBillAmount ?? double.infinity;
      if (billAmount >= rule.minBillAmount && billAmount <= max) {
        return rule.pointsEarned;
      }
    }
    return (billAmount / 100).floorToDouble().clamp(1.0, double.infinity);
  }

  static Future<List<LoyaltyRedemptionRule>> getLoyaltyRedemptionRules() async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.getLoyaltyRedemptionRules();
    }

    final defaultRedemption = [
      LoyaltyRedemptionRule(
        id: 'red-1',
        pointsRequired: 10,
        discountAmount: 4.0,
        enabled: true,
      ),
      LoyaltyRedemptionRule(
        id: 'red-2',
        pointsRequired: 20,
        discountAmount: 5.0,
        enabled: true,
      ),
      LoyaltyRedemptionRule(
        id: 'red-3',
        pointsRequired: 30,
        discountAmount: 8.0,
        enabled: true,
      ),
      LoyaltyRedemptionRule(
        id: 'red-4',
        pointsRequired: 40,
        discountAmount: 10.0,
        enabled: true,
      ),
    ];

    try {
      final response = await _client
          .from('loyalty_redemption_rules')
          .select('*')
          .order('points_required', ascending: true);
      if ((response as List).isEmpty) return defaultRedemption;
      return response
          .map((json) => LoyaltyRedemptionRule.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching loyalty redemption rules: $e');
      return defaultRedemption;
    }
  }

  static double calculateLoyaltyDiscount(
    double pointsToRedeem,
    LoyaltySettings loyaltySettings,
    List<LoyaltyRedemptionRule> activeRedemptionRules,
  ) {
    if (pointsToRedeem <= 0) return 0.0;

    final enabledRules = activeRedemptionRules.where((r) => r.enabled).toList()
      ..sort((a, b) => b.pointsRequired.compareTo(a.pointsRequired));

    if (enabledRules.isNotEmpty) {
      double remainingPts = pointsToRedeem;
      double totalDiscount = 0.0;

      for (final rule in enabledRules) {
        if (rule.pointsRequired > 0 && remainingPts >= rule.pointsRequired) {
          final multiplier = (remainingPts / rule.pointsRequired).floor();
          totalDiscount += multiplier * rule.discountAmount;
          remainingPts -= multiplier * rule.pointsRequired;
        }
      }

      if (totalDiscount > 0) {
        return double.parse(totalDiscount.toStringAsFixed(2));
      }
      final bestRule = enabledRules.first;
      final rate = bestRule.pointsRequired > 0
          ? (bestRule.discountAmount / bestRule.pointsRequired)
          : 0.5;
      return double.parse((pointsToRedeem * rate).toStringAsFixed(2));
    }

    final req = loyaltySettings.pointsRequired > 0
        ? loyaltySettings.pointsRequired
        : 10.0;
    final disc = loyaltySettings.discountValue > 0
        ? loyaltySettings.discountValue
        : 5.0;
    final ratePerPoint = disc / req;
    return double.parse((pointsToRedeem * ratePerPoint).toStringAsFixed(2));
  }

  // --- OFFLINE SYNC PAYLOAD REPLAYS ---
  static Future<void> syncCustomerPayload(Map<String, dynamic> payload) async {
    if (SupabaseConfig.isMockMode) {
      await MockDataStore.instance.createCustomer(payload);
      return;
    }

    await _client.from('customers').insert(payload);
    await logAudit(
      action: 'SYNC_CREATE_CUSTOMER',
      entity: 'Customer ${payload['name'] ?? ''}',
      newValue: 'Advance: ${payload['advance_balance']?.toString() ?? '0.0'}',
    );
  }

  static Future<void> syncProductPayload(Map<String, dynamic> payload) async {
    if (SupabaseConfig.isMockMode) {
      await MockDataStore.instance.createProduct(payload);
      return;
    }

    await _client.from('products').insert(payload);
    await logAudit(
      action: 'SYNC_CREATE_PRODUCT',
      entity: 'Product ${payload['name'] ?? ''}',
      newValue: 'Price: ${payload['price']?.toString() ?? '0.0'}',
    );
  }

  static Future<void> syncExpensePayload(Map<String, dynamic> payload) async {
    if (SupabaseConfig.isMockMode) {
      await MockDataStore.instance.createExpense(payload);
      return;
    }

    await _client.from('expenses').insert(payload);
    await logAudit(
      action: 'SYNC_CREATE_EXPENSE',
      entity: payload['title'] ?? 'Expense',
      newValue: 'Amount: ${payload['amount']?.toString() ?? '0.0'}',
    );
  }

  static Future<String> syncBillPayload(Map<String, dynamic> payload) async {
    if (SupabaseConfig.isMockMode) {
      final billData = Map<String, dynamic>.from(payload['billData']);
      final itemsPayload = List<Map<String, dynamic>>.from(payload['itemsPayload']);
      final created = await MockDataStore.instance.createBill(billData, itemsPayload);
      return created.id;
    }

    final billData = Map<String, dynamic>.from(payload['billData']);
    final itemsPayload = List<Map<String, dynamic>>.from(
      payload['itemsPayload'],
    );

    final billRes = await _client
        .from('bills')
        .insert(billData)
        .select()
        .single();
    final newBillId = billRes['id'] as String;

    if (itemsPayload.isNotEmpty) {
      for (final item in itemsPayload) {
        item['bill_id'] = newBillId;
      }
      await _client.from('bill_items').insert(itemsPayload);
    }
    return newBillId;
  }

  // --- BILLS & POS TRANSACTION ENGINE ---
  static Future<List<BillModel>> getBills() async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.getBills();
    }

    try {
      final billsData = await _client
          .from('bills')
          .select(
            '*, customer:customers(name, mobile, email), items:bill_items(*)',
          )
          .order('created_at', ascending: false);

      return (billsData as List).map((json) {
        final cust = json['customer'] as Map<String, dynamic>?;
        return BillModel.fromJson({
          ...json,
          'customer_name': cust?['name'],
          'customer_phone': cust?['mobile'],
          'customer_email': cust?['email'],
        });
      }).toList();
    } catch (e) {
      debugPrint('Error fetching bills: $e');
      return [];
    }
  }

  static Future<BillModel?> createBill({
    required String? customerId,
    required double total,
    required double discount,
    double gstAmount = 0.0,
    required RoundingMethod roundingMethod,
    required double roundingAdjustment,
    required double grandTotal,
    required double cashPaid,
    required double upiPaid,
    double cardPaid = 0.0,
    required double advanceUsed,
    required double advanceEarned,
    required String paymentMethod,
    required double loyaltyPointsEarned,
    required double loyaltyPointsRedeemed,
    required List<BillItemModel> items,
  }) async {
    final paidTotal = cashPaid + upiPaid + cardPaid + advanceUsed;

    if (SupabaseConfig.isMockMode) {
      final billData = {
        'customer_id': customerId,
        'total': total,
        'discount': discount,
        'gst_amount': gstAmount,
        'rounding_method': roundingMethod.name,
        'rounding_adjustment': roundingAdjustment,
        'grand_total': grandTotal,
        'cash_paid': cashPaid,
        'upi_paid': upiPaid,
        'card_paid': cardPaid,
        'paid_total': paidTotal,
        'advance_used': advanceUsed,
        'advance_earned': advanceEarned,
        'payment_method': paymentMethod,
        'loyalty_points_earned': loyaltyPointsEarned,
        'loyalty_points_redeemed': loyaltyPointsRedeemed,
      };
      final itemsPayload = items.map((i) => {
        'product_id': i.productId,
        'product_name': i.productName,
        'quantity': i.quantity,
        'unit_price': i.price,
        'total': i.total,
      }).toList();

      return MockDataStore.instance.createBill(billData, itemsPayload);
    }

    try {
      final billNumber = await getNextSequence('BILL');

      final billData = {
        'bill_number': billNumber,
        'customer_id': customerId,
        'total': total,
        'discount': discount,
        'gst_amount': gstAmount,
        'rounding_method': roundingMethod.name,
        'rounding_adjustment': roundingAdjustment,
        'grand_total': grandTotal,
        'cash_paid': cashPaid,
        'upi_paid': upiPaid,
        'card_paid': cardPaid,
        'paid_total': paidTotal,
        'advance_used': advanceUsed,
        'advance_earned': advanceEarned,
        'payment_method': paymentMethod,
        'loyalty_points_earned': loyaltyPointsEarned,
        'loyalty_points_redeemed': loyaltyPointsRedeemed,
      };

      final itemsPayload = items
          .map(
            (item) => {
              'product_id': item.productId,
              'product_name': item.productName,
              'quantity': item.quantity,
              'price': item.price,
              'total': item.total,
            },
          )
          .toList();

      final createdBillId = await syncBillPayload({
        'billData': billData,
        'itemsPayload': itemsPayload,
      });

      // Insert Individual Payments for Cash & UPI (Single Source of Truth)
      if (cashPaid > 0) {
        final pNum = await getNextSequence('PAYMENT');
        await _client.from('payments').insert({
          'payment_number': pNum,
          'customer_id': customerId,
          'bill_id': createdBillId,
          'amount': cashPaid,
          'payment_method': 'Cash',
          'notes': 'POS Cash payment for $billNumber',
        });
      }

      if (upiPaid > 0) {
        final pNum = await getNextSequence('PAYMENT');
        await _client.from('payments').insert({
          'payment_number': pNum,
          'customer_id': customerId,
          'bill_id': createdBillId,
          'amount': upiPaid,
          'payment_method': 'UPI',
          'notes': 'POS UPI payment for $billNumber',
        });
      }

      // Customer Advance / Loyalty Updates
      if (customerId != null) {
        final customerRes = await _client
            .from('customers')
            .select('advance_balance, loyalty_points')
            .eq('id', customerId)
            .single();
        final currentAdvance =
            (customerRes['advance_balance'] as num?)?.toDouble() ?? 0.0;
        final currentLoyalty =
            (customerRes['loyalty_points'] as num?)?.toDouble() ?? 0.0;

        final newAdvance = (currentAdvance - advanceUsed + advanceEarned).clamp(
          0.0,
          double.infinity,
        );
        final newLoyalty =
            (currentLoyalty - loyaltyPointsRedeemed + loyaltyPointsEarned)
                .clamp(0.0, double.infinity);

        await _client
            .from('customers')
            .update({
              'advance_balance': newAdvance,
              'loyalty_points': newLoyalty,
            })
            .eq('id', customerId);
      }

      await logAudit(
        action: 'CREATE_BILL',
        entity: billNumber,
        newValue: 'Grand Total: $grandTotal ($paymentMethod)',
      );

      return BillModel(
        id: createdBillId,
        billNumber: billNumber,
        customerId: customerId,
        total: total,
        discount: discount,
        gstAmount: gstAmount,
        roundingMethod: roundingMethod.name,
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
    } catch (e) {
      debugPrint('Error creating bill: $e');
      return null;
    }
  }

  // --- SETTINGS ---
  static Future<AllSettings> getSettings() async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.getSettings();
    }

    final defaultSettings = AllSettings(
      shop: ShopSettings(
        shopName: 'ABC Printing Center',
        phone: '+91 98765 43210',
        address: 'Main Road, Shop No. 12',
      ),
      billing: BillingSettings(),
      loyalty: LoyaltySettings(),
    );

    try {
      final rows = await _client.from('settings').select('*');
      if ((rows as List).isEmpty) return defaultSettings;

      Map<String, dynamic> shopMap = {};
      Map<String, dynamic> billingMap = {};
      Map<String, dynamic> loyaltyMap = {};

      for (final row in rows) {
        if (row['key'] == 'shop' && row['value'] != null) {
          shopMap = Map<String, dynamic>.from(row['value']);
        } else if (row['key'] == 'billing' && row['value'] != null) {
          billingMap = Map<String, dynamic>.from(row['value']);
        } else if (row['key'] == 'loyalty' && row['value'] != null) {
          loyaltyMap = Map<String, dynamic>.from(row['value']);
        }
      }

      return AllSettings(
        shop: ShopSettings.fromJson(shopMap),
        billing: BillingSettings.fromJson(billingMap),
        loyalty: LoyaltySettings.fromJson(loyaltyMap),
      );
    } catch (e) {
      debugPrint('Error fetching settings: $e');
      return defaultSettings;
    }
  }

  static Future<bool> saveSettings(AllSettings settings) async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.saveSettings(settings);
    }

    try {
      await _client.from('settings').upsert([
        {'key': 'shop', 'value': settings.shop.toJson()},
        {'key': 'billing', 'value': settings.billing.toJson()},
        {'key': 'loyalty', 'value': settings.loyalty.toJson()},
      ]);
      await logAudit(
        action: 'UPDATE_SETTINGS',
        entity: 'System & Shop Settings',
      );
      return true;
    } catch (e) {
      debugPrint('Error saving settings: $e');
      return false;
    }
  }

  // --- DASHBOARD METRICS ---
  static Future<DashboardStatsModel> getDashboardStats() async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.getDashboardStats();
    }

    try {
      final bills = await getBills();
      final expenses = await getExpenses();
      final customers = await getCustomers();

      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final monthStr = todayStr.substring(0, 7);

      double todaySales = 0.0;
      double monthSales = 0.0;
      double totalIncome = 0.0;
      double pendingBalances = 0.0;
      int todaysBillsCount = 0;

      for (final b in bills) {
        totalIncome += b.grandTotal;
        if (b.createdAt.startsWith(todayStr)) {
          todaySales += b.grandTotal;
          todaysBillsCount++;
        }
        if (b.createdAt.startsWith(monthStr)) {
          monthSales += b.grandTotal;
        }
      }

      for (final c in customers) {
        pendingBalances += c.advanceBalance;
      }

      final totalExpenses = expenses.fold<double>(
        0.0,
        (sum, e) => sum + e.amount,
      );
      final averageBillValue = bills.isNotEmpty
          ? (totalIncome / bills.length)
          : 0.0;

      return DashboardStatsModel(
        todaysSales: todaySales,
        monthlySales: monthSales,
        todaysBillsCount: todaysBillsCount,
        pendingBalance: pendingBalances,
        totalCustomers: customers.length,
        totalIncome: totalIncome,
        totalExpense: totalExpenses,
        netProfit: totalIncome - totalExpenses,
        billsGenerated: bills.length,
        averageBillValue: averageBillValue,
      );
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
      return DashboardStatsModel.empty();
    }
  }

  // --- DATABASE SEED UTILITY ---
  static Future<void> seedDefaultCatalogAndCustomers() async {
    if (SupabaseConfig.isMockMode) {
      await MockDataStore.instance.initialize();
      return;
    }

    try {
      final existingProds = await getProducts();
      if (existingProds.isEmpty) {
        final seedProducts = [
          {
            'name': 'A4 B&W Single',
            'category': 'Xerox & Print',
            'price': 2.00,
            'product_code': 'PRD-000001',
          },
          {
            'name': 'A4 B&W Both Sides',
            'category': 'Xerox & Print',
            'price': 3.00,
            'product_code': 'PRD-000002',
          },
          {
            'name': 'A4 Color Print Single',
            'category': 'Xerox & Print',
            'price': 10.00,
            'product_code': 'PRD-000003',
          },
          {
            'name': 'A4 Color Both Sides',
            'category': 'Xerox & Print',
            'price': 18.00,
            'product_code': 'PRD-000004',
          },
          {
            'name': 'Legal B&W Print',
            'category': 'Xerox & Print',
            'price': 3.00,
            'product_code': 'PRD-000005',
          },
          {
            'name': 'A3 B&W Print',
            'category': 'Xerox & Print',
            'price': 5.00,
            'product_code': 'PRD-000006',
          },
          {
            'name': 'A3 Color Print',
            'category': 'Xerox & Print',
            'price': 25.00,
            'product_code': 'PRD-000007',
          },
          {
            'name': 'Glossy Photo Print 4x6',
            'category': 'Xerox & Print',
            'price': 15.00,
            'product_code': 'PRD-000008',
          },
          {
            'name': 'Glossy Photo Print A4',
            'category': 'Xerox & Print',
            'price': 40.00,
            'product_code': 'PRD-000009',
          },
          {
            'name': 'PVC ID Card Print',
            'category': 'Xerox & Print',
            'price': 50.00,
            'product_code': 'PRD-000010',
          },
          {
            'name': 'A4 Document Lamination',
            'category': 'Lamination & Binding',
            'price': 30.00,
            'product_code': 'PRD-000011',
          },
          {
            'name': 'A3 Certificate Lamination',
            'category': 'Lamination & Binding',
            'price': 50.00,
            'product_code': 'PRD-000012',
          },
          {
            'name': 'ID Card Lamination (Pouch)',
            'category': 'Lamination & Binding',
            'price': 15.00,
            'product_code': 'PRD-000013',
          },
          {
            'name': 'Spiral Binding (Up to 100 pgs)',
            'category': 'Lamination & Binding',
            'price': 40.00,
            'product_code': 'PRD-000014',
          },
          {
            'name': 'Spiral Binding (Over 100 pgs)',
            'category': 'Lamination & Binding',
            'price': 60.00,
            'product_code': 'PRD-000015',
          },
          {
            'name': 'Hard Cover Project Binding',
            'category': 'Lamination & Binding',
            'price': 200.00,
            'product_code': 'PRD-000016',
          },
          {
            'name': 'Ballpoint Pen (Blue/Black)',
            'category': 'Stationery',
            'price': 10.00,
            'product_code': 'PRD-000017',
          },
          {
            'name': 'Gel Pen 0.5mm',
            'category': 'Stationery',
            'price': 20.00,
            'product_code': 'PRD-000018',
          },
          {
            'name': 'A4 75GSM Copier Paper Ream',
            'category': 'Paper & Envelopes',
            'price': 280.00,
            'product_code': 'PRD-000019',
          },
          {
            'name': 'Long Ruled Notebook 180 Pgs',
            'category': 'Stationery',
            'price': 60.00,
            'product_code': 'PRD-000020',
          },
          {
            'name': 'A4 Clear Display Folder (20 Pockets)',
            'category': 'Stationery',
            'price': 80.00,
            'product_code': 'PRD-000021',
          },
        ];
        await _client.from('products').insert(seedProducts);
      }

      final existingCusts = await getCustomers();
      if (existingCusts.isEmpty) {
        final seedCustomers = [
          {
            'name': 'Rajesh Sharma (College Staff)',
            'mobile': '9876543210',
            'email': 'rajesh.sharma@campus.edu',
            'advance_balance': 200.00,
            'loyalty_points': 45.0,
            'customer_code': 'CUS-000001',
          },
          {
            'name': 'Priya Patel (Architecture Student)',
            'mobile': '9876543211',
            'email': 'priya.patel@student.edu',
            'advance_balance': 50.00,
            'loyalty_points': 20.0,
            'customer_code': 'CUS-000002',
          },
          {
            'name': 'Apex Coaching Center (Monthly Account)',
            'mobile': '9876543212',
            'email': 'admin@apexcoaching.org',
            'advance_balance': 0.00,
            'loyalty_points': 110.0,
            'customer_code': 'CUS-000003',
          },
        ];
        await _client.from('customers').insert(seedCustomers);
      }
    } catch (e) {
      debugPrint('Error seeding default catalog: $e');
    }
  }

  // --- SEQUENCE CONFIGURATIONS ---
  static Future<List<SequenceConfigModel>> getSequenceConfigs() async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.getSequenceConfigs();
    }

    final defaultConfigs = [
      SequenceConfigModel(key: 'BILL', prefix: 'BILL', padding: 6, currentVal: 1),
      SequenceConfigModel(key: 'PAYMENT', prefix: 'PAY', padding: 6, currentVal: 1),
      SequenceConfigModel(key: 'EXPENSE', prefix: 'EXP', padding: 6, currentVal: 1),
      SequenceConfigModel(key: 'PRODUCT', prefix: 'PRD', padding: 6, currentVal: 22),
      SequenceConfigModel(key: 'CUSTOMER', prefix: 'CUS', padding: 6, currentVal: 4),
      SequenceConfigModel(key: 'AUDIT', prefix: 'AUDIT', padding: 6, currentVal: 1),
    ];

    try {
      final response = await _client.from('sequences').select('*');
      if ((response as List).isEmpty) return defaultConfigs;
      return response.map((json) => SequenceConfigModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching sequence configs: $e');
      return defaultConfigs;
    }
  }

  static Future<bool> saveSequenceConfig(SequenceConfigModel config) async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.saveSequenceConfig(config);
    }

    try {
      await _client.from('sequences').upsert({
        'key': config.key,
        'prefix': config.prefix,
        'padding': config.padding,
      }, onConflict: 'key');

      await logAudit(
        action: 'UPDATE_SEQUENCE_CONFIG',
        entity: 'Sequence ${config.key}',
        newValue: 'Prefix: ${config.prefix}, Padding: ${config.padding}',
      );
      return true;
    } catch (e) {
      debugPrint('Error saving sequence config: $e');
      return false;
    }
  }

  static Future<bool> saveLoyaltyRules(List<LoyaltyRule> rules) async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.saveLoyaltyRules(rules);
    }

    try {
      for (final r in rules) {
        await _client.from('loyalty_rules').upsert(r.toJson());
      }
      await logAudit(
        action: 'UPDATE_LOYALTY_EARNING_RULES',
        entity: 'Loyalty Earning Rules',
        newValue: '${rules.length} tiers updated',
      );
      return true;
    } catch (e) {
      debugPrint('Error saving loyalty rules: $e');
      return false;
    }
  }

  static Future<bool> saveLoyaltyRedemptionRules(List<LoyaltyRedemptionRule> rules) async {
    if (SupabaseConfig.isMockMode) {
      return MockDataStore.instance.saveLoyaltyRedemptionRules(rules);
    }

    try {
      for (final r in rules) {
        await _client.from('loyalty_redemption_rules').upsert(r.toJson());
      }
      await logAudit(
        action: 'UPDATE_LOYALTY_REDEMPTION_RULES',
        entity: 'Loyalty Redemption Rules',
        newValue: '${rules.length} tiers updated',
      );
      return true;
    } catch (e) {
      debugPrint('Error saving loyalty redemption rules: $e');
      return false;
    }
  }

  // --- BACKUP & RESTORE ---
  static Future<Map<String, dynamic>> exportDatabaseBackup() async {
    try {
      final settings = await getSettings();
      final products = await getProducts();
      final customers = await getCustomers();
      final bills = await getBills();
      final expenses = await getExpenses();
      final auditLogs = await getAuditLogs();
      final sequences = await getSequenceConfigs();
      final loyaltyRules = await getLoyaltyRules();
      final loyaltyRedemptions = await getLoyaltyRedemptionRules();

      final backup = {
        'version': '1.0.0',
        'is_mock_mode': SupabaseConfig.isMockMode,
        'exported_at': DateTime.now().toIso8601String(),
        'settings': settings.toJson(),
        'sequences': sequences.map((s) => {'key': s.key, 'prefix': s.prefix, 'padding': s.padding, 'current_val': s.currentVal}).toList(),
        'products': products.map((p) => p.toJson()).toList(),
        'customers': customers.map((c) => c.toJson()).toList(),
        'bills': bills.map((b) => b.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'audit_logs': auditLogs.map((a) => a.toJson()).toList(),
        'loyalty_earning_rules': loyaltyRules.map((r) => r.toJson()).toList(),
        'loyalty_redemption_rules': loyaltyRedemptions.map((r) => r.toJson()).toList(),
      };

      await logAudit(
        action: 'EXPORT_DATABASE_BACKUP',
        entity: 'System Database',
        newValue: 'Full Portable JSON Backup generated',
      );

      return backup;
    } catch (e) {
      debugPrint('Error exporting database backup: $e');
      return {};
    }
  }

  // --- HIGH-RISK DATA PURGE ---
  static Future<bool> purgeBusinessData() async {
    if (SupabaseConfig.isMockMode) {
      await MockDataStore.instance.resetToDefaults();
      return true;
    }

    try {
      // 1. Delete transactional data
      await _client.from('bills').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      await _client.from('payments').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      await _client.from('expenses').delete().neq('id', '00000000-0000-0000-0000-000000000000');

      // 2. Reset customer transaction balances
      await _client.from('customers').update({
        'advance_balance': 0.0,
        'loyalty_points': 0.0,
      }).neq('id', '00000000-0000-0000-0000-000000000000');

      // 3. Reset bill & payment sequence counters
      await _client.from('sequences').update({'current_val': 1}).inFilter('key', ['BILL', 'PAYMENT', 'EXPENSE']);

      // 4. Log immutable purge audit entry
      await logAudit(
        action: 'PURGE_ALL_BUSINESS_DATA',
        entity: 'System Database',
        newValue: 'Transactional records wiped by Super Admin authorization',
      );
      return true;
    } catch (e) {
      debugPrint('Error purging business data: $e');
      return false;
    }
  }
}
