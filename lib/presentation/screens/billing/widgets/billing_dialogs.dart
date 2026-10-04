import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

class BillingDialogs {
  const BillingDialogs._();

  static void showEditQuantityDialog({
    required BuildContext context,
    required WidgetRef ref,
    required int itemIndex,
    required BillItemModel item,
  }) {
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
              if (newQty == null || newQty < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid quantity (0 or greater)'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              ref.read(cartProvider.notifier).updateItemQuantity(itemIndex, newQty);
              Navigator.of(ctx).pop();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  static void showEditPriceDialog({
    required BuildContext context,
    required WidgetRef ref,
    required int itemIndex,
    required BillItemModel item,
  }) {
    final priceCtrl = TextEditingController(
      text: item.price % 1 == 0 ? item.price.toInt().toString() : item.price.toStringAsFixed(2),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.sell_rounded, color: AppColors.deepAmber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Custom Price: ${item.productName}',
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
              'Override the unit selling price for this specific bill.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Unit Price (₹)',
                hintText: 'e.g. 1.50',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                  label: const Text('₹1.50', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => priceCtrl.text = '1.50',
                  visualDensity: VisualDensity.compact,
                ),
                ActionChip(
                  label: const Text('₹2.00', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => priceCtrl.text = '2.00',
                  visualDensity: VisualDensity.compact,
                ),
                ActionChip(
                  label: const Text('₹3.00', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => priceCtrl.text = '3.00',
                  visualDensity: VisualDensity.compact,
                ),
                ActionChip(
                  label: const Text('₹5.00', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => priceCtrl.text = '5.00',
                  visualDensity: VisualDensity.compact,
                ),
              ],
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
              backgroundColor: AppColors.deepAmber,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final newPrice = double.tryParse(priceCtrl.text.trim());
              if (newPrice == null || newPrice < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid price (0 or greater)'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              ref.read(cartProvider.notifier).updateItemPrice(itemIndex, newPrice);
              Navigator.of(ctx).pop();
            },
            child: const Text('Apply Price'),
          ),
        ],
      ),
    );
  }

  static void showRedeemLoyaltyDialog({
    required BuildContext context,
    required WidgetRef ref,
    required CustomerModel customer,
    required LoyaltySettings settings,
    required List<LoyaltyRedemptionRule> rules,
  }) {
    final pts = customer.loyaltyPoints;
    final ptsCtrl = TextEditingController(
      text: pts % 1 == 0 ? pts.toInt().toString() : pts.toString(),
    );

    final applicableRules = rules.where((r) => r.enabled && r.pointsRequired <= pts).toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final enteredPts = double.tryParse(ptsCtrl.text.trim()) ?? 0.0;
          final estDiscount = ApiRepository.calculateLoyaltyDiscount(
            enteredPts.clamp(0.0, pts),
            settings,
            rules,
          );

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: AppColors.deepAmber, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Redeem Points: ${customer.name}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          Text(
                            'Available Balance: ${pts.toInt()} Points',
                            style: const TextStyle(fontSize: 12, color: AppColors.deepAmber, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ptsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Points to Redeem',
                    hintText: 'Enter points',
                    prefixIcon: const Icon(Icons.stars_outlined),
                    suffixText: 'Max ${pts.toInt()}',
                  ),
                  onChanged: (val) => setModalState(() {}),
                ),
                const SizedBox(height: 10),
                if (applicableRules.isNotEmpty) ...[
                  const Text('Quick Rewards:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: applicableRules.map((rule) {
                      return ActionChip(
                        avatar: const Icon(Icons.stars, size: 14, color: AppColors.deepAmber),
                        label: Text('${rule.pointsRequired.toInt()} pts = ₹${rule.discountAmount.toInt()} off'),
                        onPressed: () {
                          ptsCtrl.text = rule.pointsRequired.toInt().toString();
                          setModalState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.pastelMint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Estimated Discount:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.deepMint)),
                      Text('₹${estDiscount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.deepMint)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryEmerald,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      final entered = double.tryParse(ptsCtrl.text.trim()) ?? 0.0;
                      final validPts = entered.clamp(0.0, customer.loyaltyPoints);
                      ref.read(cartProvider.notifier).setPointsToRedeem(validPts);
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Apply Discount', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static void showAddCustomerModal({
    required BuildContext context,
    required WidgetRef ref,
  }) {
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
              if (!context.mounted) return;
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

  static void showCustomItemSheet({
    required BuildContext context,
    required WidgetRef ref,
    required TextEditingController customNameCtrl,
    required TextEditingController customQtyCtrl,
    required TextEditingController customPriceCtrl,
    required bool Function(String name, double? qty, double? price) onAddCustomItem,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.add_shopping_cart, color: AppColors.primaryEmerald),
                const SizedBox(width: 8),
                const Text(
                  'Add Custom / Xerox Item',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: customNameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Item Name or Service *',
                hintText: 'e.g. A4 Xerox B&W, Spiral Binding, Stamp...',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: customQtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Quantity *',
                      hintText: '1',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: customPriceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Unit Price (₹) *',
                      hintText: '2.00',
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.flash_on, size: 14, color: AppColors.primaryEmerald),
                  label: const Text('A4 B&W (₹2.00)'),
                  onPressed: () {
                    customNameCtrl.text = 'A4 B&W Xerox';
                    customPriceCtrl.text = '2.00';
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.flash_on, size: 14, color: AppColors.secondaryIndigo),
                  label: const Text('A4 Color (₹10.00)'),
                  onPressed: () {
                    customNameCtrl.text = 'A4 Color Print';
                    customPriceCtrl.text = '10.00';
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.flash_on, size: 14, color: AppColors.deepAmber),
                  label: const Text('Lamination (₹25.00)'),
                  onPressed: () {
                    customNameCtrl.text = 'A4 Lamination';
                    customPriceCtrl.text = '25.00';
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.flash_on, size: 14, color: AppColors.primaryEmerald),
                  label: const Text('Spiral (₹40.00)'),
                  onPressed: () {
                    customNameCtrl.text = 'Spiral Binding';
                    customPriceCtrl.text = '40.00';
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryEmerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Add to Cart', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                onPressed: () {
                  final added = onAddCustomItem(
                    customNameCtrl.text.trim(),
                    double.tryParse(customQtyCtrl.text.trim()),
                    double.tryParse(customPriceCtrl.text.trim()),
                  );
                  if (added) {
                    Navigator.of(ctx).pop();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
