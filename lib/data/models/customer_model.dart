class CustomerModel {
  final String id;
  final String? userId;
  final String? customerCode;
  final String name;
  final String? mobile;
  final String? email;
  final double advanceBalance;
  final double loyaltyPoints;
  final String? createdAt;
  final String? clientRef;

  // Extended summary/dues fields for ledger
  final double totalBilled;
  final double totalPaid;
  final double balanceDue;

  CustomerModel({
    required this.id,
    this.userId,
    this.customerCode,
    required this.name,
    this.mobile,
    this.email,
    this.advanceBalance = 0.0,
    this.loyaltyPoints = 0.0,
    this.createdAt,
    this.clientRef,
    this.totalBilled = 0.0,
    this.totalPaid = 0.0,
    this.balanceDue = 0.0,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    final billed = (json['total_billed'] as num?)?.toDouble() ?? 0.0;
    final paid = (json['total_paid'] as num?)?.toDouble() ?? 0.0;
    final advance = (json['advance_balance'] as num?)?.toDouble() ?? 0.0;
    final due = (json['balance_due'] as num?)?.toDouble() ?? (billed - paid - advance > 0 ? billed - paid - advance : 0.0);

    return CustomerModel(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      customerCode: json['customer_code'] as String?,
      name: json['name'] as String? ?? 'Customer',
      mobile: json['mobile'] as String?,
      email: json['email'] as String?,
      advanceBalance: advance,
      loyaltyPoints: (json['loyalty_points'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] as String?,
      clientRef: json['client_ref'] as String?,
      totalBilled: billed,
      totalPaid: paid,
      balanceDue: due,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      if (customerCode != null) 'customer_code': customerCode,
      'name': name,
      if (mobile != null) 'mobile': mobile,
      if (email != null) 'email': email,
      'advance_balance': advanceBalance,
      'loyalty_points': loyaltyPoints,
      if (createdAt != null) 'created_at': createdAt,
      if (clientRef != null) 'client_ref': clientRef,
    };
  }

  CustomerModel copyWith({
    String? id,
    String? userId,
    String? customerCode,
    String? name,
    String? mobile,
    String? email,
    double? advanceBalance,
    double? loyaltyPoints,
    String? createdAt,
    String? clientRef,
    double? totalBilled,
    double? totalPaid,
    double? balanceDue,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      customerCode: customerCode ?? this.customerCode,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      advanceBalance: advanceBalance ?? this.advanceBalance,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      createdAt: createdAt ?? this.createdAt,
      clientRef: clientRef ?? this.clientRef,
      totalBilled: totalBilled ?? this.totalBilled,
      totalPaid: totalPaid ?? this.totalPaid,
      balanceDue: balanceDue ?? this.balanceDue,
    );
  }
}
