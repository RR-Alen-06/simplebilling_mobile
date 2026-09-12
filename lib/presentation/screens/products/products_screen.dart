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

final categoriesList = [
  'All',
  'Stationery',
  'Xerox & Print',
  'Lamination & Binding',
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

  void _showAddProductDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    String category = 'Stationery';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.add_shopping_cart, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Add New Product / SKU'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Product / Item Name *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: categoriesList
                      .where((c) => c != 'All')
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => category = val);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Selling Rate (Rs.) *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Barcode / SKU (Optional)',
                    border: OutlineInputBorder(),
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
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text) ?? 0.0;
                final code = codeCtrl.text.trim().isEmpty
                    ? null
                    : codeCtrl.text.trim();
                if (name.isEmpty || price < 0) return;

                final created = await ApiRepository.createProduct(
                  name,
                  category,
                  price,
                  productCode: code,
                );
                if (created == null) {
                  // Offline fallback
                  final clientRef = const Uuid().v4();
                  await SyncQueueManager.instance.enqueueTask(
                    'create_product',
                    {
                      'client_ref': clientRef,
                      'name': name,
                      'category': category,
                      'price': price,
                      'product_code': ?code,
                    },
                    clientRef: clientRef,
                  );
                }

                if (!mounted) return;
                ref.invalidate(productsProvider);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Product "$name" saved!')),
                );
              },
              child: const Text('Save Product'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProductDialog(ProductModel prod) {
    final nameCtrl = TextEditingController(text: prod.name);
    final priceCtrl = TextEditingController(text: prod.price.toStringAsFixed(2));
    String category = prod.category;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Product Name *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: categoriesList.contains(category) ? category : categoriesList[1],
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: categoriesList.where((c) => c != 'All').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => category = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Price (₹) *', prefixText: '₹ ', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final price = double.tryParse(priceCtrl.text) ?? 0.0;
                      if (name.isEmpty || price < 0) return;

                      setDialogState(() => isSaving = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);

                      final ok = await ApiRepository.updateProduct(prod.id, name: name, category: category, price: price);
                      if (mounted) {
                        nav.pop();
                        if (ok) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Product "$name" updated!')),
                          );
                          ref.invalidate(productsProvider);
                        }
                      }
                    },
              child: Text(isSaving ? 'Saving...' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSeedCatalog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Seed Default Catalog'),
        content: const Text(
          'This will populate the standard Xerox, Printing, Lamination, and Stationery product catalog and demo customers from the web app. Proceed?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Seed Catalog'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Seeding default catalog...')),
      );
      await ApiRepository.seedDefaultCatalogAndCustomers();
      ref.invalidate(productsProvider);
      ref.invalidate(customersProvider);
      ref.invalidate(customerSummariesProvider);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Default catalog seeded successfully!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Products & Catalog',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download_outlined, color: AppColors.primary),
            tooltip: 'Seed Default Catalog',
            onPressed: _handleSeedCatalog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.invalidate(productsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _showAddProductDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Product'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search product, category, or barcode...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchTerm.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchTerm = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
              ),
              onChanged: (v) => setState(() => _searchTerm = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: categoriesList.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
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
          const SizedBox(height: 8),
          Expanded(
            child: ValueListenableBuilder<List<SyncTask>>(
              valueListenable: SyncQueueManager.instance.tasksNotifier,
              builder: (ctx, tasks, _) {
                return productsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 8),
                        Text('Error loading products: $err'),
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
                          p.category.toLowerCase() ==
                              _selectedCategory.toLowerCase();
                      if (!matchesCat) return false;
                      if (_searchTerm.isEmpty) return true;
                      final q = _searchTerm.toLowerCase();
                      return p.name.toLowerCase().contains(q) ||
                          (p.productCode != null &&
                              p.productCode!.toLowerCase().contains(q)) ||
                          p.category.toLowerCase().contains(q);
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
                              size: 48,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchTerm.isEmpty
                                  ? 'No products in catalog'
                                  : 'No products matching "$_searchTerm"',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (_searchTerm.isEmpty) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.cloud_download),
                                label: const Text('Seed Standard 21 Products'),
                                onPressed: _handleSeedCatalog,
                              ),
                            ],
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final prod = filtered[i];
                        final syncStatus = _getProductSyncStatus(
                          prod.clientRef,
                          prod.id,
                          tasks,
                        );

                        return Card(
                          elevation: 0.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            title: Row(
                              children: [
                                Text(
                                  prod.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (prod.productCode != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        prod.productCode!,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              prod.category,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  Formatters.currency(prod.price),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SyncStatusBadge(status: syncStatus),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                    color: AppColors.primary,
                                  ),
                                  tooltip: 'Edit Product',
                                  onPressed: () => _showEditProductDialog(prod),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: AppColors.error,
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text('Delete Product'),
                                        content: Text(
                                          'Are you sure you want to remove "${prod.name}"?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(c).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.error,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () =>
                                                Navigator.of(c).pop(true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await ApiRepository.deleteProduct(
                                        prod.id,
                                      );
                                      ref.invalidate(productsProvider);
                                    }
                                  },
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
