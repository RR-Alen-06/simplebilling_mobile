class ExpenseModel {
  final String id;
  final String? userId;
  final String? expenseNumber;
  final String title;
  final double amount;
  final String category;
  final String createdAt;
  final String? clientRef;

  ExpenseModel({
    required this.id,
    this.userId,
    this.expenseNumber,
    required this.title,
    required this.amount,
    this.category = 'Shop Expense',
    required this.createdAt,
    this.clientRef,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      expenseNumber: json['expense_number'] as String?,
      title: json['title'] as String? ?? 'Expense',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? 'Shop Expense',
      createdAt: json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      clientRef: json['client_ref'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'title': title,
      'amount': amount,
      'category': category,
      'created_at': createdAt,
      if (clientRef != null) 'client_ref': clientRef,
    };
  }
}