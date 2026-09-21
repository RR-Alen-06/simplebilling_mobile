import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/network/sync_queue_manager.dart';
import 'package:simplebilling_mobile/core/network/sync_task_model.dart';
import 'package:simplebilling_mobile/core/utils/formatters.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
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
                                      icon: const Icon(Icons.analytics_outlined, size: 18, color: AppColors.deepLavender),
                                      tooltip: 'Sales History & Analytics',
                                      onPressed: () => _showProductSalesHistorySheet(prod),
                                    ),
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

  void _showProductSalesHistorySheet(ProductModel product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductSalesHistoryModal(product: product),
    );
  }
}

enum _SalesHistoryDatePreset { allTime, today, thisMonth, custom }

class _ProductSaleRecord {
  final BillModel bill;
  final BillItemModel item;

  _ProductSaleRecord({required this.bill, required this.item});
}

class _ProductSalesHistoryModal extends ConsumerStatefulWidget {
  final ProductModel product;

  const _ProductSalesHistoryModal({required this.product});

  @override
  ConsumerState<_ProductSalesHistoryModal> createState() => _ProductSalesHistoryModalState();
}

class _ProductSalesHistoryModalState extends ConsumerState<_ProductSalesHistoryModal> {
  _SalesHistoryDatePreset _selectedPreset = _SalesHistoryDatePreset.allTime;
  DateTimeRange? _customDateRange;

