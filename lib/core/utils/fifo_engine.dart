class FifoAllocationResult {
  final double allocatedToPriorBills;
  final double advanceEarned;
  final double paidTotalForCurrentBill;

  FifoAllocationResult({
    required this.allocatedToPriorBills,
    required this.advanceEarned,
    required this.paidTotalForCurrentBill,
  });
}

FifoAllocationResult calculatePaymentAllocation({
  required double roundedGrandTotal,
  required double directPaid,
  required double advanceUsed,
  required double priorOutstandingBillsTotal,
}) {
  final netDueForCurrentBill = (roundedGrandTotal - advanceUsed).clamp(0.0, double.infinity);
  final overpayment = (directPaid - netDueForCurrentBill).clamp(0.0, double.infinity);

  final allocatedToPriorBills = overpayment > priorOutstandingBillsTotal
      ? priorOutstandingBillsTotal
      : overpayment;

  final advanceEarned = overpayment - allocatedToPriorBills;
  final paidTotalForCurrentBill = (directPaid + advanceUsed).clamp(0.0, roundedGrandTotal);

  return FifoAllocationResult(
    allocatedToPriorBills: allocatedToPriorBills,
    advanceEarned: advanceEarned,
    paidTotalForCurrentBill: paidTotalForCurrentBill,
  );
}
