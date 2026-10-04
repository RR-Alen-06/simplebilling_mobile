import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/network/sync_queue_manager.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
import 'package:simplebilling_mobile/data/models/product_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';
import 'package:simplebilling_mobile/presentation/screens/billing/widgets/billing_dialogs.dart';
import 'package:simplebilling_mobile/presentation/screens/billing/widgets/billing_step_header.dart';
import 'package:simplebilling_mobile/presentation/screens/billing/widgets/customer_discount_step.dart';
import 'package:simplebilling_mobile/presentation/screens/billing/widgets/items_catalog_step.dart';
import 'package:simplebilling_mobile/presentation/screens/billing/widgets/payment_settlement_step.dart';
import 'package:simplebilling_mobile/presentation/shared/printing/receipt_generator.dart';
import 'package:simplebilling_mobile/presentation/shared/widgets/barcode_scanner_modal.dart';
import 'package:simplebilling_mobile/presentation/shared/widgets/invoice_modal.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  int _currentStep = 0; // 0: Items, 1: Customer & Discounts, 2: Payment
  bool _isCartExpanded = true;

  // Custom Item entry controllers
  final TextEditingController _customNameCtrl = TextEditingController(text: 'A4 B&W Single');
  final TextEditingController _customQtyCtrl = TextEditingController(text: '1');
  final TextEditingController _customPriceCtrl = TextEditingController(text: '2.00');

  // Search & Filters
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  // Payment & Discount controllers
  final TextEditingController _cashCtrl = TextEditingController();
  final TextEditingController _upiCtrl = TextEditingController();
  final TextEditingController _percentDiscountCtrl = TextEditingController();
  final TextEditingController _flatDiscountCtrl = TextEditingController();
  String _selectedPaymentMode = 'Cash'; // Cash, UPI, Card, Credit, Split

  bool _isProcessing = false;

  @override
  void dispose() {
    _customNameCtrl.dispose();
    _customQtyCtrl.dispose();
    _customPriceCtrl.dispose();
    _searchCtrl.dispose();
    _cashCtrl.dispose();
    _upiCtrl.dispose();
    _percentDiscountCtrl.dispose();
    _flatDiscountCtrl.dispose();
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

  bool _addCustomItemDirect(String name, double? qty, double? price) {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an item name'),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quantity must be greater than 0'),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Price cannot be negative'),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }

    ref.read(cartProvider.notifier).addItem(name, price, qty);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "$name" ($qty x Rs. $price)'),
        duration: const Duration(milliseconds: 500),
      ),
    );
    return true;
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

  Future<void> _handleCheckout() async {
    if (_isProcessing) return;

    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart is empty! Add products first.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final isCreditOnly = _selectedPaymentMode == 'Credit';
    if (isCreditOnly && cart.selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or add a customer to give Credit (Udhar)!'),
          backgroundColor: AppColors.error,
        ),
      );
      BillingDialogs.showAddCustomerModal(context: context, ref: ref);
      return;
    }

    final settings = ref.read(settingsProvider).value ??
        AllSettings(
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
      if (_selectedPaymentMode == 'UPI') {
        finalUpi = remaining;
      } else {
        finalCash = remaining;
      }
    }

    final totalPaid = finalCash + finalUpi + advanceUsed;

    // Overpayment and change handling
    double allocatedToPreviousDue = 0.0;
    double savedToAdvance = 0.0;
    double changeToReturn = 0.0;

    if (totalPaid > grandTotal) {
      final excess = totalPaid - grandTotal;
      if (cart.selectedCustomer != null) {
        final prevDue = cart.selectedCustomer?.balanceDue ?? 0.0;
        if (prevDue > 0) {
          allocatedToPreviousDue = excess > prevDue ? prevDue : excess;
          savedToAdvance = excess - allocatedToPreviousDue;
        } else {
          savedToAdvance = excess;
        }
      } else {
        changeToReturn = excess;
      }
    }

    String paymentMethod = _selectedPaymentMode;
    if (isCreditOnly || totalPaid == 0) {
      paymentMethod = 'Credit (Udhar)';
    } else if (finalCash > 0 && finalUpi > 0) {
      paymentMethod = 'Split Payment';
    } else if (finalUpi > 0 && finalCash == 0) {
      paymentMethod = 'UPI';
    } else if (advanceUsed > 0 && finalCash == 0 && finalUpi == 0) {
      paymentMethod = 'Advance Wallet';
    } else if (totalPaid < grandTotal) {
      paymentMethod = 'Partial / Split Credit';
    }

    setState(() => _isProcessing = true);

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
          'paid_total': (totalPaid - changeToReturn).clamp(0.0, grandTotal),
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
        paidTotal: (totalPaid - changeToReturn).clamp(0.0, grandTotal),
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
        changeToReturn: changeToReturn,
      );

      ref.read(cartProvider.notifier).reset();
      _cashCtrl.clear();
      _upiCtrl.clear();
      _percentDiscountCtrl.clear();
      _flatDiscountCtrl.clear();
      setState(() => _currentStep = 0);
    }
  }

  void _showInvoiceModalHub({
    required BillModel bill,
    required AllSettings settings,
    required double allocatedToPrevDue,
    required double savedToAdvance,
    double changeToReturn = 0.0,
  }) {
    final bool isOffline = bill.billNumber.startsWith('OFFLINE');

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
                color: isOffline ? AppColors.pastelAmber : AppColors.pastelMint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isOffline ? AppColors.deepAmber : AppColors.deepMint),
              ),
              child: Icon(
                isOffline ? Icons.cloud_off_rounded : Icons.check_circle_rounded,
                color: isOffline ? AppColors.deepAmber : AppColors.deepMint,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOffline ? 'Queued Offline' : 'Invoice Generated! 🎉',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: isOffline ? AppColors.deepAmber : AppColors.textPrimary,
                    ),
                  ),
                  if (isOffline)
                    const Text(
                      'Pending Cloud Sync (Saved Locally)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.deepAmber),
                    ),
                ],
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
                  border: Border.all(color: isOffline ? AppColors.deepAmber.withValues(alpha: 0.4) : AppColors.border),
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
                        Text(Formatters.currency(bill.grandTotal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primaryEmerald)),
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
              if (changeToReturn > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF3B82F6)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.currency_rupee, size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 6),
                      Text(
                        'Change to Return: ${Formatters.currency(changeToReturn)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
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
              if (bill.loyaltyPointsEarned > 0 || bill.loyaltyPointsRedeemed > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars_rounded, size: 15, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${bill.loyaltyPointsRedeemed > 0 ? "Redeemed: ${bill.loyaltyPointsRedeemed.toInt()} pts  •  " : ""}'
                          'Earned: +${bill.loyaltyPointsEarned.toInt()} pts',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6D28D9)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
              const Text('Print & Distribution Hub:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 8),
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
                      backgroundColor: AppColors.primaryEmerald,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Print 80mm POS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    onPressed: () async {
                      await ReceiptGenerator.printReceipt(
                        bill: bill,
                        shop: settings.shop,
                        billing: settings.billing,
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                    label: const Text('View Full Invoice', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      InvoiceModal.show(context, bill: bill, settings: settings);
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
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done & New Bill'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final productsAsync = ref.watch(productsProvider);
    final customersAsync = ref.watch(customersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.point_of_sale, color: AppColors.primaryDark, size: 18),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'POS Billing Wizard',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (cart.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.error),
              tooltip: 'Clear Cart',
              onPressed: () => ref.read(cartProvider.notifier).reset(),
            ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primaryEmerald),
            tooltip: 'Barcode Scan',
            onPressed: () {
              final prods = productsAsync.value ?? [];
              final custs = customersAsync.value ?? [];
              _openBarcodeScanner(prods, custs);
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          BillingStepHeader(
            currentStep: _currentStep,
            onStepSelected: (step) => setState(() => _currentStep = step),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildCurrentStepView(cart, productsAsync, customersAsync),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepView(
    CartState cart,
    AsyncValue<List<ProductModel>> productsAsync,
    AsyncValue<List<CustomerModel>> customersAsync,
  ) {
    switch (_currentStep) {
      case 0:
        return ItemsCatalogStep(
          cart: cart,
          products: productsAsync.value ?? [],
          searchCtrl: _searchCtrl,
          searchQuery: _searchQuery,
          selectedCategory: _selectedCategory,
          isCartExpanded: _isCartExpanded,
          onToggleCartExpand: () => setState(() => _isCartExpanded = !_isCartExpanded),
          onCategorySelected: (cat) => setState(() => _selectedCategory = cat),
          onSearchChanged: (val) => setState(() => _searchQuery = val.trim()),
          onClearSearch: () {
            _searchCtrl.clear();
            setState(() => _searchQuery = '');
          },
          onShowCustomItem: () => BillingDialogs.showCustomItemSheet(
            context: context,
            ref: ref,
            customNameCtrl: _customNameCtrl,
            customQtyCtrl: _customQtyCtrl,
            customPriceCtrl: _customPriceCtrl,
            onAddCustomItem: _addCustomItemDirect,
          ),
          onAddQuickPreset: _addQuickPreset,
          onProceedToCustomer: () => setState(() => _currentStep = 1),
          onEditQuantity: (itemIndex, item) => BillingDialogs.showEditQuantityDialog(
            context: context,
            ref: ref,
            itemIndex: itemIndex,
            item: item,
          ),
          onEditPrice: (itemIndex, item) => BillingDialogs.showEditPriceDialog(
            context: context,
            ref: ref,
            itemIndex: itemIndex,
            item: item,
          ),
          ref: ref,
        );
      case 1:
        return CustomerDiscountStep(
          cart: cart,
          customers: customersAsync.value ?? [],
          percentDiscountCtrl: _percentDiscountCtrl,
          flatDiscountCtrl: _flatDiscountCtrl,
          onAddCustomer: () => BillingDialogs.showAddCustomerModal(context: context, ref: ref),
          onRedeemLoyalty: (customer, settings, rules) => BillingDialogs.showRedeemLoyaltyDialog(
            context: context,
            ref: ref,
            customer: customer,
            settings: settings,
            rules: rules,
          ),
          onBackToItems: () => setState(() => _currentStep = 0),
          onProceedToPayment: () => setState(() => _currentStep = 2),
          ref: ref,
        );
      case 2:
        return PaymentSettlementStep(
          cart: cart,
          selectedPaymentMode: _selectedPaymentMode,
          onPaymentModeChanged: (mode) => setState(() => _selectedPaymentMode = mode),
          cashCtrl: _cashCtrl,
          upiCtrl: _upiCtrl,
          isProcessing: _isProcessing,
          onBackToDiscounts: () => setState(() => _currentStep = 1),
          onCheckout: _handleCheckout,
          onStateChanged: () => setState(() {}),
          ref: ref,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
