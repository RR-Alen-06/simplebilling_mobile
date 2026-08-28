import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/network/supabase_client.dart';
import '../../core/utils/rounding_engine.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../models/bill_model.dart';
import '../models/expense_model.dart';
import '../models/audit_log_model.dart';
import '../models/settings_model.dart';
import '../models/dashboard_stats_model.dart';

class ApiRepository {
  ApiRepository._();

  static SupabaseClient get _client => SupabaseConfig.client;

  // ----------------------------------------------------
  // AUTH HELPER & CACHING SCOPE
  // ----------------------------------------------------
  static String? get currentUserId => _client.auth.currentUser?.id;
  static bool get isAuthenticated => _client.auth.currentUser != null;

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = currentUserId ?? 'guest';
    await prefs.remove('printpro-state:$uid');
    await _client.auth.signOut();
  }

  // ----------------------------------------------------
  // SETTINGS
  // ----------------------------------------------------
  static Future<AllSettings> getSettings() async {
    try {
      final response = await _client.from('settings').select().maybeSingle();
      if (response != null && response['value'] != null) {
        final val = response['value'];
        Map<String, dynamic> data = val is String ? jsonDecode(val) : Map<String, dynamic>.from(val);
        return AllSettings.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error loading settings from Supabase, checking cache: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final uid = currentUserId ?? 'default';
    final localJson = prefs.getString('printpro-state:$uid:settings');
    if (localJson != null) {
      try {
        return AllSettings.fromJson(jsonDecode(localJson));
      } catch (_) {}
    }

    return AllSettings(
      shop: ShopSettings(),
      billing: BillingSettings(),
      loyalty: LoyaltySettings(),
    );
  }

  static Future<void> saveSettings(AllSettings settings) async {
    final data = {
      'shop': settings.shop.toJson(),
      'billing': settings.billing.toJson(),
      'loyalty': settings.loyalty.toJson(),
    };
    try {
      await _client.from('settings').upsert({
        'key': 'ALL_SETTINGS',
        'value': data,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving settings to Supabase: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final uid = currentUserId ?? 'default';
    await prefs.setString('printpro-state:$uid:settings', jsonEncode(data));
  }

  // ----------------------------------------------------
  // CUSTOMERS
  // ----------------------------------------------------
  static Future<List<CustomerModel>> getCustomers() async {
    try {
      final response = await _client
          .from('customers')
          .select()
          .order('name', ascending: true);
      return (response as List).map((e) => CustomerModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error getting customers: $e');
      return [];
    }
  }

  static Future<CustomerModel?> createCustomer(String name, String mobile) async {
    try {
      final response = await _client.from('customers').insert({
        'name': name.trim(),
        'mobile': mobile.trim().isEmpty ? null : mobile.trim(),
        'advance_balance': 0.0,
        'loyalty_points': 0.0,
      }).select().single();
      return CustomerModel.fromJson(response);
    } catch (e) {
      debugPrint('Error creating customer: $e');
      return null;
    }
  }

  // ----------------------------------------------------
  // PRODUCTS & INVENTORY
  // ----------------------------------------------------
  static Future<List<ProductModel>> getProducts() async {
    try {
      final response = await _client
          .from('products')
          .select()
          .order('name', ascending: true);
      return (response as List).map((e) => ProductModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error getting products: $e');
      return [];
    }
  }

  static Future<ProductModel?> createProduct(String name, String category, double price) async {
    try {
      final response = await _client.from('products').insert({
        'name': name.trim(),
        'category': category.trim(),
        'price': price,
      }).select().single();
      return ProductModel.fromJson(response);
    } catch (e) {
      debugPrint('Error creating product: $e');
      return null;
    }
  }

  static Future<bool> deleteProduct(String productId) async {
    try {
      await _client.from('products').delete().eq('id', productId);
      return true;
    } catch (e) {
      debugPrint('Error deleting product: $e');
      return false;
    }
  }

  // ----------------------------------------------------
  // EXPENSES
  // ----------------------------------------------------
  static Future<List<ExpenseModel>> getExpenses() async {
    try {
      final response = await _client
          .from('expenses')
          .select()
          .order('created_at', ascending: false);
      return (response as List).map((e) => ExpenseModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error getting expenses: $e');
      return [];
    }
  }

  static Future<ExpenseModel?> createExpense(String title, double amount, String category) async {
    try {
      final response = await _client.from('expenses').insert({
        'title': title.trim(),
        'amount': amount,
        'category': category,
      }).select().single();
      return ExpenseModel.fromJson(response);
    } catch (e) {
      debugPrint('Error creating expense: $e');
      return null;
    }
  }

  static Future<bool> deleteExpense(String expenseId) async {
    try {
      await _client.from('expenses').delete().eq('id', expenseId);
      return true;
    } catch (e) {
      debugPrint('Error deleting expense: $e');
      return false;
    }
  }

  // ----------------------------------------------------
  // AUDIT LOGS
  // ----------------------------------------------------
  static Future<List<AuditLogModel>> getAuditLogs() async {
    try {
      final response = await _client
          .from('audit_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      return (response as List).map((e) => AuditLogModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error getting audit logs: $e');
      return [];
    }
  }

  static Future<void> logAudit({
    required String action,
    required String entity,
    String? previousValue,
    String? newValue,
    String userName = 'Admin',
  }) async {
    try {
      await _client.from('audit_logs').insert({
        'user_name': userName,
        'action': action,
        'entity': entity,
        'previous_value': previousValue,
        'new_value': newValue,
      });
    } catch (e) {
      debugPrint('Error writing audit log: $e');
    }
  }

  // ----------------------------------------------------
  // LOYALTY RULES
  // ----------------------------------------------------
  static Future<List<LoyaltyRedemptionRule>> getLoyaltyRedemptionRules() async {
    try {
      final response = await _client
          .from('loyalty_redemption_rules')
          .select()
          .eq('enabled', true)
          .order('points_required', ascending: true);
      return (response as List).map((e) => LoyaltyRedemptionRule.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error getting loyalty rules: $e');
      return [];
    }
  }

  // ----------------------------------------------------
  // BILLS
  // ----------------------------------------------------
  static Future<List<BillModel>> getBills() async {
    try {
      final response = await _client
          .from('bills')
          .select('*, customers(name, mobile), bill_items(*)')
          .order('created_at', ascending: false);
      return (response as List).map((e) => BillModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error getting bills: $e');
      return [];
    }
  }

  static Future<String> getNextBillNumber() async {
    try {
      final res = await _client.rpc('get_next_sequence', params: {'p_key': 'BILL'});
      if (res != null) return res.toString();
    } catch (e) {
      debugPrint('Error generating bill sequence from RPC: $e');
    }
    final rand = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    return 'BILL-$rand';
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
      final billNumber = await getNextBillNumber();
      final paidTotal = cashPaid + upiPaid + advanceUsed;

      final billData = {
        'bill_number': billNumber,
        'customer_id': customerId,
        'total': total,
        'discount': discount,
        'rounding_method': roundingMethod.toDisplayString(),
        'rounding_adjustment': roundingAdjustment,
        'grand_total': grandTotal,
        'cash_paid': cashPaid,
        'upi_paid': upiPaid,
        'paid_total': paidTotal,
        'advance_used': advanceUsed,
        'advance_earned': advanceEarned,
        'payment_method': paymentMethod,
        'loyalty_points_earned': loyaltyPointsEarned,
        'loyalty_points_redeemed': loyaltyPointsRedeemed,
      };

      final billRes = await _client.from('bills').insert(billData).select().single();
      final billId = billRes['id'] as String;

      if (items.isNotEmpty) {
        final itemsPayload = items.map((it) => {
          'bill_id': billId,
          'product_id': it.productId,
          'product_name': it.productName,
          'quantity': it.quantity,
          'price': it.price,
          'total': it.total,
        }).toList();

        await _client.from('bill_items').insert(itemsPayload);
      }

      if (customerId != null) {
        final custRes = await _client.from('customers').select().eq('id', customerId).single();
        final currentAdv = (custRes['advance_balance'] as num?)?.toDouble() ?? 0.0;
        final currentLoyalty = (custRes['loyalty_points'] as num?)?.toDouble() ?? 0.0;

        final newAdv = (currentAdv - advanceUsed + advanceEarned).clamp(0.0, double.infinity);
        final newLoyalty = (currentLoyalty - loyaltyPointsRedeemed + loyaltyPointsEarned).clamp(0.0, double.infinity);

        await _client.from('customers').update({
          'advance_balance': newAdv,
          'loyalty_points': newLoyalty,
        }).eq('id', customerId);
      }

      final fullBillRes = await _client
          .from('bills')
          .select('*, customers(name, mobile), bill_items(*)')
          .eq('id', billId)
          .single();

      return BillModel.fromJson(fullBillRes);
    } catch (e) {
      debugPrint('Error creating bill: $e');
      return null;
    }
  }

  // ----------------------------------------------------
  // DASHBOARD STATS
  // ----------------------------------------------------
  static Future<DashboardStatsModel> getDashboardStats() async {
    try {
      final bills = await getBills();
      final expenses = await getExpenses();
      final customers = await getCustomers();

      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final currentMonthStr = todayStr.substring(0, 7);

      double todaysSales = 0;
      int todaysBillsCount = 0;
      double monthlySales = 0;
      double totalIncome = 0;
      double pendingBalance = 0;

      for (final b in bills) {
        totalIncome += b.grandTotal;
        if (b.createdAt.startsWith(todayStr)) {
          todaysSales += b.grandTotal;
          todaysBillsCount++;
        }
        if (b.createdAt.startsWith(currentMonthStr)) {
          monthlySales += b.grandTotal;
        }
        final due = (b.grandTotal - b.paidTotal).clamp(0.0, double.infinity);
        pendingBalance += due;
      }

      final totalExpense = expenses.fold(0.0, (sum, e) => sum + e.amount);
      final netProfit = totalIncome - totalExpense;
      final avgBill = bills.isNotEmpty ? totalIncome / bills.length : 0.0;

      return DashboardStatsModel(
        todaysSales: todaysSales,
        monthlySales: monthlySales,
        todaysBillsCount: todaysBillsCount,
        pendingBalance: pendingBalance,
        totalCustomers: customers.length,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        netProfit: netProfit,
        billsGenerated: bills.length,
        averageBillValue: avgBill,
      );
    } catch (e) {
      debugPrint('Error calculating dashboard stats: $e');
      return DashboardStatsModel.empty();
    }
  }
}
