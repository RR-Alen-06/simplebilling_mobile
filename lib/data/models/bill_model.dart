class BillModel {
  final String id;
  final String? userId;
  final String billNumber;
  final String? customerId;
  final String? customerName;
  final String? customerMobile;
  final double total;
  final double discount;
  final String roundingMethod;
  final double roundingAdjustment;
  final double grandTotal;
  final double cashPaid;
  final double upiPaid;
  final double paidTotal;
  final double advanceUsed;
  final double advanceEarned;
  final String paymentMethod;
  final double loyaltyPointsEarned;
  final double loyaltyPointsRedeemed;
  final String createdAt;
  final String? clientRef;
  final List<BillItemModel> items;

  BillModel({
    required this.id,
    this.userId,
    required this.billNumber,
    this.customerId,
    this.customerName,
    this.customerMobile,
    required this.total,
    required this.discount,
    required this.roundingMethod,
    required this.roundingAdjustment,
    required this.grandTotal,
    required this.cashPaid,
    required this.upiPaid,
    required this.paidTotal,
    this.advanceUsed = 0.0,
    this.advanceEarned = 0.0,
    required this.paymentMethod,
    this.loyaltyPointsEarned = 0.0,
    this.loyaltyPointsRedeemed = 0.0,
    required this.createdAt,
    this.clientRef,
    required this.items,
  });

  factory BillModel.fromJson(Map<String, dynamic> json, [List<BillItemModel> items = const []]) {
    return BillModel(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      billNumber: json['bill_number'] as String,
      customerId: json['customer_id'] as String?,
      customerName: json['customers'] != null ? json['customers']['name'] as String? : null,
      customerMobile: json['customers'] != null ? json['customers']['mobile'] as String? : null,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      roundingMethod: json['rounding_method'] as String? ?? 'none',
      roundingAdjustment: (json['rounding_adjustment'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (json['grand_total'] as num?)?.toDouble() ?? 0.0,
      cashPaid: (json['cash_paid'] as num?)?.toDouble() ?? 0.0,
      upiPaid: (json['upi_paid'] as num?)?.toDouble() ?? 0.0,
      paidTotal: (json['paid_total'] as num?)?.toDouble() ?? 0.0,
      advanceUsed: (json['advance_used'] as num?)?.toDouble() ?? 0.0,
      advanceEarned: (json['advance_earned'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String? ?? 'Cash',
      loyaltyPointsEarned: (json['loyalty_points_earned'] as num?)?.toDouble() ?? 0.0,
      loyaltyPointsRedeemed: (json['loyalty_points_redeemed'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      clientRef: json['client_ref'] as String?,
      items: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'bill_number': billNumber,
      if (customerId != null) 'customer_id': customerId,
      'total': total,
      'discount': discount,
      'rounding_method': roundingMethod,
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
      'created_at': createdAt,
      if (clientRef != null) 'client_ref': clientRef,
    };
  }
}

class BillItemModel {
  final String? id;
  final String? billId;
  final String? productId;
  final String productName;
  final double quantity;
  final double price;
  final double total;

  BillItemModel({
    this.id,
    this.billId,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.total,
  });

  factory BillItemModel.fromJson(Map<String, dynamic> json) {
    return BillItemModel(
      id: json['id'] as String?,
      billId: json['bill_id'] as String?,
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String? ?? 'Item',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (billId != null) 'bill_id': billId,
      if (productId != null) 'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'total': total,
    };
  }
}