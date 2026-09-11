import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
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

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  final TextEditingController _customNameCtrl = TextEditingController(text: 'A4 B&W Single');
  final TextEditingController _customQtyCtrl = TextEditingController(text: '1');
  final TextEditingController _customPriceCtrl = TextEditingController(text: '2.00');

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  final TextEditingController _cashCtrl = TextEditingController();
  final TextEditingController _upiCtrl = TextEditingController();

  bool _isProcessing = false;

  @override
  void dispose() {
    _customNameCtrl.dispose();
    _customQtyCtrl.dispose();
    _customPriceCtrl.dispose();
    _searchCtrl.dispose();
    _cashCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  void _addQuickPreset(String name, double price, [double qty = 1.0]) {
    ref.read(cartProvider.notifier).addItem(name, price, qty);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added "$name" to cart'), duration: const Duration(milliseconds: 600)),
    );
  }

  void _addCustomItem() {
    final name = _customNameCtrl.text.trim();
    final qty = double.tryParse(_customQtyCtrl.text) ?? 1.0;
    final price = double.tryParse(_customPriceCtrl.text) ?? 0.0;
    if (name.isEmpty || qty <= 0 || price < 0) return;

    ref.read(cartProvider.notifier).addItem(name, price, qty);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added "$name" ($qty x Rs. $price)'), duration: const Duration(milliseconds: 600)),
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

    final cash = double.tryParse(_cashCtrl.text) ?? 0.0;
    final upi = double.tryParse(_upiCtrl.text) ?? 0.0;
    final advanceUsed = cart.useAdvance ? cart.advanceUsed : 0.0;

    double finalCash = cash;
    double finalUpi = upi;
    if (cash == 0 && upi == 0) {
      final remaining = (roundingResult.roundedTotal - advanceUsed).clamp(0.0, double.infinity);
      finalCash = remaining;
    }

    String paymentMethod = 'Cash';
    if (finalCash > 0 && finalUpi > 0) {
      paymentMethod = 'Split Payment';
    } else if (finalUpi > 0) {
      paymentMethod = 'UPI';
    } else if (advanceUsed > 0 && finalCash == 0) {
      paymentMethod = 'Advance Used';
    }

    setState(() => _isProcessing = true);

    // Calculate dynamic points earned
    double pointsEarned = 0.0;
    if (settings.loyalty.enabled && (finalCash + finalUpi + advanceUsed) >= roundingResult.roundedTotal - 0.01) {
      pointsEarned = await ApiRepository.calculateLoyaltyPointsEarned(roundingResult.roundedTotal);
    }

    BillModel? newBill = await ApiRepository.createBill(
      customerId: cart.selectedCustomer?.id,
      total: cart.subtotal,
      discount: cart.manualDiscount + loyaltyDiscount,
      gstAmount: gstAmount,
      roundingMethod: cart.roundingMethod,
      roundingAdjustment: roundingResult.roundingAdjustment,
      grandTotal: roundingResult.roundedTotal,
      cashPaid: finalCash,
      upiPaid: finalUpi,
      advanceUsed: advanceUsed,
      advanceEarned: 0.0,
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
          'grand_total': roundingResult.roundedTotal,
          'cash_paid': finalCash,
          'upi_paid': finalUpi,
          'paid_total': finalCash + finalUpi + advanceUsed,
          'advance_used': advanceUsed,
          'advance_earned': 0.0,
          'payment_method': paymentMethod,
          'loyalty_points_earned': pointsEarned,
          'loyalty_points_redeemed': cart.pointsToRedeem,
          'client_ref': clientRef,
        },
        'itemsPayload': cart.items.map((it) => it.toJson()).toList(),
      };

      await SyncQueueManager.instance.enqueueTask('create_bill', billPayload, clientRef: clientRef);

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
        grandTotal: roundingResult.roundedTotal,
        cashPaid: finalCash,
        upiPaid: finalUpi,
        paidTotal: finalCash + finalUpi + advanceUsed,
        advanceUsed: advanceUsed,
        advanceEarned: 0.0,
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

      _showSuccessDialog(newBill);
      ref.read(cartProvider.notifier).reset();
      _cashCtrl.clear();
      _upiCtrl.clear();
    }
  }

  void _showSuccessDialog(BillModel bill) {
    final settings = ref.read(settingsProvider).value ?? AllSettings(
          shop: ShopSettings(),
          billing: BillingSettings(),
          loyalty: LoyaltySettings(),
        );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 28),
            const SizedBox(width: 8),
            Text(bill.billNumber.startsWith('OFFLINE') ? 'Bill Queued (Offline)' : 'Bill Generated!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invoice #: ${bill.billNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Grand Total: ${Formatters.currency(bill.grandTotal)} (${bill.paymentMethod})'),
            if (bill.customerName != null)
              Text('Customer: ${bill.customerName} (${bill.customerMobile ?? "-"})',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            if (bill.loyaltyPointsEarned > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Points Earned: +${bill.loyaltyPointsEarned.toStringAsFixed(0)} pts',
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 16),
            const Text('Share & Print Options:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
            icon: const Icon(Icons.chat, size: 16),
            label: const Text('WhatsApp Invoice'),
            onPressed: () async {
              await ReceiptGenerator.shareViaWhatsApp(bill: bill, shop: settings.shop, billing: settings.billing);
            },
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.description, size: 16),
            label: const Text('A4 Invoice'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ReceiptGenerator.printReceipt(
                bill: bill,
                shop: settings.shop,
                billing: settings.billing,
                forceA4: true,
              );
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ReceiptGenerator.printReceipt(
                bill: bill,
                shop: settings.shop,
                billing: settings.billing,
              );
            },
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print 80mm POS'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final customersAsync = ref.watch(customerSummariesProvider);
    final productsAsync = ref.watch(productsProvider);
    final settingsAsync = ref.watch(settingsProvider);

    final settings = settingsAsync.value ?? AllSettings(
          shop: ShopSettings(),
          billing: BillingSettings(),
          loyalty: LoyaltySettings(),
        );

    final loyaltyRules = ref.watch(loyaltyRulesProvider).value ?? [];
    final loyaltyDiscount = cart.calculateLoyaltyDiscount(settings.loyalty, loyaltyRules);
    final subtotalAfterDisc = (cart.subtotal - cart.manualDiscount - loyaltyDiscount).clamp(0.0, double.infinity);
    final gstAmount = cart.calculateGst(settings.billing, subtotalAfterDisc);
    final roundingResult = cart.getRoundingResult(loyaltyDiscount, gstAmount: gstAmount);

    final products = productsAsync.value ?? [];
    final customers = customersAsync.value ?? [];

    final filteredProducts = products.where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (p.productCode != null && p.productCode!.toLowerCase().contains(_searchQuery.toLowerCase())) ||
          p.category.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('POS Billing Counter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
            tooltip: 'Barcode & QR Scanner',
            onPressed: () => _openBarcodeScanner(products, customers),
          ),
          if (cart.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: AppColors.error),
              tooltip: 'Clear Cart',
              onPressed: () => ref.read(cartProvider.notifier).reset(),
            ),
        ],
      ),
      body: Row(
        children: [
          // Left Panel: Quick Presets & Products Catalog
          Expanded(
            flex: 6,
            child: Column(
              children: [
                // Top Customer Selection Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: Colors.white,
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: AppColors.primary, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: const Text('Select Customer (Walk-in)'),
                            value: cart.selectedCustomer?.id,
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Walk-in Customer', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              ...customers.map((c) => DropdownMenuItem<String>(
                                    value: c.id,
                                    child: Row(
                                      children: [
                                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        if (c.balanceDue > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 6),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4)),
                                              child: Text('Due: Rs.${c.balanceDue.toStringAsFixed(0)}',
                                                  style: const TextStyle(color: AppColors.error, fontSize: 11)),
                                            ),
                                          ),
                                        if (c.advanceBalance > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 6),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(4)),
                                              child: Text('Adv: Rs.${c.advanceBalance.toStringAsFixed(0)}',
                                                  style: const TextStyle(color: AppColors.success, fontSize: 11)),
                                            ),
                                          ),
                                      ],
                                    ),
                                  )),
                            ],
                            onChanged: (val) {
                              if (val == null) {
                                ref.read(cartProvider.notifier).selectCustomer(null);
                              } else {
                                final selected = customers.firstWhere((c) => c.id == val);
                                ref.read(cartProvider.notifier).selectCustomer(selected);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search stationery or services...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),

                // Quick Xerox / Print Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      _buildPresetChip('A4 B&W Single', 2.00),
                      const SizedBox(width: 6),
                      _buildPresetChip('A4 B&W B2B', 3.00),
                      const SizedBox(width: 6),
                      _buildPresetChip('A4 Color', 10.00),
                      const SizedBox(width: 6),
                      _buildPresetChip('Spiral Binding', 40.00),
                      const SizedBox(width: 6),
                      _buildPresetChip('Lamination', 30.00),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Custom Job Entry Box
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Card(
                    elevation: 0.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: TextField(
                              controller: _customNameCtrl,
                              decoration: const InputDecoration(labelText: 'Custom Service', isDense: true, border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _customQtyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Qty', isDense: true, border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _customPriceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Rate', isDense: true, border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 28),
                            onPressed: _addCustomItem,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Products Grid / List
                Expanded(
                  child: productsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('Error loading products: $err')),
                    data: (prods) {
                      if (filteredProducts.isEmpty) {
                        return const Center(child: Text('No matching products found'));
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: filteredProducts.length,
                        itemBuilder: (ctx, i) {
                          final p = filteredProducts[i];
                          return InkWell(
                            onTap: () => ref.read(cartProvider.notifier).addItem(p.name, p.price, 1, productId: p.id),
                            child: Card(
                              elevation: 0.5,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(p.category, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                        Text(Formatters.currency(p.price), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Right Panel: Active Cart & Total Breakdown
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(left: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  // Cart Header
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: AppColors.surfaceVariant,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shopping_cart, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text('Cart (${cart.items.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        if (cart.selectedCustomer != null)
                          Text('Customer: ${cart.selectedCustomer!.name}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.primary)),
                      ],
                    ),
                  ),

                  // Cart Items List
                  Expanded(
                    child: cart.items.isEmpty
                        ? const Center(
                            child: Text('Cart is empty\nTap items or scan barcode to add', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(8),
                            itemCount: cart.items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, idx) {
                              final item = cart.items[idx];
                              return Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        Text('Rs.${item.price.toStringAsFixed(2)} each', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                                        onPressed: () => ref.read(cartProvider.notifier).updateItemQuantity(idx, item.quantity - 1),
                                      ),
                                      Text(item.quantity.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, size: 18),
                                        onPressed: () => ref.read(cartProvider.notifier).updateItemQuantity(idx, item.quantity + 1),
                                      ),
                                    ],
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      Formatters.currency(item.total),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                                    onPressed: () => ref.read(cartProvider.notifier).removeItem(idx),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),

                  // Bottom Summary & Checkout Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceVariant,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal:'),
                            Text(Formatters.currency(cart.subtotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        if (cart.manualDiscount > 0 || loyaltyDiscount > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Discount (Manual + Loyalty):', style: TextStyle(color: AppColors.error)),
                              Text('- ${Formatters.currency(cart.manualDiscount + loyaltyDiscount)}',
                                  style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                        if (gstAmount > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('GST Tax (${settings.billing.gstRate}%):'),
                              Text('+ ${Formatters.currency(gstAmount)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                        if (roundingResult.roundingAdjustment != 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Rounding:'),
                              Text(Formatters.currency(roundingResult.roundingAdjustment)),
                            ],
                          ),
                        ],
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('GRAND TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(
                              Formatters.currency(roundingResult.roundedTotal),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: AppColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Split Payment Inputs
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _cashCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Cash Paid (Rs.)', isDense: true, border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _upiCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'UPI Paid (Rs.)', isDense: true, border: OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Checkout Button
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _isProcessing ? null : _handleCheckout,
                            icon: _isProcessing
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.receipt_long),
                            label: Text(
                              _isProcessing ? 'Generating...' : 'Complete & Generate Bill',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String title, double price) {
    return ActionChip(
      avatar: const Icon(Icons.print, size: 16, color: AppColors.primary),
      label: Text('$title (Rs.$price)'),
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.border),
      onPressed: () => _addQuickPreset(title, price),
    );
  }
}
