import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/network/sync_queue_manager.dart';
import 'package:simplebilling_mobile/core/network/sync_task_model.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/data/models/product_model.dart';
import 'package:simplebilling_mobile/data/repositories/api_repository.dart';
import 'package:simplebilling_mobile/presentation/shared/widgets/sync_status_badge.dart';
import 'package:simplebilling_mobile/providers/billing_provider.dart';

final predefinedCategories = [
  'All',
  'Xerox & Print',
  'Lamination & Binding',
  'Stationery',
  'Paper & Envelopes',
  'Other Services',
];

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchTerm = '';
  String _selectedCategory = 'All';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  SyncStatus _getProductSyncStatus(
    String? clientRef,
    String id,
    List<SyncTask> tasks,
  ) {
    for (final task in tasks) {
      if (task.action == 'create_product') {
        if ((clientRef != null && task.clientRef == clientRef) ||
            task.id == id ||
            task.clientRef == id) {
          return task.status;
        }
      }
    }
    return SyncStatus.synced;
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'xerox & print':
      case 'xerox':
      case 'print':
        return AppColors.deepSky;
      case 'lamination & binding':
      case 'binding':
      case 'lamination':
        return AppColors.deepAmber;
      case 'stationery':
        return AppColors.deepLavender;
      case 'paper & envelopes':
      case 'paper':
        return AppColors.deepMint;
      default:
        return AppColors.deepCoral;
    }
  }

  Color _getCategoryBgColor(String category) {
    switch (category.toLowerCase()) {
      case 'xerox & print':
      case 'xerox':
      case 'print':
        return AppColors.pastelSky;
      case 'lamination & binding':
      case 'binding':
      case 'lamination':
        return AppColors.pastelAmber;
      case 'stationery':
        return AppColors.pastelLavender;
      case 'paper & envelopes':
      case 'paper':
        return AppColors.pastelMint;
      default:
        return AppColors.pastelCoral;
    }
  }

  void _showProductFormDialog({ProductModel? product}) {
    final isEditing = product != null;
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final priceCtrl = TextEditingController(
      text: product != null ? product.price.toStringAsFixed(2) : '',
    );
    final codeCtrl = TextEditingController(text: product?.productCode ?? '');
    String category = product?.category ?? 'Xerox & Print';
    if (!predefinedCategories.contains(category) && category != 'All') {
      category = 'Other Services';
    }

    String? errorBanner;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isEditing ? AppColors.pastelSky : AppColors.pastelMint,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isEditing ? AppColors.deepSky : AppColors.deepMint),
                ),
                child: Icon(
                  isEditing ? Icons.edit_note_rounded : Icons.add_shopping_cart_rounded,
                  color: isEditing ? AppColors.deepSky : AppColors.deepMint,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isEditing ? 'Edit Product / Service' : 'Add New Product / Rate',
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
                if (errorBanner != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.pastelCoral,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.deepCoral),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.deepCoral),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            errorBanner!,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.deepCoral),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Product / Service Name *',
                    hintText: 'e.g. A4 Color Single or Spiral Binding',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Service Category *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: predefinedCategories
                      .where((c) => c != 'All')
                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => category = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Standard Unit Price (₹) *',
                    hintText: 'e.g. 2.00 or 10.50 (step ₹0.25)',
                    prefixIcon: Icon(Icons.currency_rupee, size: 18, color: AppColors.primary),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeCtrl,
                  decoration: InputDecoration(
                    labelText: isEditing ? 'Product Code / SKU' : 'Product Code / SKU (Auto-generated if empty)',
                    hintText: 'e.g. PROD-000001',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text);
                final code = codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim();

                if (name.isEmpty) {
                  setModalState(() => errorBanner = 'Please enter product or service name.');
                  return;
                }
                if (price == null || price < 0) {
                  setModalState(() => errorBanner = 'Please enter a valid selling price (₹0.00 or higher).');
                  return;
                }

                if (isEditing) {
                  final success = await ApiRepository.updateProduct(
                    product.id,
                    name: name,
                    category: category,
                    price: price,
                    productCode: code,
                  );
                  if (mounted) {
                    ref.invalidate(productsProvider);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(success ? 'Product "$name" updated! ✏️' : 'Failed to update product.')),
                    );
                  }
                } else {
                  final created = await ApiRepository.createProduct(
                    name,
                    category,
                    price,
                    productCode: code,
                  );
                  if (created == null) {
                    // Offline fallback queue
                    final clientRef = const Uuid().v4();
                    await SyncQueueManager.instance.enqueueTask(
                      'create_product',
                      {
                        'client_ref': clientRef,
                        'name': name,
                        'category': category,
                        'price': price,
                        'product_code': code,
                      },
                      clientRef: clientRef,
                    );
                  }

                  if (mounted) {
                    ref.invalidate(productsProvider);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Product "$name" added to catalog! 🎉')),
                    );
                  }
                }
              },
              child: Text(isEditing ? 'Save Changes' : 'Save Product'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteSafeguardDialog(ProductModel product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.pastelCoral,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.deepCoral),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.deepCoral, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('Delete Product', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to permanently remove this catalog item?'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                  Text(
                    Formatters.currency(product.price),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.primary),
                  ),
                ],
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
              backgroundColor: AppColors.deepCoral,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await ApiRepository.deleteProduct(product.id);
              if (mounted) {
                ref.invalidate(productsProvider);
                if (ctx.mounted) Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Product "${product.name}" deleted from catalog.')),
                );
              }
            },
            child: const Text('Delete Product'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Product Catalog & Service Rates',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary),
            ),
            Text(
              'Master inventory items, photocopy/printing rates, and service fees',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary.withValues(alpha: 0.9)),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
        actions: [
          IconButton(
            tooltip: 'Add Product',
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.deepMint),
            onPressed: () => _showProductFormDialog(),
          ),
          IconButton(
            tooltip: 'Refresh Catalog',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: () => ref.invalidate(productsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        onPressed: () => _showProductFormDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('+ Add Product', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search catalog by product name, category, or barcode...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchTerm.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchTerm = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                ),
              ),
              onChanged: (v) => setState(() => _searchTerm = v),
            ),
          ),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: predefinedCategories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: AppColors.pastelLavender,
                    checkmarkColor: AppColors.deepLavender,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? AppColors.deepLavender : AppColors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.deepLavender : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 12,
                    ),
                    onSelected: (val) {
                      setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Product List / Grid
          Expanded(
            child: ValueListenableBuilder<List<SyncTask>>(
              valueListenable: SyncQueueManager.instance.tasksNotifier,
              builder: (ctx, tasks, _) {
                return productsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (err, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 44, color: AppColors.deepCoral),
                        const SizedBox(height: 8),
                        Text('Error loading products: $err', style: const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(productsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (products) {
                    final filtered = products.where((p) {
                      final matchesCat =
                          _selectedCategory == 'All' ||
                          p.category.toLowerCase() == _selectedCategory.toLowerCase();
                      if (!matchesCat) return false;
                      if (_searchTerm.isEmpty) return true;
                      final q = _searchTerm.toLowerCase();
                      return p.name.toLowerCase().contains(q) ||
                          (p.productCode != null && p.productCode!.toLowerCase().contains(q)) ||
                          p.category.toLowerCase().contains(q);
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.pastelLavender,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.inventory_2_rounded,
                                size: 48,
                                color: AppColors.deepLavender,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchTerm.isEmpty
                                  ? 'No products configured in catalog'
                                  : 'No products matching "$_searchTerm"',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Your First Product'),
                              onPressed: () => _showProductFormDialog(),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final prod = filtered[i];
                        final syncStatus = _getProductSyncStatus(
                          prod.clientRef,
                          prod.id,
                          tasks,
                        );

                        final catColor = _getCategoryColor(prod.category);
                        final catBg = _getCategoryBgColor(prod.category);

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border, width: 1.5),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: catBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.inventory_2_rounded, color: catColor, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              prod.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                color: AppColors.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (prod.productCode != null)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 6),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: AppColors.pastelSky,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  prod.productCode!,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.deepSky,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: catBg,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          prod.category,
                                          style: TextStyle(
                                            color: catColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${prod.price.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const Text('per unit/page', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                  ],
                                ),
                                const SizedBox(width: 6),
                                SyncStatusBadge(status: syncStatus),
                                const SizedBox(width: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.deepSky),
                                      tooltip: 'Edit Product',
                                      onPressed: () => _showProductFormDialog(product: prod),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.deepCoral),
                                      tooltip: 'Delete Product',
                                      onPressed: () => _showDeleteSafeguardDialog(prod),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
