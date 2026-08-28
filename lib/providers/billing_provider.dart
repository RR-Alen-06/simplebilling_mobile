import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/customer_model.dart';
import '../data/models/product_model.dart';
import '../data/models/bill_model.dart';
import '../data/models/settings_model.dart';
import '../data/repositories/api_repository.dart';
import '../core/utils/rounding_engine.dart';

final settingsProvider = FutureProvider<AllSettings>((ref) async {
  return await ApiRepository.getSettings();
});

final customersProvider = FutureProvider<List<CustomerModel>>((ref) async {
  return await ApiRepository.getCustomers();
});

final productsProvider = FutureProvider<List<ProductModel>>((ref) async {
  return await ApiRepository.getProducts();
});

final loyaltyRulesProvider = FutureProvider<List<LoyaltyRedemptionRule>>((ref) async {
  return await ApiRepository.getLoyaltyRedemptionRules();
});

final billsListProvider = FutureProvider<List<BillModel>>((ref) async {
  return await ApiRepository.getBills();
});

// POS Cart State
class CartState {
  final List<BillItemModel> items;
  final CustomerModel? selectedCustomer;
  final String discountType; // 'FLAT' or 'PERCENTAGE'
  final double discountValue;
  final RoundingMethod roundingMethod;
  final double cashPaid;
  final double upiPaid;
  final bool useAdvance;
  final double advanceUsed;
  final double pointsToRedeem;

  CartState({
    this.items = const [],
    this.selectedCustomer,
    this.discountType = 'FLAT',
    this.discountValue = 0.0,
    this.roundingMethod = RoundingMethod.none,
    this.cashPaid = 0.0,
    this.upiPaid = 0.0,
    this.useAdvance = false,
    this.advanceUsed = 0.0,
    this.pointsToRedeem = 0.0,
  });

  double get subtotal => items.fold(0.0, (sum, it) => sum + it.total);

  double get manualDiscount {
    if (discountType == 'PERCENTAGE') {
      return double.parse(((subtotal * discountValue) / 100).toStringAsFixed(2));
    }
    return discountValue;
  }

  double calculateLoyaltyDiscount(LoyaltySettings settings, List<LoyaltyRedemptionRule> rules) {
    if (!settings.enabled || pointsToRedeem <= 0) return 0.0;
    for (final rule in rules) {
      if (rule.enabled && pointsToRedeem >= rule.pointsRequired) {
        return rule.discountAmount;
      }
    }
    if (settings.pointsRequired > 0) {
      final tiers = (pointsToRedeem / settings.pointsRequired).floor();
      return tiers * settings.discountValue;
    }
    return 0.0;
  }

  RoundingResult getRoundingResult(double loyaltyDiscount) {
    final totalAfterDiscount = (subtotal - manualDiscount - loyaltyDiscount).clamp(0.0, double.infinity);
    return RoundingEngine.calculate(totalAfterDiscount, roundingMethod);
  }

  CartState copyWith({
    List<BillItemModel>? items,
    CustomerModel? selectedCustomer,
    bool clearCustomer = false,
    String? discountType,
    double? discountValue,
    RoundingMethod? roundingMethod,
    double? cashPaid,
    double? upiPaid,
    bool? useAdvance,
    double? advanceUsed,
    double? pointsToRedeem,
  }) {
    return CartState(
      items: items ?? this.items,
      selectedCustomer: clearCustomer ? null : (selectedCustomer ?? this.selectedCustomer),
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      roundingMethod: roundingMethod ?? this.roundingMethod,
      cashPaid: cashPaid ?? this.cashPaid,
      upiPaid: upiPaid ?? this.upiPaid,
      useAdvance: useAdvance ?? this.useAdvance,
      advanceUsed: advanceUsed ?? this.advanceUsed,
      pointsToRedeem: pointsToRedeem ?? this.pointsToRedeem,
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState());

  void addItem(String productName, double price, double quantity, {String? productId}) {
    final existingIndex = state.items.indexWhere((it) => it.productName == productName && it.price == price);
    if (existingIndex >= 0) {
      final updatedList = List<BillItemModel>.from(state.items);
      final current = updatedList[existingIndex];
      final newQty = current.quantity + quantity;
      updatedList[existingIndex] = BillItemModel(
        productId: current.productId,
        productName: current.productName,
        quantity: newQty,
        price: current.price,
        total: double.parse((newQty * current.price).toStringAsFixed(2)),
      );
      state = state.copyWith(items: updatedList);
    } else {
      final newItem = BillItemModel(
        productId: productId,
        productName: productName,
        quantity: quantity,
        price: price,
        total: double.parse((quantity * price).toStringAsFixed(2)),
      );
      state = state.copyWith(items: [...state.items, newItem]);
    }
  }

  void updateItemQuantity(int index, double quantity) {
    if (quantity <= 0) {
      removeItem(index);
      return;
    }
    final updatedList = List<BillItemModel>.from(state.items);
    final it = updatedList[index];
    updatedList[index] = BillItemModel(
      productId: it.productId,
      productName: it.productName,
      quantity: quantity,
      price: it.price,
      total: double.parse((quantity * it.price).toStringAsFixed(2)),
    );
    state = state.copyWith(items: updatedList);
  }

  void removeItem(int index) {
    final updatedList = List<BillItemModel>.from(state.items)..removeAt(index);
    state = state.copyWith(items: updatedList);
  }

  void selectCustomer(CustomerModel? customer) {
    if (customer == null) {
      state = state.copyWith(clearCustomer: true, useAdvance: false, advanceUsed: 0.0);
    } else {
      state = state.copyWith(
        selectedCustomer: customer,
        useAdvance: customer.advanceBalance > 0,
        advanceUsed: customer.advanceBalance > 0 ? customer.advanceBalance : 0.0,
      );
    }
  }

  void setDiscount(String type, double value) {
    state = state.copyWith(discountType: type, discountValue: value);
  }

  void setRoundingMethod(RoundingMethod method) {
    state = state.copyWith(roundingMethod: method);
  }

  void setPayments({double? cash, double? upi, bool? useAdv, double? advUsed, double? loyaltyRedeem}) {
    state = state.copyWith(
      cashPaid: cash ?? state.cashPaid,
      upiPaid: upi ?? state.upiPaid,
      useAdvance: useAdv ?? state.useAdvance,
      advanceUsed: advUsed ?? state.advanceUsed,
      pointsToRedeem: loyaltyRedeem ?? state.pointsToRedeem,
    );
  }

  void reset() {
    state = CartState();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});
