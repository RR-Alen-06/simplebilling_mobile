enum LedgerEntryType { bill, payment }

enum LedgerBalanceType { due, adv, settled }

class CustomerLedgerEntry {
  final String id;
  final String date;
  final LedgerEntryType type;
  final String referenceNumber;
  final String description;
  final double billAmount; // Debit
  final double paidAmount; // Credit
  final double runningBalance;
  final LedgerBalanceType balanceType;
  final String? notes;

  CustomerLedgerEntry({
    required this.id,
    required this.date,
    required this.type,
    required this.referenceNumber,
    required this.description,
    required this.billAmount,
    required this.paidAmount,
    required this.runningBalance,
    required this.balanceType,
    this.notes,
  });

  factory CustomerLedgerEntry.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String? ?? 'bill').toLowerCase();
    final balTypeStr = (json['balance_type'] as String? ?? 'settled').toLowerCase();

    return CustomerLedgerEntry(
      id: json['id'] as String,
      date: json['date'] as String? ?? DateTime.now().toIso8601String(),
      type: typeStr == 'payment' ? LedgerEntryType.payment : LedgerEntryType.bill,
      referenceNumber: json['reference_number'] as String? ?? '-',
      description: json['description'] as String? ?? '',
      billAmount: (json['bill_amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      runningBalance: (json['running_balance'] as num?)?.toDouble() ?? 0.0,
      balanceType: balTypeStr == 'due'
          ? LedgerBalanceType.due
          : (balTypeStr == 'adv' ? LedgerBalanceType.adv : LedgerBalanceType.settled),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'type': type == LedgerEntryType.payment ? 'payment' : 'bill',
      'reference_number': referenceNumber,
      'description': description,
      'bill_amount': billAmount,
      'paid_amount': paidAmount,
      'running_balance': runningBalance,
      'balance_type': balanceType.name,
      if (notes != null) 'notes': notes,
    };
  }
}
