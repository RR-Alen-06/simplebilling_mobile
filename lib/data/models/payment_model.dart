class PaymentModel {
  final String id;
  final String? paymentNumber;
  final String customerId;
  final String? customerName;
  final String? customerMobile;
  final String? billId;
  final double amount;
  final String paymentMethod;
  final String? notes;
  final String createdAt;

  PaymentModel({
    required this.id,
    this.paymentNumber,
    required this.customerId,
    this.customerName,
    this.customerMobile,
    this.billId,
    required this.amount,
    required this.paymentMethod,
    this.notes,
    required this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String? ?? '',
      paymentNumber: json['payment_number'] as String?,
      customerId: json['customer_id'] as String? ?? '',
      customerName: json['customer_name'] as String?,
      customerMobile: json['customer_mobile'] as String?,
      billId: json['bill_id'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String? ?? 'Cash',
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payment_number': paymentNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_mobile': customerMobile,
      'bill_id': billId,
      'amount': amount,
      'payment_method': paymentMethod,
      'notes': notes,
      'created_at': createdAt,
    };
  }
}

class CustomerLedgerEntryModel {
  final String id;
  final String date;
  final String type; // 'BILL' | 'PAYMENT' | 'ADVANCE_USED' | 'LOYALTY_REDEEM'
  final String referenceNo;
  final String description;
  final double billAmount;
  final double paidAmount;
  final double advanceUsed;
  final double loyaltyPoints;
  final double runningBalance;

  CustomerLedgerEntryModel({
    required this.id,
    required this.date,
    required this.type,
    required this.referenceNo,
    required this.description,
    required this.billAmount,
    required this.paidAmount,
    required this.advanceUsed,
    required this.loyaltyPoints,
    required this.runningBalance,
  });

  factory CustomerLedgerEntryModel.fromJson(Map<String, dynamic> json) {
    return CustomerLedgerEntryModel(
      id: json['id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      type: json['type'] as String? ?? 'BILL',
      referenceNo: json['reference_no'] as String? ?? '',
      description: json['description'] as String? ?? '',
      billAmount: (json['bill_amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      advanceUsed: (json['advance_used'] as num?)?.toDouble() ?? 0.0,
      loyaltyPoints: (json['loyalty_points'] as num?)?.toDouble() ?? 0.0,
      runningBalance: (json['running_balance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'type': type,
      'reference_no': referenceNo,
      'description': description,
      'bill_amount': billAmount,
      'paid_amount': paidAmount,
      'advance_used': advanceUsed,
      'loyalty_points': loyaltyPoints,
      'running_balance': runningBalance,
    };
  }
}
