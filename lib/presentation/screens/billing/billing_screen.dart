import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/constants/app_theme.dart';
import 'package:simplebilling_mobile/core/network/sync_queue_manager.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
import 'package:simplebilling_mobile/data/models/product_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';
import 'package:simplebilling_mobile/presentation/shared/printing/receipt_generator.dart';
import 'package:simplebilling_mobile/presentation/shared/widgets/barcode_scanner_modal.dart';
import 'package:simplebilling_mobile/presentation/shared/widgets/invoice_modal.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  int _currentStep = 0; // 0: Items, 1: Customer & Discounts, 2: Payment
  bool _isCartExpanded = true;

  // Custom Item entry
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
  final TextEditingController _discountCtrl = TextEditingController();
  String _selectedPaymentMode = 'Cash'; // Cash, UPI, Card, Credit, Split

  bool _isProcessing = false;

  void _showEditQuantityDialog(int itemIndex, BillItemModel item) {
    final qtyCtrl = TextEditingController(
      text: item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: AppColors.primaryEmerald),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Edit Qty: ${item.productName}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter exact quantity (e.g. 250 copies, 1.5 units). Enter 0 to remove item.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Quantity',
                hintText: 'e.g. 10',
                prefixIcon: Icon(Icons.pin_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryEmerald,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final newQty = double.tryParse(qtyCtrl.text.trim());
              if (newQty != null && newQty >= 0) {
                ref.read(cartProvider.notifier).updateItemQuantity(itemIndex, newQty);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showEditPriceDialog(int itemIndex, BillItemModel item) {
    final priceCtrl = TextEditingController(
      text: item.price % 1 == 0 ? item.price.toInt().toString() : item.price.toStringAsFixed(2),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.price_change_outlined, color: AppColors.primaryEmerald),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Edit Unit Price: ${item.productName}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter new unit price per item/page.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Unit Price (₹)',
                hintText: 'e.g. 2.50',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryEmerald,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final newPrice = double.tryParse(priceCtrl.text.trim());
              if (newPrice != null && newPrice >= 0) {
                ref.read(cartProvider.notifier).updateItemPrice(itemIndex, newPrice);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Update Price'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _customNameCtrl.dispose();
    _customQtyCtrl.dispose();
    _customPriceCtrl.dispose();
    _searchCtrl.dispose();
    _cashCtrl.dispose();
    _upiCtrl.dispose();
    _discountCtrl.dispose();
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
            Icon(Icons.person_add_rounded, color: AppColors.primaryEmerald),
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
              backgroundColor: AppColors.primaryEmerald,
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
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Customer ${nameCtrl.text.trim()} registered & selected! 🎉')),
              );
            },
            child: const Text('Save & Select', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCheckout() async {
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

    final isCreditOnly = _selectedPaymentMode == 'Credit';
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

    // Overpayment handling
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
      setState(() => _currentStep = 0);
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
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.point_of_sale, color: AppColors.primaryDark, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('POS Billing Wizard', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
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
          // Multi-Step Progress Indicator
          _buildStepProgressHeader(),

          // Step Content
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

  // --- Step 1, 2, 3 Wizard Header ---
  Widget _buildStepProgressHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildStepPill(0, '1. Items & Cart', Icons.shopping_basket_outlined),
          const SizedBox(width: 6),
          Expanded(child: Container(height: 2, color: _currentStep >= 1 ? AppColors.primaryEmerald : AppColors.border)),
          const SizedBox(width: 6),
          _buildStepPill(1, '2. Customer', Icons.person_outline),
          const SizedBox(width: 6),
          Expanded(child: Container(height: 2, color: _currentStep >= 2 ? AppColors.primaryEmerald : AppColors.border)),
          const SizedBox(width: 6),
          _buildStepPill(2, '3. Payment', Icons.payments_outlined),
        ],
      ),
    );
  }

  Widget _buildStepPill(int stepIndex, String title, IconData icon) {
    final isActive = _currentStep == stepIndex;
    final isCompleted = _currentStep > stepIndex;

    return InkWell(
      onTap: () {
        if (isCompleted || stepIndex < _currentStep) {
          setState(() => _currentStep = stepIndex);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryContainer
              : isCompleted
                  ? AppColors.pastelMint
                  : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? AppColors.primaryEmerald
                : isCompleted
                    ? AppColors.borderMint
                    : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCompleted ? Icons.check_circle : icon,
              size: 15,
              color: isActive
                  ? AppColors.primaryDark
                  : isCompleted
                      ? AppColors.deepMint
                      : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive
                    ? AppColors.primaryDark
                    : isCompleted
                        ? AppColors.deepMint
                        : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepView(CartState cart, AsyncValue<List<ProductModel>> productsAsync, AsyncValue<List<CustomerModel>> customersAsync) {
    switch (_currentStep) {
      case 0:
        return _buildStep1ItemsCatalog(cart, productsAsync, customersAsync);
      case 1:
        return _buildStep2CustomerDiscounts(cart, customersAsync);
      case 2:
        return _buildStep3PaymentSettlement(cart);
      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================
  // STEP 1: Items, Quick Presets & Cart
  // ==========================================
  Widget _buildStep1ItemsCatalog(CartState cart, AsyncValue<List<ProductModel>> productsAsync, AsyncValue<List<CustomerModel>> customersAsync) {
    final products = productsAsync.value ?? [];
    final categories = ['All', ...{for (var p in products) p.category}];

    final filteredProducts = products.where((p) {
      final matchesCat = _selectedCategory == 'All' || p.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (p.productCode?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      return matchesCat && matchesSearch;
    }).toList();

    return Column(
      children: [
        // Collapsible Active Cart Section
        if (cart.items.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderMint, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryEmerald.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => setState(() => _isCartExpanded = !_isCartExpanded),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.pastelMint,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.shopping_cart_outlined, color: AppColors.deepMint, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Active Cart (${cart.items.length})',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            Formatters.currency(cart.subtotal),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: AppColors.error,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                          onPressed: () => ref.read(cartProvider.notifier).reset(),
                          child: const Text('Clear', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                        Icon(
                          _isCartExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isCartExpanded) ...[
                  const Divider(height: 1, color: AppColors.border),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      itemCount: cart.items.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 8, color: AppColors.surfaceVariant),
                      itemBuilder: (ctx, itemIdx) {
                        final item = cart.items[itemIdx];
                        final origProd = item.productId != null
                            ? products.firstWhereOrNull((p) => p.id == item.productId)
                            : null;
                        final isCustomPrice = origProd != null && (origProd.price - item.price).abs() > 0.001;
                        final qtyDisplay = item.quantity % 1 == 0
                            ? item.quantity.toInt().toString()
                            : item.quantity.toString();

                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      // Tap to edit price
                                      InkWell(
                                        onTap: () => _showEditPriceDialog(itemIdx, item),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isCustomPrice ? AppColors.pastelAmber : AppColors.surfaceVariant,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: isCustomPrice ? AppColors.deepAmber : AppColors.border,
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '@ ₹${item.price % 1 == 0 ? item.price.toInt() : item.price.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: isCustomPrice ? AppColors.deepAmber : AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(width: 3),
                                              Icon(
                                                Icons.edit,
                                                size: 10,
                                                color: isCustomPrice ? AppColors.deepAmber : AppColors.textSecondary,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (isCustomPrice) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppColors.pastelAmber,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Custom Rate',
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.deepAmber),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 6),
                                      Text(
                                        '= ₹${item.total.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryEmerald),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Quantity Controls
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => ref.read(cartProvider.notifier).decrementQuantity(itemIdx),
                                  borderRadius: BorderRadius.circular(6),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.remove_circle_outline, color: AppColors.error, size: 18),
                                  ),
                                ),
                                // Tap to edit quantity
                                InkWell(
                                  onTap: () => _showEditQuantityDialog(itemIdx, item),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    margin: const EdgeInsets.symmetric(horizontal: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.primaryEmerald.withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          qtyDisplay,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primaryDark),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(Icons.edit, size: 10, color: AppColors.primaryDark),
                                      ],
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => ref.read(cartProvider.notifier).incrementQuantity(itemIdx),
                                  borderRadius: BorderRadius.circular(6),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.add_circle, color: AppColors.primaryEmerald, size: 18),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => ref.read(cartProvider.notifier).removeItem(itemIdx),
                                  borderRadius: BorderRadius.circular(6),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.close, color: AppColors.textMuted, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

        // Quick Search & Action Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search products or scan SKU...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _showCustomItemSheet,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border, width: 1.2),
                  ),
                  child: const Icon(Icons.playlist_add, color: AppColors.secondaryIndigo, size: 22),
                ),
              ),
            ],
          ),
        ),

        // Category Chips
        SizedBox(
          height: 38,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (ctx, i) {
              final cat = categories[i];
              final isSelected = _selectedCategory == cat;
              return ChoiceChip(
                label: Text(cat, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                selected: isSelected,
                selectedColor: AppColors.primaryContainer,
                backgroundColor: Colors.white,
                side: BorderSide(color: isSelected ? AppColors.primaryEmerald : AppColors.border),
                onSelected: (sel) => setState(() => _selectedCategory = cat),
              );
            },
          ),
        ),

        const SizedBox(height: 6),

        // Quick Preset Buttons Grid (Xerox & Common services)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(child: _buildPresetCard('A4 B&W', '₹2.00', () => _addQuickPreset('A4 B&W Xerox', 2.0))),
              const SizedBox(width: 6),
              Expanded(child: _buildPresetCard('A4 Color', '₹10.00', () => _addQuickPreset('A4 Color Xerox', 10.0))),
              const SizedBox(width: 6),
              Expanded(child: _buildPresetCard('Spiral', '₹40.00', () => _addQuickPreset('Spiral Binding', 40.0))),
              const SizedBox(width: 6),
              Expanded(child: _buildPresetCard('Laminate', '₹25.00', () => _addQuickPreset('A4 Lamination', 25.0))),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Products List
        Expanded(
          child: filteredProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted.withValues(alpha: 0.6)),
                      const SizedBox(height: 10),
                      const Text('No products found', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Custom Item to Cart'),
                        onPressed: _showCustomItemSheet,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
                  itemCount: filteredProducts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final prod = filteredProducts[idx];
                    final cartIndex = cart.items.indexWhere(
                      (it) => (it.productId != null && it.productId == prod.id) || it.productName == prod.name,
                    );
                    final cartItem = cartIndex >= 0 ? cart.items[cartIndex] : null;

                    final isCustomPrice = cartItem != null && (cartItem.price - prod.price).abs() > 0.001;
                    final qtyDisplay = cartItem != null
                        ? (cartItem.quantity % 1 == 0 ? cartItem.quantity.toInt().toString() : cartItem.quantity.toString())
                        : '0';

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: AppTheme.tactileCardDecoration(),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(Icons.shopping_bag_outlined, color: AppColors.primaryDark, size: 22),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prod.name,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      Formatters.currency(cartItem != null ? cartItem.price : prod.price),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: isCustomPrice ? AppColors.deepAmber : AppColors.primaryEmerald,
                                      ),
                                    ),
                                    if (isCustomPrice) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.pastelAmber,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Custom',
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.deepAmber),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (cartItem != null) ...[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 22),
                                  onPressed: () => ref.read(cartProvider.notifier).decrementQuantity(cartIndex),
                                ),
                                // Tap to edit quantity in catalog list
                                InkWell(
                                  onTap: () => _showEditQuantityDialog(cartIndex, cartItem),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.primaryEmerald.withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          qtyDisplay,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primaryDark),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(Icons.edit, size: 10, color: AppColors.primaryDark),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle, color: AppColors.primaryEmerald, size: 22),
                                  onPressed: () => ref.read(cartProvider.notifier).incrementQuantity(cartIndex),
                                ),
                              ],
                            ),
                          ] else ...[
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => ref.read(cartProvider.notifier).addItem(prod.name, prod.price, 1, productId: prod.id),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add, size: 16),
                                  SizedBox(width: 4),
                                  Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Floating Sticky Bottom Summary Bar
        _buildStep1FloatingDock(cart),
      ],
    );
  }

  Widget _buildPresetCard(String title, String price, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(price, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryEmerald)),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1FloatingDock(CartState cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.border, width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${cart.items.length} Items Selected',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                Text(
                  Formatters.currency(cart.subtotal),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cart.items.isEmpty ? AppColors.textMuted : AppColors.primaryEmerald,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: cart.items.isEmpty
                  ? null
                  : () {
                      setState(() => _currentStep = 1);
                    },
              child: const Row(
                children: [
                  Text('Proceed to Customer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomItemSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Custom Item / Xerox Spec', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(
              controller: _customNameCtrl,
              decoration: const InputDecoration(labelText: 'Item / Service Name', hintText: 'e.g. A3 Color Print'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customQtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity', hintText: '1'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _customPriceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Unit Price (₹)', hintText: '2.00'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _addCustomItem();
                  Navigator.pop(ctx);
                },
                child: const Text('Add to Cart', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STEP 2: Customer Selection & Discounts
  // ==========================================
  Widget _buildStep2CustomerDiscounts(CartState cart, AsyncValue<List<CustomerModel>> customersAsync) {
    final customers = customersAsync.value ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected Customer Card / Selector
          const Text('Customer Account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.tactileCardDecoration(elevated: true),
            child: Column(
              children: [
                if (cart.selectedCustomer != null) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.pastelMint,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person, color: AppColors.deepMint, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cart.selectedCustomer!.name,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                            ),
                            Text(
                              cart.selectedCustomer!.mobile ?? 'No phone recorded',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            if (cart.selectedCustomer!.balanceDue > 0)
                              Text(
                                'Pending Due: ${Formatters.currency(cart.selectedCustomer!.balanceDue)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.error),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textMuted),
                        onPressed: () => ref.read(cartProvider.notifier).selectCustomer(null),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      const Icon(Icons.person_outline, color: AppColors.textSecondary, size: 24),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Walk-in / Cash Customer',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.person_add, size: 16),
                        label: const Text('New'),
                        onPressed: _showAddCustomerModal,
                      ),
                    ],
                  ),
                ],
                const Divider(height: 20),
                // Customer search autocomplete
                Autocomplete<CustomerModel>(
                  displayStringForOption: (c) => '${c.name} (${c.mobile ?? "No phone"})',
                  optionsBuilder: (textVal) {
                    if (textVal.text.isEmpty) return const Iterable<CustomerModel>.empty();
                    return customers.where((c) =>
                        c.name.toLowerCase().contains(textVal.text.toLowerCase()) ||
                        (c.mobile?.contains(textVal.text) ?? false));
                  },
                  onSelected: (cust) => ref.read(cartProvider.notifier).selectCustomer(cust),
                  fieldViewBuilder: (ctx, ctrl, focus, onSub) {
                    return TextField(
                      controller: ctrl,
                      focusNode: focus,
                      decoration: const InputDecoration(
                        hintText: 'Search customer name or phone...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Discounts Section
          const Text('Discount & Pricing Adjustments', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.tactileCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _discountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Flat Discount (₹)',
                          hintText: '0.00',
                          prefixIcon: Icon(Icons.discount_outlined, size: 18),
                        ),
                        onChanged: (val) {
                          final d = double.tryParse(val) ?? 0.0;
                          ref.read(cartProvider.notifier).setManualDiscount(d);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildDiscountChip('₹0', 0),
                    _buildDiscountChip('5%', cart.subtotal * 0.05),
                    _buildDiscountChip('10%', cart.subtotal * 0.10),
                    _buildDiscountChip('₹50', 50),
                    _buildDiscountChip('₹100', 100),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Step Navigation Controls
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back to Items'),
                onPressed: () => setState(() => _currentStep = 0),
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Proceed to Payment'),
                onPressed: () => setState(() => _currentStep = 2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountChip(String label, double amount) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      backgroundColor: AppColors.surfaceVariant,
      onPressed: () {
        _discountCtrl.text = amount > 0 ? amount.toStringAsFixed(2) : '';
        ref.read(cartProvider.notifier).setManualDiscount(amount);
      },
    );
  }

  // ==========================================
  // STEP 3: Payment Collection & Finalize
  // ==========================================
  Widget _buildStep3PaymentSettlement(CartState cart) {
    final settings = ref.watch(settingsProvider).value ?? AllSettings(
          shop: ShopSettings(),
          billing: BillingSettings(),
          loyalty: LoyaltySettings(),
        );

    final loyaltyRules = ref.watch(loyaltyRulesProvider).value ?? [];
    final loyaltyDiscount = cart.calculateLoyaltyDiscount(settings.loyalty, loyaltyRules);
    final subtotalAfterDiscount = (cart.subtotal - cart.manualDiscount - loyaltyDiscount).clamp(0.0, double.infinity);
    final gstAmount = cart.calculateGst(settings.billing, subtotalAfterDiscount);
    final roundingResult = cart.getRoundingResult(loyaltyDiscount, gstAmount: gstAmount);
    final grandTotal = roundingResult.roundedTotal;

    final cash = double.tryParse(_cashCtrl.text) ?? 0.0;
    final upi = double.tryParse(_upiCtrl.text) ?? 0.0;
    final totalTendered = (_selectedPaymentMode == 'Cash' && cash == 0 && upi == 0) ? grandTotal : (cash + upi);
    final changeDue = (totalTendered - grandTotal).clamp(0.0, double.infinity);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grand Total Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Amount Payable', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${cart.items.length} Items', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  Formatters.currency(grandTotal),
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const Divider(height: 16, color: Colors.white24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal: ${Formatters.currency(cart.subtotal)}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    if (cart.manualDiscount > 0)
                      Text('Discount: -${Formatters.currency(cart.manualDiscount)}', style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11, fontWeight: FontWeight.w700)),
                    if (gstAmount > 0)
                      Text('GST: +${Formatters.currency(gstAmount)}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Payment Mode Selector
          const Text('Select Payment Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildPaymentModeTile('Cash', Icons.money, 'Cash')),
              const SizedBox(width: 8),
              Expanded(child: _buildPaymentModeTile('UPI', Icons.qr_code, 'UPI / QR')),
              const SizedBox(width: 8),
              Expanded(child: _buildPaymentModeTile('Credit', Icons.account_balance_wallet, 'Due (Udhar)')),
            ],
          ),

          const SizedBox(height: 16),

          // Cash Tender Quick Calculator
          if (_selectedPaymentMode == 'Cash' || _selectedPaymentMode == 'Split') ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.tactileCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _cashCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Cash Tendered (₹)',
                      hintText: grandTotal.toStringAsFixed(2),
                      prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                    ),
                    onChanged: (val) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      ActionChip(
                        label: Text('Exact (${Formatters.currency(grandTotal)})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        onPressed: () {
                          _cashCtrl.text = grandTotal.toStringAsFixed(2);
                          setState(() {});
                        },
                      ),
                      _buildTenderChip(100),
                      _buildTenderChip(200),
                      _buildTenderChip(500),
                      _buildTenderChip(2000),
                    ],
                  ),
                  if (changeDue > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.pastelMint,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Change to Return:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.deepMint)),
                          Text(Formatters.currency(changeDue), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.deepMint)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back'),
                onPressed: () => setState(() => _currentStep = 1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryEmerald,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _isProcessing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    _isProcessing ? 'Finalizing...' : 'Complete & Print Bill 🧾',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  onPressed: _isProcessing ? null : _handleCheckout,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentModeTile(String modeKey, IconData icon, String label) {
    final isSelected = _selectedPaymentMode == modeKey;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMode = modeKey),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryEmerald : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.primaryDark : AppColors.textSecondary, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTenderChip(double amount) {
    return ActionChip(
      label: Text('₹${amount.toInt()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.surfaceVariant,
      onPressed: () {
        _cashCtrl.text = amount.toStringAsFixed(2);
        setState(() {});
      },
    );
  }
}
