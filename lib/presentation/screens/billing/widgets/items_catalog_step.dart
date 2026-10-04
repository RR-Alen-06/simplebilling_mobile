import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/constants/app_theme.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/product_model.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

class ItemsCatalogStep extends StatelessWidget {
  final CartState cart;
  final List<ProductModel> products;
  final TextEditingController searchCtrl;
  final String searchQuery;
  final String selectedCategory;
  final bool isCartExpanded;
  final VoidCallback onToggleCartExpand;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onShowCustomItem;
  final void Function(String name, double price) onAddQuickPreset;
  final VoidCallback onProceedToCustomer;
  final void Function(int itemIndex, BillItemModel item) onEditQuantity;
  final void Function(int itemIndex, BillItemModel item) onEditPrice;
  final WidgetRef ref;

  const ItemsCatalogStep({
    super.key,
    required this.cart,
    required this.products,
    required this.searchCtrl,
    required this.searchQuery,
    required this.selectedCategory,
    required this.isCartExpanded,
    required this.onToggleCartExpand,
    required this.onCategorySelected,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onShowCustomItem,
    required this.onAddQuickPreset,
    required this.onProceedToCustomer,
    required this.onEditQuantity,
    required this.onEditPrice,
    required this.ref,
  });

  Widget _buildPresetCard(String title, String price, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              price,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppColors.primaryEmerald),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingDock() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderMint, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${cart.items.length} Items in Cart',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                Text(
                  Formatters.currency(cart.subtotal),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryEmerald),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryEmerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Next: Customer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            onPressed: onProceedToCustomer,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...{for (var p in products) p.category}];

    final filteredProducts = products.where((p) {
      final matchesCat = selectedCategory == 'All' || p.category == selectedCategory;
      final matchesSearch = searchQuery.isEmpty ||
          p.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          (p.productCode?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false);
      return matchesCat && matchesSearch;
    }).toList();

    return Stack(
      children: [
        Column(
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
                      onTap: onToggleCartExpand,
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
                              isCartExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isCartExpanded) ...[
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
                                ? products.where((p) => p.id == item.productId).firstOrNull
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
                                          InkWell(
                                            onTap: () => onEditPrice(itemIdx, item),
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
                                    InkWell(
                                      onTap: () => onEditQuantity(itemIdx, item),
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
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search products or scan SKU...',
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                        suffixIcon: searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: onClearSearch,
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      ),
                      onChanged: onSearchChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onShowCustomItem,
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
                  final isSelected = selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                    selected: isSelected,
                    selectedColor: AppColors.primaryContainer,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: isSelected ? AppColors.primaryEmerald : AppColors.border),
                    onSelected: (sel) => onCategorySelected(cat),
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
                  Expanded(child: _buildPresetCard('A4 B&W', '₹2.00', () => onAddQuickPreset('A4 B&W Xerox', 2.0))),
                  const SizedBox(width: 6),
                  Expanded(child: _buildPresetCard('A4 Color', '₹10.00', () => onAddQuickPreset('A4 Color Xerox', 10.0))),
                  const SizedBox(width: 6),
                  Expanded(child: _buildPresetCard('Spiral', '₹40.00', () => onAddQuickPreset('Spiral Binding', 40.0))),
                  const SizedBox(width: 6),
                  Expanded(child: _buildPresetCard('Laminate', '₹25.00', () => onAddQuickPreset('A4 Lamination', 25.0))),
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
                            onPressed: onShowCustomItem,
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
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    InkWell(
                                      onTap: () => onEditQuantity(cartIndex, cartItem),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryContainer,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.primaryEmerald.withValues(alpha: 0.4)),
                                        ),
                                        child: Text(
                                          qtyDisplay,
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.primaryDark),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle, color: AppColors.primaryEmerald, size: 22),
                                      onPressed: () => ref.read(cartProvider.notifier).incrementQuantity(cartIndex),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ] else ...[
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryEmerald,
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  onPressed: () => ref.read(cartProvider.notifier).addItem(
                                        prod.name,
                                        prod.price,
                                        1,
                                        productId: prod.id,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),

        // Floating Bottom Dock (when items in cart)
        if (cart.items.isNotEmpty)
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: _buildFloatingDock(),
          ),
      ],
    );
  }
}
