import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/constants/app_theme.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

class PaymentSettlementStep extends StatelessWidget {
  final CartState cart;
  final String selectedPaymentMode;
  final ValueChanged<String> onPaymentModeChanged;
  final TextEditingController cashCtrl;
  final TextEditingController upiCtrl;
  final bool isProcessing;
  final VoidCallback onBackToDiscounts;
  final VoidCallback onCheckout;
  final VoidCallback onStateChanged;
  final WidgetRef ref;

  const PaymentSettlementStep({
    super.key,
    required this.cart,
    required this.selectedPaymentMode,
    required this.onPaymentModeChanged,
    required this.cashCtrl,
    required this.upiCtrl,
    required this.isProcessing,
    required this.onBackToDiscounts,
    required this.onCheckout,
    required this.onStateChanged,
    required this.ref,
  });

  Widget _buildPaymentModeTile(String modeKey, IconData icon, String label) {
    final isSelected = selectedPaymentMode == modeKey;
    return InkWell(
      onTap: () => onPaymentModeChanged(modeKey),
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
        cashCtrl.text = amount.toStringAsFixed(2);
        onStateChanged();
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
    final subtotalAfterDiscount = (cart.subtotal - cart.manualDiscount - loyaltyDiscount).clamp(0.0, double.infinity);
    final gstAmount = cart.calculateGst(settings.billing, subtotalAfterDiscount);
    final roundingResult = cart.getRoundingResult(loyaltyDiscount, gstAmount: gstAmount);
    final grandTotal = roundingResult.roundedTotal;

    final cash = double.tryParse(cashCtrl.text) ?? 0.0;
    final upi = double.tryParse(upiCtrl.text) ?? 0.0;
    final totalTendered = (selectedPaymentMode == 'Cash' && cash == 0 && upi == 0) ? grandTotal : (cash + upi);
    final changeDue = (totalTendered - grandTotal).clamp(0.0, double.infinity);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer Overview Banner in Step 3
          if (cart.selectedCustomer != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.pastelMint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person, color: AppColors.deepMint, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cart.selectedCustomer!.name,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Loyalty: ${cart.selectedCustomer!.loyaltyPoints.toInt()} pts${cart.pointsToRedeem > 0 ? " (${cart.pointsToRedeem.toInt()} redeemed)" : ""}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6D28D9), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  if (cart.selectedCustomer!.balanceDue > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Pending Due', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                          Text(
                            Formatters.currency(cart.selectedCustomer!.balanceDue),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

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
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text('Subtotal: ${Formatters.currency(cart.subtotal)}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    if (cart.manualDiscount > 0)
                      Text('Discount: -${Formatters.currency(cart.manualDiscount)}', style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11, fontWeight: FontWeight.w700)),
                    if (loyaltyDiscount > 0)
                      Text('Loyalty: -${Formatters.currency(loyaltyDiscount)}', style: const TextStyle(color: Color(0xFFC4B5FD), fontSize: 11, fontWeight: FontWeight.w700)),
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
          if (selectedPaymentMode == 'Cash' || selectedPaymentMode == 'Split') ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.tactileCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: cashCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Cash Tendered (₹)',
                      hintText: grandTotal.toStringAsFixed(2),
                      prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                    ),
                    onChanged: (val) => onStateChanged(),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      ActionChip(
                        label: Text('Exact (${Formatters.currency(grandTotal)})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        onPressed: () {
                          cashCtrl.text = grandTotal.toStringAsFixed(2);
                          onStateChanged();
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
                onPressed: onBackToDiscounts,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryEmerald,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: isProcessing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    isProcessing ? 'Finalizing...' : 'Complete & Print Bill 🧾',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  onPressed: isProcessing ? null : onCheckout,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
