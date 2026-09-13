import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/network/sync_queue_manager.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/core/utils/rounding_engine.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
import 'package:simplebilling_mobile/data/models/product_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';
import 'package:simplebilling_mobile/presentation/shared/printing/receipt_generator.dart';
import 'package:simplebilling_mobile/presentation/shared/widgets/barcode_scanner_modal.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Custom entry controllers
  final TextEditingController _customNameCtrl = TextEditingController(text: 'A4 B&W Single');
  final TextEditingController _customQtyCtrl = TextEditingController(text: '1');
  final TextEditingController _customPriceCtrl = TextEditingController(text: '2.00');

  // Search & Payment controllers
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _barcodeWedgeCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final TextEditingController _cashCtrl = TextEditingController();
  final TextEditingController _upiCtrl = TextEditingController();
  final TextEditingController _discountCtrl = TextEditingController();
  final TextEditingController _loyaltyPointsCtrl = TextEditingController();

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customNameCtrl.dispose();
    _customQtyCtrl.dispose();
    _customPriceCtrl.dispose();
    _searchCtrl.dispose();
    _barcodeWedgeCtrl.dispose();
    _cashCtrl.dispose();
    _upiCtrl.dispose();
    _discountCtrl.dispose();
    _loyaltyPointsCtrl.dispose();
    super.dispose();
  }

  void _addQuickPreset(String name, double price, [double qty = 1.0]) {
    ref.read(cartProvider.notifier).addItem(name, price, qty);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "$name" to cart'),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _addCustomItem() {
    final name = _customNameCtrl.text.trim();
    final qty = double.tryParse(_customQtyCtrl.text) ?? 1.0;
    final price = double.tryParse(_customPriceCtrl.text) ?? 0.0;
    if (name.isEmpty || qty <= 0 || price < 0) return;

    ref.read(cartProvider.notifier).addItem(name, price, qty);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "$name" ($qty x Rs. $price)'),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }



  void _openBarcodeScanner(List<ProductModel> products, List<CustomerModel> customers) {
    BarcodeScannerModal.show(
      context,
      products: products,
      customers: customers,
      onProductScanned: (product) {
        ref.read(cartProvider.notifier).addItem(product.name, product.price, 1, productId: product.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scanned & Added: ${product.name} (Rs. ${product.price})')),
        );
      },
      onCustomerScanned: (customer) {
        ref.read(cartProvider.notifier).selectCustomer(customer);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected Customer: ${customer.name}')),
        );
      },
    );
  }

  void _showAddCustomerModal() {
    final nameCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_add_rounded, color: AppColors.deepSky),
            SizedBox(width: 8),
            Text('Quick Add Customer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Customer Name *', hintText: 'Enter full name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: mobileCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile Number', hintText: '10-digit phone'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email Address', hintText: 'Optional email'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final newCust = await ApiRepository.createCustomer(
                nameCtrl.text.trim(),
                mobileCtrl.text.trim().isEmpty ? null : mobileCtrl.text.trim(),
                email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
              );
              if (newCust != null) {
                ref.invalidate(customersProvider);
                ref.invalidate(customerSummariesProvider);
                ref.read(cartProvider.notifier).selectCustomer(newCust);
              }
              if (mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Customer ${nameCtrl.text.trim()} registered & selected! 🎉')),
                );
              }
            },
            child: const Text('Save & Select', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCheckout({bool isCreditOnly = false}) async {
    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty! Add products first.')),
      );
      return;
    }

    final settings = ref.read(settingsProvider).value ?? AllSettings(
          shop: ShopSettings(),
          billing: BillingSettings(),
          loyalty: LoyaltySettings(),
        );

    final loyaltyRules = ref.read(loyaltyRulesProvider).value ?? [];
    final loyaltyDiscount = cart.calculateLoyaltyDiscount(settings.loyalty, loyaltyRules);

    final subtotalAfterDiscount = (cart.subtotal - cart.manualDiscount - loyaltyDiscount).clamp(0.0, double.infinity);
    final gstAmount = cart.calculateGst(settings.billing, subtotalAfterDiscount);
    final roundingResult = cart.getRoundingResult(loyaltyDiscount, gstAmount: gstAmount);
    final grandTotal = roundingResult.roundedTotal;

    final cash = isCreditOnly ? 0.0 : (double.tryParse(_cashCtrl.text) ?? 0.0);
    final upi = isCreditOnly ? 0.0 : (double.tryParse(_upiCtrl.text) ?? 0.0);
    final advanceUsed = (cart.useAdvance && !isCreditOnly) ? cart.advanceUsed : 0.0;

    double finalCash = cash;
    double finalUpi = upi;

    if (!isCreditOnly && cash == 0 && upi == 0) {
      final remaining = (grandTotal - advanceUsed).clamp(0.0, double.infinity);
      finalCash = remaining;
    }

    final totalPaid = finalCash + finalUpi + advanceUsed;

    // Intelligent Overpayment Redistribution
    double allocatedToPreviousDue = 0.0;
    double savedToAdvance = 0.0;
    if (totalPaid > grandTotal) {
      final excess = totalPaid - grandTotal;
      final prevDue = cart.selectedCustomer?.balanceDue ?? 0.0;
      if (prevDue > 0) {
        allocatedToPreviousDue = excess > prevDue ? prevDue : excess;
        savedToAdvance = excess - allocatedToPreviousDue;
      } else {
        savedToAdvance = excess;
      }
    }

    String paymentMethod = 'Cash';
    if (isCreditOnly || totalPaid == 0) {
      paymentMethod = 'Credit (Udhar)';
    } else if (finalCash > 0 && finalUpi > 0) {
      paymentMethod = 'Split Payment';
    } else if (finalUpi > 0) {
      paymentMethod = 'UPI';
    } else if (advanceUsed > 0 && finalCash == 0 && finalUpi == 0) {
      paymentMethod = 'Advance Wallet';
    } else if (totalPaid < grandTotal) {
      paymentMethod = 'Partial / Split Credit';
    }

    setState(() => _isProcessing = true);

    // Calculate dynamic points earned
    double pointsEarned = 0.0;
    if (settings.loyalty.enabled && totalPaid >= grandTotal - 0.01) {
      pointsEarned = await ApiRepository.calculateLoyaltyPointsEarned(grandTotal);
    }

    BillModel? newBill = await ApiRepository.createBill(
      customerId: cart.selectedCustomer?.id,
      total: cart.subtotal,
      discount: cart.manualDiscount + loyaltyDiscount,
      gstAmount: gstAmount,
      roundingMethod: cart.roundingMethod,
      roundingAdjustment: roundingResult.roundingAdjustment,
      grandTotal: grandTotal,
      cashPaid: finalCash,
      upiPaid: finalUpi,
      advanceUsed: advanceUsed,
      advanceEarned: savedToAdvance,
      paymentMethod: paymentMethod,
      loyaltyPointsEarned: pointsEarned,
      loyaltyPointsRedeemed: cart.pointsToRedeem,
      items: cart.items,
    );

    // Offline Resilient Fallback
    if (newBill == null) {
      final clientRef = const Uuid().v4();
      final offlineBillNumber = 'OFFLINE-BILL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      final billPayload = {
        'billData': {
          'bill_number': offlineBillNumber,
          'customer_id': cart.selectedCustomer?.id,
          'total': cart.subtotal,
          'discount': cart.manualDiscount + loyaltyDiscount,
          'gst_amount': gstAmount,
          'rounding_method': cart.roundingMethod.name,
          'rounding_adjustment': roundingResult.roundingAdjustment,
          'grand_total': grandTotal,
          'cash_paid': finalCash,
          'upi_paid': finalUpi,
          'paid_total': totalPaid,
          'advance_used': advanceUsed,
          'advance_earned': savedToAdvance,
          'payment_method': paymentMethod,
          'loyalty_points_earned': pointsEarned,
          'loyalty_points_redeemed': cart.pointsToRedeem,
          'client_ref': clientRef,
        },
        'itemsPayload': cart.items.map((it) => it.toJson()).toList(),
      };

      await SyncQueueManager.instance.enqueueTask(
        'create_bill',
        billPayload,
        clientRef: clientRef,
      );

      newBill = BillModel(
        id: clientRef,
        billNumber: offlineBillNumber,
        customerId: cart.selectedCustomer?.id,
        customerName: cart.selectedCustomer?.name,
        customerMobile: cart.selectedCustomer?.mobile,
        total: cart.subtotal,
        discount: cart.manualDiscount + loyaltyDiscount,
        gstAmount: gstAmount,
        roundingMethod: cart.roundingMethod.name,
        roundingAdjustment: roundingResult.roundingAdjustment,
        grandTotal: grandTotal,
        cashPaid: finalCash,
        upiPaid: finalUpi,
        paidTotal: totalPaid,
        advanceUsed: advanceUsed,
        advanceEarned: savedToAdvance,
        paymentMethod: paymentMethod,
        loyaltyPointsEarned: pointsEarned,
        loyaltyPointsRedeemed: cart.pointsToRedeem,
        createdAt: DateTime.now().toIso8601String(),
        clientRef: clientRef,
        items: cart.items,
      );
    }

    setState(() => _isProcessing = false);

    if (mounted) {
      ref.invalidate(billsListProvider);
      ref.invalidate(customersProvider);
      ref.invalidate(customerSummariesProvider);

      _showInvoiceModalHub(
        bill: newBill,
        settings: settings,
        allocatedToPrevDue: allocatedToPreviousDue,
        savedToAdvance: savedToAdvance,
      );

      ref.read(cartProvider.notifier).reset();
      _cashCtrl.clear();
      _upiCtrl.clear();
      _discountCtrl.clear();
      _loyaltyPointsCtrl.clear();
    }
  }

  void _showInvoiceModalHub({
    required BillModel bill,
    required AllSettings settings,
    required double allocatedToPrevDue,
    required double savedToAdvance,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.pastelMint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.deepMint),
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.deepMint, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                bill.billNumber.startsWith('OFFLINE') ? 'Bill Queued (Offline)' : 'Invoice Generated! 🎉',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Invoice: ${bill.billNumber}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                        Text(Formatters.parseAndFormatDate(bill.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Grand Total:', style: TextStyle(fontWeight: FontWeight.w700)),
                        Text(Formatters.currency(bill.grandTotal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Paid: ${Formatters.currency(bill.paidTotal)} via ${bill.paymentMethod}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    if (bill.customerName != null) ...[
                      const SizedBox(height: 4),
                      Text('Customer: ${bill.customerName} (${bill.customerMobile ?? "-"})', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Overpayment feedback badges
              if (allocatedToPrevDue > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.pastelAmber,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.deepAmber),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 14, color: AppColors.deepAmber),
                      const SizedBox(width: 6),
                      Text('₹${allocatedToPrevDue.toStringAsFixed(2)} allocated to previous dues', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.deepAmber)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (savedToAdvance > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.pastelMint,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.deepMint),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppColors.deepMint),
                      const SizedBox(width: 6),
                      Text('₹${savedToAdvance.toStringAsFixed(2)} credited to advance wallet', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.deepMint)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],

              const Text('Print & Distribution Hub:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 8),

              // Actions grid
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 16),
                    label: const Text('WhatsApp Receipt', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    onPressed: () async {
                      await ReceiptGenerator.shareViaWhatsApp(
                        bill: bill,
                        shop: settings.shop,
                        billing: settings.billing,
                      );
                    },
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Print 80mm POS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    onPressed: () async {
                      await ReceiptGenerator.print80mmReceipt(
                        bill: bill,
                        shop: settings.shop,
                        billing: settings.billing,
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.deepSky,
                      side: const BorderSide(color: AppColors.deepSky),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    icon: const Icon(Icons.receipt_rounded, size: 16),
                    label: const Text('Print 58mm POS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    onPressed: () async {
                      await ReceiptGenerator.print58mmReceipt(
                        bill: bill,
                        shop: settings.shop,
                        billing: settings.billing,
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.deepLavender,
                      side: const BorderSide(color: AppColors.deepLavender),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    icon: const Icon(Icons.description_rounded, size: 16),
                    label: const Text('A4 Tax Invoice', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    onPressed: () async {
                      await ReceiptGenerator.printA4Invoice(
                        bill: bill,
                        shop: settings.shop,
                        billing: settings.billing,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done / New Bill', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _openCheckoutDialog() {
    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty! Add products first.')),
      );
      return;
    }

    final settings = ref.read(settingsProvider).value ?? AllSettings(
          shop: ShopSettings(),
          billing: BillingSettings(),
          loyalty: LoyaltySettings(),
        );

    final loyaltyRules = ref.read(loyaltyRulesProvider).value ?? [];
    final loyaltyDiscount = cart.calculateLoyaltyDiscount(settings.loyalty, loyaltyRules);
    final subtotalAfterDiscount = (cart.subtotal - cart.manualDiscount - loyaltyDiscount).clamp(0.0, double.infinity);
    final gstAmount = cart.calculateGst(settings.billing, subtotalAfterDiscount);
    final roundingResult = cart.getRoundingResult(loyaltyDiscount, gstAmount: gstAmount);
    final grandTotal = roundingResult.roundedTotal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final advanceUsed = cart.useAdvance ? cart.advanceUsed : 0.0;
          final cashVal = double.tryParse(_cashCtrl.text) ?? 0.0;
          final upiVal = double.tryParse(_upiCtrl.text) ?? 0.0;
          final totalPaid = cashVal + upiVal + advanceUsed;
          final remainingDue = (grandTotal - totalPaid).clamp(0.0, double.infinity);
          final excessPaid = (totalPaid - grandTotal).clamp(0.0, double.infinity);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 14,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Split Payment & Settlement', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(ctx).pop()),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Total Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.pastelLavender,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.neoBorder, width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('BILL GRAND TOTAL:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.deepLavender)),
                        Text(Formatters.currency(grandTotal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.deepLavender)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Advance toggle
                  if (cart.selectedCustomer != null && cart.selectedCustomer!.advanceBalance > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.pastelMint,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.deepMint),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: cart.useAdvance,
                            activeColor: AppColors.deepMint,
                            onChanged: (val) {
                              final use = val ?? false;
                              final maxAdvance = cart.selectedCustomer!.advanceBalance;
                              final amt = use ? (grandTotal < maxAdvance ? grandTotal : maxAdvance) : 0.0;
                              ref.read(cartProvider.notifier).setPayments(useAdv: use, advUsed: amt);
                              setModalState(() {});
                            },
                          ),
                          Expanded(
                            child: Text(
                              'Use Advance Credit (${Formatters.currency(cart.selectedCustomer!.advanceBalance)} avail.)',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.deepMint),
                            ),
                          ),
                          Text('- ${Formatters.currency(advanceUsed)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.deepMint)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Quick Pay Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.pastelMint,
                            foregroundColor: AppColors.deepMint,
                            side: const BorderSide(color: AppColors.deepMint),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.bolt, size: 16),
                          label: const Text('⚡ All Cash', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          onPressed: () {
                            final rem = (grandTotal - advanceUsed).clamp(0.0, double.infinity);
                            _cashCtrl.text = rem.toStringAsFixed(2);
                            _upiCtrl.clear();
                            setModalState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.pastelSky,
                            foregroundColor: AppColors.deepSky,
                            side: const BorderSide(color: AppColors.deepSky),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.bolt, size: 16),
                          label: const Text('⚡ All UPI', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          onPressed: () {
                            final rem = (grandTotal - advanceUsed).clamp(0.0, double.infinity);
                            _upiCtrl.text = rem.toStringAsFixed(2);
                            _cashCtrl.clear();
                            setModalState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Cash & UPI Inputs
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cashCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Cash Paid (₹)',
                            prefixIcon: const Icon(Icons.attach_money, color: AppColors.deepMint, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _upiCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'UPI Paid (₹)',
                            prefixIcon: const Icon(Icons.qr_code_2, color: AppColors.deepSky, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Payment Status Feedback Badges
                  if (remainingDue == 0 && excessPaid == 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.pastelMint, borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: AppColors.deepMint, size: 16),
                          SizedBox(width: 6),
                          Text('Bill Paid Full ✓', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.deepMint, fontSize: 12)),
                        ],
                      ),
                    )
                  else if (remainingDue > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.pastelCoral, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Remaining Bill Due (Udhar):', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.deepCoral, fontSize: 12)),
                          Text(Formatters.currency(remainingDue), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.deepCoral, fontSize: 13)),
                        ],
                      ),
                    )
                  else if (excessPaid > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.pastelAmber, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Overpayment (Redistributed):', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.deepAmber, fontSize: 12)),
                          Text(Formatters.currency(excessPaid), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.deepAmber, fontSize: 13)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),

                  // Actions
                  Row(
                    children: [
                      if (cart.selectedCustomer != null)
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.deepCoral,
                              side: const BorderSide(color: AppColors.deepCoral, width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _isProcessing
                                ? null
                                : () {
                                    Navigator.of(ctx).pop();
                                    _handleCheckout(isCreditOnly: true);
                                  },
                            child: const Text('Charge to Credit (Udhar)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                          ),
                        ),
                      if (cart.selectedCustomer != null) const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _isProcessing
                              ? null
                              : () {
                                  Navigator.of(ctx).pop();
                                  _handleCheckout();
                                },
                          child: _isProcessing
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Complete Payment', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final customersAsync = ref.watch(customerSummariesProvider);
    final productsAsync = ref.watch(productsProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final loyaltyRulesAsync = ref.watch(loyaltyRulesProvider);

    final settings = settingsAsync.value ?? AllSettings(
          shop: ShopSettings(),
          billing: BillingSettings(),
          loyalty: LoyaltySettings(),
        );

    final loyaltyRules = loyaltyRulesAsync.value ?? [];
    final loyaltyDiscount = cart.calculateLoyaltyDiscount(settings.loyalty, loyaltyRules);
    final subtotalAfterDiscount = (cart.subtotal - cart.manualDiscount - loyaltyDiscount).clamp(0.0, double.infinity);
    final gstAmount = cart.calculateGst(settings.billing, subtotalAfterDiscount);
    final roundingResult = cart.getRoundingResult(loyaltyDiscount, gstAmount: gstAmount);
    final grandTotal = roundingResult.roundedTotal;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'SimpleBilling POS Terminal',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
        actions: [
          IconButton(
            tooltip: 'Barcode Scanner',
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.deepSky),
            onPressed: () {
              _openBarcodeScanner(productsAsync.valueOrNull ?? [], customersAsync.valueOrNull ?? []);
            },
          ),
          IconButton(
            tooltip: 'Clear Cart',
            icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.deepCoral),
            onPressed: () => ref.read(cartProvider.notifier).reset(),
          ),
        ],
      ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWidescreen = constraints.maxWidth >= 850;

            if (isWidescreen) {
              // Desktop Split-Screen POS Layout
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Side (60%): Customer selector + Tabs (Presets, Catalog, Custom)
                  Expanded(
                    flex: 6,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCustomerSelectorAndLedger(customersAsync.valueOrNull ?? []),
                          const SizedBox(height: 10),
                          _buildTabsHeader(),
                          const SizedBox(height: 10),
                          _buildActiveTabContent(productsAsync.valueOrNull ?? []),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1, color: AppColors.border),

                  // Right Side (40%): Sticky Live Cart & Instant Checkout
                  Expanded(
                    flex: 4,
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(12),
                      child: _buildCartAndCheckoutPanel(
                        cart,
                        settings,
                        loyaltyDiscount,
                        gstAmount,
                        roundingResult,
                        loyaltyRules,
                      ),
                    ),
                  ),
                ],
              );
            }

            // Mobile / Tablet POS Layout
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCustomerSelectorAndLedger(customersAsync.valueOrNull ?? []),
                        const SizedBox(height: 10),
                        _buildTabsHeader(),
                        const SizedBox(height: 10),
                        _buildActiveTabContent(productsAsync.valueOrNull ?? []),
                      ],
                    ),
                  ),
                ),
                _buildMobileCartSummaryBar(cart, grandTotal),
              ],
            );
          },
        ),
      );
  }

  Widget _buildCustomerSelectorAndLedger(List<CustomerModel> customers) {
    final cart = ref.watch(cartProvider);
    final selected = cart.selectedCustomer;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neoBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Autocomplete<CustomerModel>(
                  displayStringForOption: (c) => '${c.name} (${c.mobile ?? "No phone"})',
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) return customers.take(5);
                    final q = textEditingValue.text.toLowerCase();
                    return customers.where((c) => c.name.toLowerCase().contains(q) || (c.mobile != null && c.mobile!.contains(q)));
                  },
                  onSelected: (customer) {
                    ref.read(cartProvider.notifier).selectCustomer(customer);
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    if (selected != null && controller.text.isEmpty) {
                      controller.text = '${selected.name} (${selected.mobile ?? ""})';
                    }
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Select Customer Account',
                        hintText: 'Search by name or mobile number...',
                        prefixIcon: const Icon(Icons.person_search_rounded, color: AppColors.primary, size: 20),
                        suffixIcon: selected != null
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  controller.clear();
                                  ref.read(cartProvider.notifier).selectCustomer(null);
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pastelSky,
                  foregroundColor: AppColors.deepSky,
                  elevation: 0,
                  side: const BorderSide(color: AppColors.deepSky),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New', style: TextStyle(fontWeight: FontWeight.w800)),
                onPressed: _showAddCustomerModal,
              ),
            ],
          ),

          // Live Ledger Snapshot Card
          if (selected != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLedgerPill('PREV. DUE (UDHAR)', Formatters.currency(selected.balanceDue), AppColors.pastelCoral, AppColors.deepCoral, AppColors.borderCoral),
                      _buildLedgerPill('ADVANCE WALLET', Formatters.currency(selected.advanceBalance), AppColors.pastelMint, AppColors.deepMint, AppColors.borderMint),
                      _buildLedgerPill('LOYALTY PTS', '${selected.loyaltyPoints.toStringAsFixed(0)} ⭐', AppColors.pastelAmber, AppColors.deepAmber, AppColors.borderAmber),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLedgerPill(String label, String value, Color bgColor, Color textColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildTabsHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neoBorder, width: 1.5),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.deepLavender,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.deepLavender,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        tabs: const [
          Tab(text: '⚡ Xerox Presets'),
          Tab(text: '📦 Catalog'),
          Tab(text: '✏️ Custom Add'),
        ],
        onTap: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildActiveTabContent(List<ProductModel> products) {
    if (_tabController.index == 0) {
      return _buildXeroxPresetsGrid();
    } else if (_tabController.index == 1) {
      return _buildCatalogTab(products);
    } else {
      return _buildCustomEntryForm();
    }
  }

  Widget _buildXeroxPresetsGrid() {
    final presets = [
      {'name': 'A4 B&W Single', 'price': 2.0, 'color': AppColors.pastelMint, 'textColor': AppColors.deepMint},
      {'name': 'A4 B&W Back to Back', 'price': 3.0, 'color': AppColors.pastelMint, 'textColor': AppColors.deepMint},
      {'name': 'A4 Color Single', 'price': 10.0, 'color': AppColors.pastelSky, 'textColor': AppColors.deepSky},
      {'name': 'A4 Color B2B', 'price': 15.0, 'color': AppColors.pastelSky, 'textColor': AppColors.deepSky},
      {'name': 'A3 B&W Single', 'price': 5.0, 'color': AppColors.pastelLavender, 'textColor': AppColors.deepLavender},
      {'name': 'A3 Color Print', 'price': 20.0, 'color': AppColors.pastelLavender, 'textColor': AppColors.deepLavender},
      {'name': 'Spiral Binding', 'price': 40.0, 'color': AppColors.pastelAmber, 'textColor': AppColors.deepAmber},
      {'name': 'Soft / Hard Binding', 'price': 80.0, 'color': AppColors.pastelAmber, 'textColor': AppColors.deepAmber},
      {'name': 'Lamination (A4)', 'price': 30.0, 'color': AppColors.pastelCoral, 'textColor': AppColors.deepCoral},
      {'name': 'Passport Photo (8 Pcs)', 'price': 60.0, 'color': AppColors.pastelCoral, 'textColor': AppColors.deepCoral},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: presets.length,
      itemBuilder: (ctx, i) {
        final p = presets[i];
        final name = p['name'] as String;
        final price = p['price'] as double;
        final bgColor = p['color'] as Color;
        final textColor = p['textColor'] as Color;

        return InkWell(
          onTap: () => _addQuickPreset(name, price),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.neoBorder, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: textColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.neoBorder),
                  ),
                  child: Text('₹${price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.textPrimary)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCatalogTab(List<ProductModel> products) {
    final categories = ['All', 'Xerox', 'Print', 'Paper', 'Binding', 'Stationery', 'Other'];
    final filtered = products.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || p.category.toLowerCase() == _selectedCategory.toLowerCase();
      return matchesSearch && matchesCategory;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search products by name / barcode...',
            prefixIcon: const Icon(Icons.search, color: AppColors.primary),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
        const SizedBox(height: 8),

        // Category chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(cat, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: isSelected ? Colors.white : AppColors.textPrimary)),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.neoBorder),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),

        // Product cards list
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No matching products in catalog', style: TextStyle(color: AppColors.textMuted))),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (c, i) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final p = filtered[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.neoBorder, width: 1.2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                          Text('Category: ${p.category}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Text('₹${p.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.primary)),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pastelMint,
                        foregroundColor: AppColors.deepMint,
                        elevation: 0,
                        side: const BorderSide(color: AppColors.deepMint),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _addQuickPreset(p.name, p.price, 1),
                      child: const Text('+ Add', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildCustomEntryForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neoBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Fast Custom Xerox / Print Entry', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 12),
          TextField(
            controller: _customNameCtrl,
            decoration: const InputDecoration(labelText: 'Item / Service Description *', hintText: 'e.g. A4 Double Side Xerox'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customQtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Page Quantity *'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _customPriceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Unit Rate (₹) *'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Multiplier Chips
          const Text('Quick Multipliers:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [1, 5, 10, 20, 50, 100].map((m) {
              return ActionChip(
                label: Text('+$m', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                backgroundColor: AppColors.pastelSky,
                side: const BorderSide(color: AppColors.borderSky),
                onPressed: () {
                  final cur = double.tryParse(_customQtyCtrl.text) ?? 0.0;
                  _customQtyCtrl.text = (cur + m).toStringAsFixed(0);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Add to Bill Cart', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              onPressed: _addCustomItem,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartAndCheckoutPanel(
    CartState cart,
    AllSettings settings,
    double loyaltyDiscount,
    double gstAmount,
    RoundingResult roundingResult,
    List<LoyaltyRedemptionRule> loyaltyRules,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_bag_rounded, color: AppColors.deepLavender, size: 20),
                const SizedBox(width: 6),
                Text('Active Cart (${cart.items.length})', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            ),
            if (cart.items.isNotEmpty)
              TextButton(
                onPressed: () => ref.read(cartProvider.notifier).reset(),
                child: const Text('Clear All', style: TextStyle(color: AppColors.deepCoral, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
          ],
        ),
        const Divider(height: 1),
        const SizedBox(height: 8),

        // Cart items scroll list with IN-LINE RATE OVERRIDES
        Expanded(
          child: cart.items.isEmpty
              ? const Center(
                  child: Text('Your cart is empty.\nTap presets or catalog items to add.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                )
              : ListView.separated(
                  itemCount: cart.items.length,
                  separatorBuilder: (c, i) => const Divider(height: 12),
                  itemBuilder: (ctx, i) {
                    final it = cart.items[i];
                    return Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(it.productName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5), overflow: TextOverflow.ellipsis),
                              Row(
                                children: [
                                  const Text('Rate: ₹', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  // Inline Unit Rate Override Input
                                  SizedBox(
                                    width: 50,
                                    height: 24,
                                    child: TextField(
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2), isDense: true),
                                      controller: TextEditingController(text: it.price.toStringAsFixed(2)),
                                      onSubmitted: (val) {
                                        final p = double.tryParse(val);
                                        if (p != null) ref.read(cartProvider.notifier).updateItemPrice(i, p);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Qty + / - controls
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 18),
                              onPressed: () => ref.read(cartProvider.notifier).updateItemQuantity(i, it.quantity - 1),
                            ),
                            Text(it.quantity.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 18),
                              onPressed: () => ref.read(cartProvider.notifier).updateItemQuantity(i, it.quantity + 1),
                            ),
                          ],
                        ),
                        Text(Formatters.currency(it.total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.deepCoral),
                          onPressed: () => ref.read(cartProvider.notifier).removeItem(i),
                        ),
                      ],
                    );
                  },
                ),
        ),

        const Divider(height: 1),
        const SizedBox(height: 6),

        // Discounts, Loyalty & Tax calculations
        _buildTotalsAndDiscountControls(cart, settings, loyaltyDiscount, gstAmount, roundingResult, loyaltyRules),
      ],
    );
  }

  Widget _buildTotalsAndDiscountControls(
    CartState cart,
    AllSettings settings,
    double loyaltyDiscount,
    double gstAmount,
    RoundingResult roundingResult,
    List<LoyaltyRedemptionRule> loyaltyRules,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Loyalty Redemption Slider / Tiers
        if (cart.selectedCustomer != null && cart.selectedCustomer!.loyaltyPoints >= 10 && settings.loyalty.enabled) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.pastelAmber,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderAmber),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('🎁 Redeem Loyalty (⭐ ${cart.selectedCustomer!.loyaltyPoints.toStringAsFixed(0)} avail.)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.deepAmber)),
                    if (loyaltyDiscount > 0)
                      Text('- ${Formatters.currency(loyaltyDiscount)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.deepAmber)),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [10, 20, 30, 40, 50].where((pts) => pts <= cart.selectedCustomer!.loyaltyPoints).map((pts) {
                    final isSel = cart.pointsToRedeem == pts.toDouble();
                    return ActionChip(
                      label: Text('$pts Pts', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: isSel ? Colors.white : AppColors.deepAmber)),
                      backgroundColor: isSel ? AppColors.deepAmber : Colors.white,
                      onPressed: () {
                        ref.read(cartProvider.notifier).setPayments(loyaltyRedeem: isSel ? 0.0 : pts.toDouble());
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],

        // Summary Rows
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subtotal:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text(Formatters.currency(cart.subtotal), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
        if (cart.manualDiscount > 0) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Manual Discount:', style: TextStyle(fontSize: 12, color: AppColors.deepCoral)),
              Text('- ${Formatters.currency(cart.manualDiscount)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.deepCoral)),
            ],
          ),
        ],
        if (gstAmount > 0) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('GST (${settings.billing.gstRate}%):', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text('+ ${Formatters.currency(gstAmount)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
        ],
        if (roundingResult.roundingAdjustment != 0) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Rounding (${cart.roundingMethod.name}):', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(
                '${roundingResult.roundingAdjustment > 0 ? '+' : ''}${roundingResult.roundingAdjustment.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
              ),
            ],
          ),
        ],
        const SizedBox(height: 6),

        // Grand Total & Checkout Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.pastelMint,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.deepMint, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('GRAND TOTAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.deepMint)),
                  Text(Formatters.currency(roundingResult.roundedTotal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.deepMint)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.payment_rounded, size: 16),
                label: const Text('Checkout (F12)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                onPressed: _openCheckoutDialog,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileCartSummaryBar(CartState cart, double grandTotal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${cart.items.length} item(s)', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              Text(Formatters.currency(grandTotal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primary)),
            ],
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 16),
            label: const Text('Cart & Pay', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            onPressed: _openCheckoutDialog,
          ),
        ],
      ),
    );
  }
}
