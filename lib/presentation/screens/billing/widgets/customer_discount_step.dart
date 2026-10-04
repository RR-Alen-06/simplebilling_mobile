import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/constants/app_theme.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

class CustomerDiscountStep extends StatelessWidget {
  final CartState cart;
  final List<CustomerModel> customers;
  final TextEditingController percentDiscountCtrl;
  final TextEditingController flatDiscountCtrl;
  final VoidCallback onAddCustomer;
  final void Function(CustomerModel customer, LoyaltySettings settings, List<LoyaltyRedemptionRule> rules) onRedeemLoyalty;
  final VoidCallback onBackToItems;
  final VoidCallback onProceedToPayment;
  final WidgetRef ref;

  const CustomerDiscountStep({
    super.key,
    required this.cart,
    required this.customers,
    required this.percentDiscountCtrl,
    required this.flatDiscountCtrl,
    required this.onAddCustomer,
    required this.onRedeemLoyalty,
    required this.onBackToItems,
    required this.onProceedToPayment,
    required this.ref,
  });

  Widget _buildPercentChip(String label, double percent) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      backgroundColor: AppColors.surfaceVariant,
      visualDensity: VisualDensity.compact,
      onPressed: () {
        percentDiscountCtrl.text = percent > 0 ? (percent % 1 == 0 ? percent.toInt().toString() : percent.toString()) : '';
        ref.read(cartProvider.notifier).setPercentageDiscount(percent);
      },
    );
  }

  Widget _buildFlatChip(String label, double amount) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      backgroundColor: AppColors.surfaceVariant,
      visualDensity: VisualDensity.compact,
      onPressed: () {
        flatDiscountCtrl.text = amount > 0 ? (amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(2)) : '';
        ref.read(cartProvider.notifier).setFlatDiscount(amount);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value ?? AllSettings(
          shop: ShopSettings(),
          billing: BillingSettings(),
          loyalty: LoyaltySettings(),
        );
    final loyaltyRules = ref.watch(loyaltyRulesProvider).value ?? [];
    final loyaltyDiscount = cart.calculateLoyaltyDiscount(settings.loyalty, loyaltyRules);

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
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textMuted),
                        onPressed: () => ref.read(cartProvider.notifier).selectCustomer(null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Badges: Pending Due, Loyalty Balance, Advance Wallet
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (cart.selectedCustomer!.balanceDue > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFDC2626)),
                              const SizedBox(width: 4),
                              Text(
                                'Pending Due: ${Formatters.currency(cart.selectedCustomer!.balanceDue)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.stars_rounded, size: 13, color: Color(0xFF7C3AED)),
                            const SizedBox(width: 4),
                            Text(
                              'Loyalty: ${cart.selectedCustomer!.loyaltyPoints.toInt()} pts',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6D28D9)),
                            ),
                          ],
                        ),
                      ),
                      if (cart.selectedCustomer!.advanceBalance > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.pastelMint,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.borderMint),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined, size: 13, color: AppColors.deepMint),
                              const SizedBox(width: 4),
                              Text(
                                'Advance: ${Formatters.currency(cart.selectedCustomer!.advanceBalance)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.deepMint),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (cart.selectedCustomer!.loyaltyPoints > 0 && settings.loyalty.enabled) ...[
                    const SizedBox(height: 10),
                    if (cart.pointsToRedeem > 0)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.pastelMint,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderMint),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.stars_rounded, color: AppColors.deepMint, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Redeeming ${cart.pointsToRedeem.toInt()} pts (-₹${loyaltyDiscount.toStringAsFixed(2)})',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.deepMint),
                                  ),
                                  const Text(
                                    'Loyalty discount applied to bill',
                                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                              ),
                              onPressed: () => onRedeemLoyalty(cart.selectedCustomer!, settings.loyalty, loyaltyRules),
                              child: const Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                              onPressed: () => ref.read(cartProvider.notifier).clearPointsToRedeem(),
                            ),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6D28D9),
                            side: const BorderSide(color: Color(0xFFC4B5FD)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.stars_rounded, size: 18),
                          label: Text(
                            'Redeem Loyalty Points (${cart.selectedCustomer!.loyaltyPoints.toInt()} Available)',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                          onPressed: () => onRedeemLoyalty(cart.selectedCustomer!, settings.loyalty, loyaltyRules),
                        ),
                      ),
                  ],
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
                        onPressed: onAddCustomer,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Discount & Pricing Adjustments', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              if (cart.percentageDiscount > 0 || cart.flatDiscount > 0)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  icon: const Icon(Icons.clear, size: 14),
                  label: const Text('Clear All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  onPressed: () {
                    percentDiscountCtrl.clear();
                    flatDiscountCtrl.clear();
                    ref.read(cartProvider.notifier).clearDiscounts();
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.tactileCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Percentage Discount Field
                Row(
                  children: [
                    const Icon(Icons.percent_rounded, size: 18, color: AppColors.primaryEmerald),
                    const SizedBox(width: 8),
                    const Text('Percentage Discount (%)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const Spacer(),
                    if (cart.percentageDiscount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '= -${Formatters.currency(cart.percentDiscountAmount)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: percentDiscountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'e.g. 10 (for 10% off)',
                    prefixIcon: const Icon(Icons.discount_outlined, size: 18),
                    suffixText: '%',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: percentDiscountCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              percentDiscountCtrl.clear();
                              ref.read(cartProvider.notifier).setPercentageDiscount(0.0);
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    final p = double.tryParse(val) ?? 0.0;
                    if (p > 100) {
                      percentDiscountCtrl.text = '100';
                      percentDiscountCtrl.selection = const TextSelection.collapsed(offset: 3);
                      ref.read(cartProvider.notifier).setPercentageDiscount(100.0);
                    } else {
                      ref.read(cartProvider.notifier).setPercentageDiscount(p);
                    }
                  },
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    _buildPercentChip('0%', 0),
                    _buildPercentChip('5%', 5),
                    _buildPercentChip('10%', 10),
                    _buildPercentChip('15%', 15),
                    _buildPercentChip('20%', 20),
                  ],
                ),

                const Divider(height: 24),

                // 2. Flat Discount Field
                Row(
                  children: [
                    const Icon(Icons.currency_rupee, size: 18, color: AppColors.primaryEmerald),
                    const SizedBox(width: 8),
                    const Text('Flat Discount (₹)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const Spacer(),
                    if (cart.flatDiscount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '= -${Formatters.currency(cart.flatDiscount)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: flatDiscountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    prefixIcon: const Icon(Icons.money_off_csred_outlined, size: 18),
                    prefixText: '₹ ',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: flatDiscountCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              flatDiscountCtrl.clear();
                              ref.read(cartProvider.notifier).setFlatDiscount(0.0);
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    final d = double.tryParse(val) ?? 0.0;
                    ref.read(cartProvider.notifier).setFlatDiscount(d);
                  },
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    _buildFlatChip('₹0', 0),
                    _buildFlatChip('₹20', 20),
                    _buildFlatChip('₹50', 50),
                    _buildFlatChip('₹100', 100),
                    _buildFlatChip('₹200', 200),
                  ],
                ),

                if (cart.manualDiscount > 0) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.pastelMint,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderMint),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: AppColors.deepMint, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Discount Applied: ${Formatters.currency(cart.manualDiscount)}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.deepMint),
                              ),
                              Text(
                                '${cart.percentageDiscount > 0 ? "${cart.percentageDiscount.toStringAsFixed(0)}% (${Formatters.currency(cart.percentDiscountAmount)})" : ""}'
                                '${cart.percentageDiscount > 0 && cart.flatDiscount > 0 ? " + " : ""}'
                                '${cart.flatDiscount > 0 ? "${Formatters.currency(cart.flatDiscount)} flat" : ""}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Net: ${Formatters.currency((cart.subtotal - cart.manualDiscount).clamp(0.0, double.infinity))}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
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
                onPressed: onBackToItems,
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryEmerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Proceed to Payment', style: TextStyle(fontWeight: FontWeight.w800)),
                onPressed: onProceedToPayment,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
