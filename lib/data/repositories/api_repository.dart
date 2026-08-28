import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simplebilling_mobile/core/network/supabase_client.dart';
import 'package:simplebilling_mobile/core/utils/rounding_engine.dart';
import 'package:simplebilling_mobile/data/models/audit_log_model.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
import 'package:simplebilling_mobile/data/models/dashboard_stats_model.dart';
import 'package:simplebilling_mobile/data/models/expense_model.dart';
import 'package:simplebilling_mobile/data/models/product_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';

class ApiRepository {
  static final _client = SupabaseConfig.client;

  static String _getUserKey(String baseKey) {
    final uid = _client.auth.currentUser?.id ?? 'guest';
    return 'printpro-state:' + uid + ':' + baseKey;
  }

  // --- AUTHENTICATION ---
  static Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final uid = _client.auth.currentUser?.id;
      if (uid != null) {
        for (final k in keys) {
          if (k.startsWith('printpro-state:' + uid)) {
            await prefs.remove(k);
          }
        }
      }
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: ');
    }
  }

  // --- CUSTOMERS ---
  static Future<List<CustomerModel>> getCustomers() async {
    try {
      final response = await _client.from('customers').select('*').order('created_at', ascending: false);
      return (response as List).map((json) => CustomerModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching customers: ');
      return [];
    }
  }

  static Future<CustomerModel?> createCustomer(String name, String? mobile, {double initialAdvance = 0.0}) async {
    try {
      final response = await _client.from('customers').insert({
        'name': name,
        'mobile': mobile,
        'advance_balance': initialAdvance,
        'loyalty_points': 0,
      }).select().single();

      await logAudit(action: 'CREATE_CUSTOMER', entity: 'Customer ', newValue: 'Advance: ');
      return CustomerModel.fromJson(response);
    } catch (e) {
      debugPrint('Error creating customer: ');
      return null;
    }
  }

  // --- PRODUCTS ---
  static Future<List<ProductModel>> getProducts() async {
    try {
      final response = await _client.from('products').select('*').order('name', ascending: true);
      return (response as List).map((json) => ProductModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching products: ');
      return [];
    }
  }

  static Future<ProductModel?> createProduct(String name, String category, double price) async {
    try {
      final response = await _client.from('products').insert({
        'name': name,
        'category': category,
        'price': price,
      }).select().single();

      await logAudit(action: 'CREATE_PRODUCT', entity: 'Product ', newValue: 'Price: ');
      return ProductModel.fromJson(response);
    } catch (e) {
      debugPrint('Error creating product: ');
      return null;
    }
  }

  static Future<bool> deleteProduct(String id) async {
    try {
      await _client.from('products').delete().eq('id', id);
      await logAudit(action: 'DELETE_PRODUCT', entity: 'Product ID ');
      return true;
    } catch (e) {
      debugPrint('Error deleting product: ');
      return false;
    }
  }

  // --- EXPENSES ---
  static Future<List<ExpenseModel>> getExpenses() async {
    try {
      final response = await _client.from('expenses').select('*').order('created_at', ascending: false);
      return (response as List).map((json) => ExpenseModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching expenses: ');
      return [];
    }
  }

  static Future<ExpenseModel?> createExpense(String title, double amount, String category) async {
    try {
      final response = await _client.from('expenses').insert({
        'title': title,
        'amount': amount,
        'category': category,
      }).select().single();

      await logAudit(action: 'CREATE_EXPENSE', entity: title, newValue: 'Amount: ');
      return ExpenseModel.fromJson(response);
    } catch (e) {
      debugPrint('Error creating expense: ');
      return null;
    }
  }

  static Future<bool> deleteExpense(String id) async {
    try {
      await _client.from('expenses').delete().eq('id', id);
      await logAudit(action: 'DELETE_EXPENSE', entity: 'Expense ID ');
      return true;
    } catch (e) {
      debugPrint('Error deleting expense: ');
      return false;
    }
  }

  // --- AUDIT LOGS ---
  static Future<List<AuditLogModel>> getAuditLogs() async {
    try {
      final response = await _client.from('audit_logs').select('*').order('created_at', ascending: false).limit(100);
      return (response as List).map((json) => AuditLogModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching audit logs: ');
      return [];
    }
  }

  static Future<void> logAudit({required String action, required String entity, String? newValue}) async {
    try {
      final user = _client.auth.currentUser;
      await _client.from('audit_logs').insert({
        'user_name': user?.email ?? 'Mobile App User',
        'action': action,
        'entity': entity,
        'new_value': newValue,
      });
    } catch (e) {
      debugPrint('Audit logging failed: ');
    }
  }

  // --- LOYALTY RULES ---
  static Future<List<LoyaltyRedemptionRule>> getLoyaltyRedemptionRules() async {
    try {
      final response = await _client.from('loyalty_redemption_rules').select('*').order('points_required', ascending: true);
      return (response as List).map((json) => LoyaltyRedemptionRule.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching loyalty rules: ');
      return [];
    }
  }

  // --- SETTINGS ---
  static Future<AllSettings> getSettings() async {
    final defaultSettings = AllSettings(
      shop: ShopSettings(shopName: 'PrintPro Shop', phone: '9876543210', address: 'Main Street'),
      billing: BillingSettings(),
      loyalty: LoyaltySettings(),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_getUserKey('settings'));
      if (cached != null) {
        return AllSettings.fromJson(jsonDecode(cached));
      }

      final response = await _client.from('settings').select('*').limit(1).maybeSingle();
      if (response != null && response['value'] != null) {
        final settings = AllSettings.fromJson(response['value']);
        await prefs.setString(_getUserKey('settings'), jsonEncode(settings.toJson()));
        return settings;
      }
    } catch (e) {
      debugPrint('Error fetching settings: ');
    }

    return defaultSettings;
  }

  static Future<void> saveSettings(AllSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_getUserKey('settings'), jsonEncode(settings.toJson()));

      final existing = await _client.from('settings').select('id').limit(1).maybeSingle();
      if (existing != null) {
        await _client.from('settings').update({'value': settings.toJson()}).eq('id', existing['id']);
      } else {
        await _client.from('settings').insert({'value': settings.toJson()});
      }

      await logAudit(action: 'UPDATE_SETTINGS', entity: 'Shop Settings');
    } catch (e) {
      debugPrint('Error saving settings: ');
    }
  }

  static Future<String> generateBillNumber() async {
    return _generateBillNumber();
  }

  static double calculateLoyaltyDiscount(double pointsToRedeem, LoyaltySettings loyaltySettings, List<LoyaltyRedemptionRule> activeRedemptionRules) {
    if (pointsToRedeem <= 0) return 0.0;
    final enabledRules = activeRedemptionRules.where((r) => r.enabled).toList()
      ..sort((a, b) => b.pointsRequired.compareTo(a.pointsRequired));

    if (enabledRules.isNotEmpty) {
      double remainingPts = pointsToRedeem;
      double totalDiscount = 0.0;

      for (final rule in enabledRules) {
        if (remainingPts >= rule.pointsRequired) {
          final multiplier = (remainingPts / rule.pointsRequired).floor();
          totalDiscount += multiplier * rule.discountAmount;
          remainingPts -= multiplier * rule.pointsRequired;
        }
      }
      if (totalDiscount > 0) return double.parse(totalDiscount.toStringAsFixed(2));
      final bestRule = enabledRules.first;
      final rate = bestRule.discountAmount / bestRule.pointsRequired;
      return double.parse((pointsToRedeem * rate).toStringAsFixed(2));
    }

    final req = loyaltySettings.pointsRequired > 0 ? loyaltySettings.pointsRequired : 10.0;
    final disc = loyaltySettings.discountValue > 0 ? loyaltySettings.discountValue : 5.0;
    final ratePerPoint = disc / req;
    return double.parse((pointsToRedeem * ratePerPoint).toStringAsFixed(2));
  }

  // --- BILLS & POS TRANSACTION ENGINE ---
  static Future<String> _generateBillNumber() async {
    final now = DateTime.now();
    final year = now.year.toString().substring(2);
    final month = now.month.toString().padLeft(2, '0');
    final randomSuffix = (1000 + (now.microsecond % 9000)).toString();
    return 'BILL-' + year + month + '-' + randomSuffix;
  }

  static Future<List<BillModel>> getBills() async {
    try {
      final billsData = await _client.from('bills').select('*, customer:customers(name, mobile), items:bill_items(*)').order('created_at', ascending: false);
      return (billsData as List).map((json) {
        final cust = json['customer'] as Map<String, dynamic>?;
        return BillModel.fromJson({
          ...json,
          'customer_name': cust?['name'],
          'customer_phone': cust?['mobile'],
        });
      }).toList();
    } catch (e) {
      debugPrint('Error fetching bills: ');
      return [];
    }
  }

  static Future<String> syncBillPayload(Map<String, dynamic> payload) async {
    final billData = Map<String, dynamic>.from(payload['billData']);
    final itemsPayload = List<Map<String, dynamic>>.from(payload['itemsPayload']);

    final billRes = await _client.from('bills').insert(billData).select().single();
    final newBillId = billRes['id'] as String;

    if (itemsPayload.isNotEmpty) {
      for (final item in itemsPayload) {
        item['bill_id'] = newBillId;
      }
      await _client.from('bill_items').insert(itemsPayload);
    }
    return newBillId;
  }

  static Future<BillModel?> createBill({
    required String? customerId,
    required double total,
    required double discount,
    required RoundingMethod roundingMethod,
    required double roundingAdjustment,
    required double grandTotal,
    required double cashPaid,
    required double upiPaid,
    required double advanceUsed,
    required double advanceEarned,
    required String paymentMethod,
    required double loyaltyPointsEarned,
    required double loyaltyPointsRedeemed,
    required List<BillItemModel> items,
  }) async {
    try {
      final billNumber = await _generateBillNumber();
      final billData = {
        'bill_number': billNumber,
        'customer_id': customerId,
        'total': total,
        'discount': discount,
        'rounding_method': roundingMethod.name,
        'rounding_adjustment': roundingAdjustment,
        'grand_total': grandTotal,
        'cash_paid': cashPaid,
        'upi_paid': upiPaid,
        'paid_total': cashPaid + upiPaid,
        'advance_used': advanceUsed,
        'advance_earned': advanceEarned,
        'payment_method': paymentMethod,
        'loyalty_points_earned': loyaltyPointsEarned,
        'loyalty_points_redeemed': loyaltyPointsRedeemed,
      };

      final itemsPayload = items.map((item) => {
        'product_id': item.productId,
        'product_name': item.productName,
        'quantity': item.quantity,
        'price': item.price,
        'total': item.total,
      }).toList();

      final createdBillId = await syncBillPayload({
        'billData': billData,
        'itemsPayload': itemsPayload,
      });

      // Advance / Loyalty Updates
      if (customerId != null) {
        final customerRes = await _client.from('customers').select('advance_balance, loyalty_points').eq('id', customerId).single();
        final currentAdvance = (customerRes['advance_balance'] as num?)?.toDouble() ?? 0.0;
        final currentLoyalty = (customerRes['loyalty_points'] as num?)?.toDouble() ?? 0.0;

        final newAdvance = (currentAdvance - advanceUsed + advanceEarned).clamp(0.0, double.infinity);
        final newLoyalty = (currentLoyalty - loyaltyPointsRedeemed + loyaltyPointsEarned).clamp(0.0, double.infinity);

        await _client.from('customers').update({
          'advance_balance': newAdvance,
          'loyalty_points': newLoyalty,
        }).eq('id', customerId);
      }

      await logAudit(action: 'CREATE_BILL', entity: billNumber, newValue: 'Grand Total: ');

      return BillModel(
        id: createdBillId,
        billNumber: billNumber,
        customerId: customerId,
        total: total,
        discount: discount,
        roundingMethod: roundingMethod.name,
        roundingAdjustment: roundingAdjustment,
        grandTotal: grandTotal,
        cashPaid: cashPaid,
        upiPaid: upiPaid,
        paidTotal: cashPaid + upiPaid,
        advanceUsed: advanceUsed,
        advanceEarned: advanceEarned,
        paymentMethod: paymentMethod,
        loyaltyPointsEarned: loyaltyPointsEarned,
        loyaltyPointsRedeemed: loyaltyPointsRedeemed,
        createdAt: DateTime.now().toIso8601String(),
        items: items,
      );
    } catch (e) {
      debugPrint('Error creating bill: ');
      return null;
    }
  }

  // --- DASHBOARD AGGREGATION ---
  static Future<DashboardStatsModel> getDashboardStats() async {
    try {
      final bills = await getBills();
      final expenses = await getExpenses();
      final customers = await getCustomers();

      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final monthStr = todayStr.substring(0, 7);

      double todaySales = 0;
      double monthSales = 0;
      double totalIncome = 0;
      double pendingBalances = 0;
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

      double totalExpenses = expenses.fold(0.0, (sum, e) => sum + e.amount);
      double averageBillValue = bills.isNotEmpty ? (totalIncome / bills.length) : 0.0;

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
      debugPrint('Error loading dashboard stats: ');
      return DashboardStatsModel.empty();
    }
  }
}