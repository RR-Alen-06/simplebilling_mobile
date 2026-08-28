import 'package:uuid/uuid.dart';
import 'package:simplebilling_mobile/core/network/sync_queue_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';
import 'package:simplebilling_mobile/presentation/shared/printing/receipt_generator.dart';

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

  void _addQuickPreset(String name, double price) {
    ref.read(cartProvider.notifier).addItem(name, price, 1);
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
      SnackBar(content: Text('Added "$name" ($qty x â‚¹$price)'), duration: const Duration(milliseconds: 600)),
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

    final settingsAsync = ref.read(settingsProvider);
    final settings = settingsAsync.value;
    final loyaltyRules = ref.read(loyaltyRulesProvider).value ?? [];

    final loyaltyDiscount = settings != null
        ? cart.calculateLoyaltyDiscount(settings.loyalty, loyaltyRules)
        : 0.0;
    final roundingResult = cart.getRoundingResult(loyaltyDiscount);

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

    final newBill = await ApiRepository.createBill(
      customerId: cart.selectedCustomer?.id,
      total: cart.subtotal,
      discount: cart.manualDiscount + loyaltyDiscount,
      roundingMethod: cart.roundingMethod,
      roundingAdjustment: roundingResult.roundingAdjustment,
      grandTotal: roundingResult.roundedTotal,
      cashPaid: finalCash,
      upiPaid: finalUpi,
      advanceUsed: advanceUsed,
      advanceEarned: 0.0,
      paymentMethod: paymentMethod,
      loyaltyPointsEarned: (roundingResult.roundedTotal / 100).floorToDouble(),
      loyaltyPointsRedeemed: cart.pointsToRedeem,
      items: cart.items,
    );

    setState(() => _isProcessing = false);

    if (newBill != null && mounted) {
      ref.invalidate(billsListProvider);
      ref.invalidate(customersProvider);

      _showSuccessDialog(newBill);
      ref.read(cartProvider.notifier).reset();
      _cashCtrl.clear();
      _upiCtrl.clear();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate bill. Please try again.')),
      );
    }
  }

  void _showSuccessDialog(BillModel bill) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 28),
            SizedBox(width: 8),
            Text('Bill Generated!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invoice #: ${bill.billNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Grand Total: ${Formatters.currency(bill.grandTotal)}'),
            Text('Paid: ${Formatters.currency(bill.paidTotal)} (${bill.paymentMethod})'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final settings = ref.read(settingsProvider).value;
              await ReceiptGenerator.printReceipt(
                bill: bill,
                shop: settings?.shop ?? ShopSettings(),
                billing: settings?.billing ?? BillingSettings(),
              );
            },
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Print Receipt'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final customersAsync = ref.watch(customersProvider);
    final productsAsync = ref.watch(productsProvider);
    final settingsAsync = ref.watch(settingsProvider);

    final settings = settingsAsync.value;
    final loyaltyRules = ref.watch(loyaltyRulesProvider).value ?? [];
    final loyaltyDiscount = settings != null
        ? cart.calculateLoyaltyDiscount(settings.loyalty, loyaltyRules)
        : 0.0;
    final roundingResult = cart.getRoundingResult(loyaltyDiscount);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('POS Billing & Xerox', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Clear Cart',
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: () => ref.read(cartProvider.notifier).reset(),
          ),
        ],
      ),
      body: Row(
        children: [
          // Left Side: Catalog & Xerox Quick Presets
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Picker Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              if (cart.selectedCustomer != null)
                                TextButton(
                                  onPressed: () => ref.read(cartProvider.notifier).selectCustomer(null),
                                  child: const Text('Remove', style: TextStyle(color: AppColors.error, fontSize: 12)),
                                ),
                            ],
                          ),
                          customersAsync.when(
                            data: (customers) => DropdownButtonFormField<String>(
                              initialValue: cart.selectedCustomer?.id,
                              decoration: InputDecoration(
                                hintText: 'Select or Search Customer (Walk-in)',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Walk-in Customer')),
                                ...customers.map((c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text('${c.name} (${c.mobile ?? 'No Mobile'})'),
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
                            loading: () => const LinearProgressIndicator(),
                            error: (e, s) => const Text('Failed to load customers'),
                          ),
                          if (cart.selectedCustomer != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Chip(
                                  avatar: const Icon(Icons.account_balance_wallet, size: 16, color: AppColors.secondary),
                                  label: Text('Advance: ${Formatters.currency(cart.selectedCustomer!.advanceBalance)}'),
                                  backgroundColor: AppColors.surfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Chip(
                                  avatar: const Icon(Icons.stars, size: 16, color: AppColors.accent),
                                  label: Text('Loyalty: ${cart.selectedCustomer!.loyaltyPoints.toStringAsFixed(0)} pts'),
                                  backgroundColor: AppColors.surfaceVariant,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick Xerox Presets Grid
                  const Text('âš¡ Xerox & Quick Presets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPresetChip('A4 B&W Single', 2.00),
                      _buildPresetChip('A4 B&W Both', 3.00),
                      _buildPresetChip('A4 Color Single', 10.00),
                      _buildPresetChip('A4 Color Both', 18.00),
                      _buildPresetChip('Lamination A4', 20.00),
                      _buildPresetChip('Spiral Binding', 35.00),
                      _buildPresetChip('Passport Photo (8)', 50.00),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Custom Item Entry Row
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Custom Print / Job', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: TextField(
                                  controller: _customNameCtrl,
                                  decoration: const InputDecoration(labelText: 'Description', isDense: true, border: OutlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _customQtyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Qty', isDense: true, border: OutlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _customPriceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Rate (â‚¹)', isDense: true, border: OutlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                onPressed: _addCustomItem,
                                child: const Text('Add'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Products Catalog Search & List
                  const Text('ðŸ“¦ Stationery & Products Catalog', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search products by name or category...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  ),
                  const SizedBox(height: 8),
                  productsAsync.when(
                    data: (prods) {
                      final filtered = prods.where((p) =>
                          p.name.toLowerCase().contains(_searchQuery) ||
                          p.category.toLowerCase().contains(_searchQuery)).toList();
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final item = filtered[idx];
                          return ListTile(
                            dense: true,
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(item.category),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(Formatters.currency(item.price), style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.add_circle, color: AppColors.primary),
                                  onPressed: () => ref.read(cartProvider.notifier).addItem(item.name, item.price, 1, productId: item.id),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => const Text('Error loading products'),
                  ),
                ],
              ),
            ),
          ),

          // Right Side: Cart Summary & Checkout Bar
          Expanded(
            flex: 4,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(left: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Bill Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Chip(
                          label: Text('${cart.items.length} items'),
                          backgroundColor: AppColors.surfaceVariant,
                        ),
                      ],
                    ),
                  ),

                  // Cart Items
                  Expanded(
                    child: cart.items.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shopping_cart_outlined, size: 48, color: AppColors.textMuted),
                                SizedBox(height: 8),
                                Text('Cart is empty', style: TextStyle(color: AppColors.textSecondary)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: cart.items.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
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
                                        Text('â‚¹${item.price.toStringAsFixed(2)} each', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
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

                  // Bottom Calculation & Checkout Section
                  Container(
                    padding: const EdgeInsets.all(16),
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
                        if (cart.manualDiscount > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Discount:', style: TextStyle(color: AppColors.error)),
                              Text('- ${Formatters.currency(cart.manualDiscount)}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
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
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('GRAND TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(
                              Formatters.currency(roundingResult.roundedTotal),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Split Payment Quick Input
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _cashCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Cash Paid (â‚¹)', isDense: true, border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _upiCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'UPI Paid (â‚¹)', isDense: true, border: OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Checkout Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
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
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
      label: Text('$title (â‚¹$price)'),
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.border),
      onPressed: () => _addQuickPreset(title, price),
    );
  }
}
