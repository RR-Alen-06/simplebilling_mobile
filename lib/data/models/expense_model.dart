class ExpenseModel {
  final String id;
  final String? userId;
  final String? expenseNumber;
  final String title;
  final double amount;
  final String category;
  final String paymentMode;
  final String? notes;
  final String date;
  final String? clientRef;

  ExpenseModel({
    required this.id,
    this.userId,
    this.expenseNumber,
    required this.title,
    required this.amount,
    this.category = 'Shop Expense',
    this.paymentMode = 'Cash',
    this.notes,
    required this.date,
    this.clientRef,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String? ?? 'exp_${DateTime.now().millisecondsSinceEpoch}',
      userId: json['user_id'] as String?,
      expenseNumber: json['expense_number'] as String?,
      title: json['title'] as String? ?? 'Expense',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? 'Shop Expense',
      paymentMode: json['payment_mode'] as String? ?? 'Cash',
      notes: json['notes'] as String?,
      date: json['date'] as String? ?? json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      clientRef: json['client_ref'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      if (expenseNumber != null) 'expense_number': expenseNumber,
      'title': title,
      'amount': amount,
      'category': category,
      'payment_mode': paymentMode,
      if (notes != null) 'notes': notes,
      'date': date,
      if (clientRef != null) 'client_ref': clientRef,
    };
  }
}