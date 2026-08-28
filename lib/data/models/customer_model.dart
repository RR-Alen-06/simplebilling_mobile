class CustomerModel {
  final String id;
  final String? userId;
  final String? customerCode;
  final String name;
  final String? mobile;
  final double advanceBalance;
  final double loyaltyPoints;
  final String? createdAt;

  CustomerModel({
    required this.id,
    this.userId,
    this.customerCode,
    required this.name,
    this.mobile,
    this.advanceBalance = 0.0,
    this.loyaltyPoints = 0.0,
    this.createdAt,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      customerCode: json['customer_code'] as String?,
      name: json['name'] as String? ?? 'Customer',
      mobile: json['mobile'] as String?,
      advanceBalance: (json['advance_balance'] as num?)?.toDouble() ?? 0.0,
      loyaltyPoints: (json['loyalty_points'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      if (customerCode != null) 'customer_code': customerCode,
      'name': name,
      if (mobile != null) 'mobile': mobile,
      'advance_balance': advanceBalance,
      'loyalty_points': loyaltyPoints,
      if (createdAt != null) 'created_at': createdAt,
    };
  }
}
