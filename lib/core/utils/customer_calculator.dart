import 'package:simplebilling_mobile/data/models/customer_model.dart';

class CustomerSummaryResult {
  final double totalBilled;
  final double totalPaid;
  final double balanceDue;

  const CustomerSummaryResult({
    required this.totalBilled,
    required this.totalPaid,
    required this.balanceDue,
  });
}

class CustomerCalculator {
  CustomerCalculator._();

  /// Calculates running totals (totalBilled, totalPaid, balanceDue) from raw lists or models
  static CustomerSummaryResult calculateBalances({
    required double advanceBalance,
    required Iterable<Map<String, dynamic>> bills,
    required Iterable<Map<String, dynamic>> directPayments,
  }) {
    final totalBilled = bills.fold<double>(
      0.0,
      (sum, b) => sum + ((b['grand_total'] as num?)?.toDouble() ?? 0.0),
    );

    final billPayments = bills.fold<double>(
      0.0,
      (sum, b) => sum + ((b['paid_total'] as num?)?.toDouble() ?? 0.0),
    );

    final directPaymentsTotal = directPayments.fold<double>(
      0.0,
      (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0),
    );

    final totalPaid = billPayments + directPaymentsTotal;
    final balanceDue = (totalBilled - totalPaid - advanceBalance).clamp(
      0.0,
      double.infinity,
    );

    return CustomerSummaryResult(
      totalBilled: double.parse(totalBilled.toStringAsFixed(2)),
      totalPaid: double.parse(totalPaid.toStringAsFixed(2)),
      balanceDue: double.parse(balanceDue.toStringAsFixed(2)),
    );
  }

  /// Convenience method to compute and return an updated CustomerModel
  static CustomerModel applyBalances({
    required CustomerModel customer,
    required Iterable<Map<String, dynamic>> bills,
    required Iterable<Map<String, dynamic>> directPayments,
  }) {
    final result = calculateBalances(
      advanceBalance: customer.advanceBalance,
      bills: bills,
      directPayments: directPayments,
    );

    return customer.copyWith(
      totalBilled: result.totalBilled,
      totalPaid: result.totalPaid,
      balanceDue: result.balanceDue,
    );
  }
}