  DateTimeRange? _getDateRange() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (_selectedPreset) {
      case _SalesHistoryDatePreset.allTime:
        return null;
      case _SalesHistoryDatePreset.today:
        return DateTimeRange(start: todayStart, end: todayEnd);
      case _SalesHistoryDatePreset.thisMonth:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: todayEnd);
      case _SalesHistoryDatePreset.custom:
        return _customDateRange ?? DateTimeRange(start: todayStart, end: todayEnd);
    }
  }

  bool _isBillInRange(BillModel bill, DateTimeRange? range) {
    if (range == null) return true;
    if (bill.createdAt.isEmpty) return false;
    final parsed = DateTime.tryParse(bill.createdAt);
    if (parsed == null) return false;
    return (parsed.isAfter(range.start) || parsed.isAtSameMomentAs(range.start)) &&
        (parsed.isBefore(range.end) || parsed.isAtSameMomentAs(range.end));
  }

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(billsListProvider);
    final range = _getDateRange();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
        ),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.pastelLavender,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLavender),
                  ),
                  child: const Icon(Icons.analytics_rounded, color: AppColors.deepLavender, size: 22),
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
                              widget.product.name,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.product.productCode != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.pastelSky,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.product.productCode!,
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.deepSky),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Category: ${widget.product.category}  •  Catalog Rate: ₹${widget.product.price.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Date Filter Selector Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildDateChip('All Time', _SalesHistoryDatePreset.allTime),
                _buildDateChip('Today', _SalesHistoryDatePreset.today),
                _buildDateChip('This Month', _SalesHistoryDatePreset.thisMonth),
                _buildDateChip(
                  _selectedPreset == _SalesHistoryDatePreset.custom && _customDateRange != null
                      ? '${Formatters.date(_customDateRange!.start)} - ${Formatters.date(_customDateRange!.end)}'
                      : 'Custom Range',
                  _SalesHistoryDatePreset.custom,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Content
          Expanded(
            child: billsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, _) => Center(child: Text('Error loading sales: $err')),
              data: (allBills) {
                final targetName = widget.product.name.trim().toLowerCase();
                final targetId = widget.product.id;

                final List<_ProductSaleRecord> records = [];

                for (final bill in allBills) {
                  if (!_isBillInRange(bill, range)) continue;

                  for (final item in bill.items) {
                    final itemProdId = item.productId;
                    final itemName = item.productName.trim().toLowerCase();

                    final isMatch = (itemProdId != null && itemProdId == targetId) ||
                        itemName == targetName;

                    if (isMatch) {
                      records.add(_ProductSaleRecord(bill: bill, item: item));
                    }
                  }
                }

                // Sort by date descending
                records.sort((a, b) => b.bill.createdAt.compareTo(a.bill.createdAt));

                // Compute Metrics
                final totalQtySold = records.fold(0.0, (s, r) => s + r.item.quantity);
                final totalRevenueEarned = records.fold(0.0, (s, r) => s + r.item.total);
                final avgSellingPrice = totalQtySold > 0 ? totalRevenueEarned / totalQtySold : widget.product.price;
                final uniqueOrdersCount = records.map((r) => r.bill.id).toSet().length;

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  children: [
                    // 4 Financial Summary KPI Cards
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildMetricCard(
                          title: 'TOTAL QTY SOLD',
                          value: '${totalQtySold.toStringAsFixed(totalQtySold % 1 == 0 ? 0 : 2)} units',
                          subtitle: 'Units / Pages Sold',
                          icon: Icons.inventory_2_rounded,
                          bgColor: AppColors.pastelSky,
                          textColor: AppColors.deepSky,
                          borderColor: AppColors.borderSky,
                        ),
                        _buildMetricCard(
                          title: 'TOTAL REVENUE',
                          value: '₹${totalRevenueEarned.toStringAsFixed(2)}',
                          subtitle: 'Total Earned',
                          icon: Icons.currency_rupee_rounded,
                          bgColor: AppColors.pastelMint,
                          textColor: AppColors.deepMint,
                          borderColor: AppColors.borderMint,
                        ),
                        _buildMetricCard(
                          title: 'AVG SELLING PRICE',
                          value: '₹${avgSellingPrice.toStringAsFixed(2)}',
                          subtitle: 'Effective Rate/Unit',
                          icon: Icons.price_check_rounded,
                          bgColor: AppColors.pastelLavender,
                          textColor: AppColors.deepLavender,
                          borderColor: AppColors.borderLavender,
                        ),
                        _buildMetricCard(
                          title: 'ORDERS COUNT',
                          value: '$uniqueOrdersCount bills',
                          subtitle: 'Invoices Billed',
                          icon: Icons.receipt_long_rounded,
                          bgColor: AppColors.pastelAmber,
                          textColor: AppColors.deepAmber,
                          borderColor: AppColors.borderAmber,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Sales Transaction List Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sales Transactions (${records.length})',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                        ),
                        if (records.isNotEmpty)
                          Text(
                            'Earned: ₹${totalRevenueEarned.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.deepMint),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (records.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border, width: 1.5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 44, color: AppColors.border),
                            const SizedBox(height: 8),
                            const Text(
                              'No sales recorded for this product',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedPreset == _SalesHistoryDatePreset.allTime
                                  ? 'This item has not been included in any billed invoices yet.'
                                  : 'No sales found in the selected date range. Try switching to "All Time".',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    else
                      ...records.map((r) {
                        final isCustomPrice = (r.item.price - widget.product.price).abs() > 0.001;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border, width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        r.bill.billNumber,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, fontFamily: 'monospace'),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        Formatters.parseAndFormatDate(r.bill.createdAt),
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '₹${r.item.total.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: AppColors.primary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Customer: ${r.bill.customerName ?? "Walk-in Customer"}',
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'Qty: ${r.item.quantity.toStringAsFixed(r.item.quantity % 1 == 0 ? 0 : 2)}  ×  ₹${r.item.price.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                      ),
                                      if (isCustomPrice) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppColors.pastelAmber,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('Custom Rate', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.deepAmber)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(String label, _SalesHistoryDatePreset preset) {
    final isSelected = _selectedPreset == preset;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
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
          fontSize: 11.5,
        ),
        onSelected: (val) async {
          if (preset == _SalesHistoryDatePreset.custom) {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              initialDateRange: _customDateRange ?? DateTimeRange(
                start: DateTime.now().subtract(const Duration(days: 7)),
                end: DateTime.now(),
              ),
            );
            if (picked != null) {
              setState(() {
                _customDateRange = picked;
                _selectedPreset = _SalesHistoryDatePreset.custom;
              });
            }
          } else {
            setState(() => _selectedPreset = preset);
          }
        },
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
    required Color borderColor,
  }) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final cardWidth = (MediaQuery.of(context).size.width - 40) / 2;
        return Container(
          width: cardWidth,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 9.5, color: textColor, letterSpacing: 0.5)),
                  Icon(icon, size: 16, color: textColor),
                ],
              ),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: textColor)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      },
    );
  }
}
