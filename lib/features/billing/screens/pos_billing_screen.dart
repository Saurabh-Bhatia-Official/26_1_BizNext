// lib/features/billing/screens/pos_billing_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../inventory/models/product_model.dart';
import '../../discounts/providers/discount_provider.dart';
import '../../discounts/models/offer.dart';
import '../../settings/providers/settings_provider.dart';
import '../../customers/providers/customer_provider.dart';
import '../../customers/models/customer_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/pos_model.dart';
import '../providers/billing_provider.dart';
import '../../loyalty/providers/loyalty_provider.dart';
import '../providers/sales_stats_provider.dart';
import '../utils/invoice_service.dart';
import '../../../core/widgets/searchable_dropdown.dart';
import '../../../core/widgets/qr_scanner_screen.dart';
import '../../../core/services/shortcut_service.dart';

// Local POS specific state providers
final _posSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final _isCameraVisibleProvider = StateProvider.autoDispose<bool>((ref) => false);
final _posCategoryProvider = StateProvider.autoDispose<int?>((ref) => null);
final _posStockFilterProvider = StateProvider.autoDispose<String>((ref) => 'all'); // 'all', 'in_stock', 'low_stock'
final _posViewModeProvider = StateProvider.autoDispose<String>((ref) => 'grid'); // 'grid', 'list'
final _posPriceListProvider = StateProvider.autoDispose<String>((ref) => 'Standard');

class PosBillingScreen extends ConsumerWidget {
  const PosBillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 900;

    if (isMobile) {
      return AppShortcut(
        actionId: 'pos_clear',
        onPressed: () => ref.read(billingProvider.notifier).reset(),
        child: PopScope(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) ref.read(billingProvider.notifier).reset();
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                'POS BILLING', 
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5)
              ),
              leading: Navigator.canPop(context) 
                ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context))
                : IconButton(icon: const Icon(Icons.menu_rounded), onPressed: () => Scaffold.of(context).openDrawer()),
              actions: [
                _HeldOrdersBadgeButton(isDark: isDark),
                const SizedBox(width: 8),
              ],
            ),
            body: _ProductPicker(isDark: isDark),
            bottomSheet: _MobileCartSheet(isDark: isDark),
          ),
        ),
      );
    }

    return AppShortcut(
      actionId: 'pos_clear',
      onPressed: () => ref.read(billingProvider.notifier).reset(),
      child: PopScope(
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) ref.read(billingProvider.notifier).reset();
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Row(
            children: [
              // ── Left: Product Catalog ──
              Expanded(
                flex: 9,
                child: _ProductPicker(isDark: isDark),
              ),
              
              // ── Right: Checkout Panel ──
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                        blurRadius: 40,
                        offset: const Offset(-10, 0),
                      ),
                    ],
                    border: Border(left: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.5)),
                  ),
                  child: _CartPanel(isDark: isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Held Orders Badge Button ──────────────────────────────────────────────────
class _HeldOrdersBadgeButton extends ConsumerWidget {
  final bool isDark;
  const _HeldOrdersBadgeButton({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heldOrders = ref.watch(heldOrdersProvider);

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.pause_circle_outline_rounded, size: 24),
          tooltip: 'Parked / Held Orders',
          onPressed: () => _showHeldOrdersDialog(context, ref, isDark),
        ),
        if (heldOrders.isNotEmpty)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${heldOrders.length}',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
          ),
      ],
    );
  }
}

void _showHeldOrdersDialog(BuildContext context, WidgetRef ref, bool isDark) {
  showDialog(
    context: context,
    builder: (ctx) => Consumer(
      builder: (context, ref, _) {
        final heldOrders = ref.watch(heldOrdersProvider);

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.pause_circle_filled_rounded, color: Colors.amber),
              ),
              const SizedBox(width: 14),
              Text(
                'Parked / Held Carts (${heldOrders.length})',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: heldOrders.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_rounded, size: 48, color: AppColors.textMuted.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        const Text('No parked orders at this time', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: heldOrders.length,
                    separatorBuilder: (ctx, idx) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final order = heldOrders[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        title: Text(
                          order.customerName ?? 'Walk-in Customer',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                        subtitle: Text(
                          '${order.itemCount} items • ${CurrencyFormatter.format(order.grandTotal)}${order.notes != null ? ' • Note: ${order.notes}' : ''}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.play_arrow_rounded, size: 18),
                              label: const Text('Resume'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                ref.read(billingProvider.notifier).resumeHeldOrder(order);
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Parked order resumed to cart'),
                                    backgroundColor: AppColors.success,
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                              onPressed: () => ref.read(billingProvider.notifier).discardHeldOrder(order.id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    ),
  );
}

// ── Product Picker (Catalog) ──────────────────────────────────────────────────
class _ProductPicker extends ConsumerStatefulWidget {
  final bool isDark;
  const _ProductPicker({required this.isDark});

  @override
  ConsumerState<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends ConsumerState<_ProductPicker> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final searchQuery = ref.watch(_posSearchProvider).toLowerCase();
    final selectedCatId = ref.watch(_posCategoryProvider);
    final stockFilter = ref.watch(_posStockFilterProvider);
    final viewMode = ref.watch(_posViewModeProvider);

    return AppShortcut(
      actionId: 'pos_search',
      onPressed: () => _searchFocusNode.requestFocus(),
      child: Column(
        children: [
          // ── Catalog Header & Search Controls ──
          Padding(
            padding: EdgeInsets.fromLTRB(
              MediaQuery.of(context).size.width < 700 ? 16 : 28,
              MediaQuery.of(context).size.width < 700 ? 16 : 24,
              MediaQuery.of(context).size.width < 700 ? 16 : 28,
              12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (Navigator.canPop(context))
                            Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_rounded),
                                onPressed: () => Navigator.pop(context),
                                tooltip: 'Back to Sales History',
                              ),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Point of Sale',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.0,
                              color: widget.isDark ? Colors.white : AppColors.textLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.flash_on_rounded, size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Tap products, scan barcode, or search below',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _HeldOrdersBadgeButton(isDark: widget.isDark),
                        _PriceListSelector(isDark: widget.isDark),
                        _ViewModeToggle(isDark: widget.isDark, current: viewMode),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ProfessionalSearchBar(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (v) => ref.read(_posSearchProvider.notifier).state = v,
                        isDark: widget.isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _BarcodeScannerButton(
                      onScan: (code) {
                        _searchController.text = code;
                        ref.read(_posSearchProvider.notifier).state = code;
                        _instantAddBarcode(code);
                      },
                    ),
                  ],
                ),
                if (ref.watch(_isCameraVisibleProvider)) ...[
                  const SizedBox(height: 12),
                  _EmbeddedScanner(
                    onScan: (code) {
                      _searchController.text = code;
                      ref.read(_posSearchProvider.notifier).state = code;
                      _instantAddBarcode(code);
                    },
                    isDark: widget.isDark,
                    onClose: () => ref.read(_isCameraVisibleProvider.notifier).state = false,
                    initialCameraIndex: ref.watch(featureSettingsProvider).selectedCameraIndex,
                  ),
                ],
              ],
            ),
          ),

          // ── Category & Stock Filter Chips Ribbon ──
          categoriesAsync.when(
            data: (cats) => Container(
              height: 44,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                scrollDirection: Axis.horizontal,
                itemCount: cats.length + 3, // All + Stock Filters + Categories
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    final isSelected = selectedCatId == null && stockFilter == 'all';
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: 'All Products',
                        icon: Icons.grid_view_rounded,
                        isSelected: isSelected,
                        onTap: () {
                          ref.read(_posCategoryProvider.notifier).state = null;
                          ref.read(_posStockFilterProvider.notifier).state = 'all';
                        },
                        isDark: widget.isDark,
                      ),
                    );
                  } else if (i == 1) {
                    final isSelected = stockFilter == 'in_stock';
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: 'In Stock',
                        icon: Icons.check_circle_outline_rounded,
                        isSelected: isSelected,
                        onTap: () => ref.read(_posStockFilterProvider.notifier).state = isSelected ? 'all' : 'in_stock',
                        isDark: widget.isDark,
                      ),
                    );
                  } else if (i == 2) {
                    final isSelected = stockFilter == 'low_stock';
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: 'Low Stock',
                        icon: Icons.warning_amber_rounded,
                        isSelected: isSelected,
                        onTap: () => ref.read(_posStockFilterProvider.notifier).state = isSelected ? 'all' : 'low_stock',
                        isDark: widget.isDark,
                      ),
                    );
                  }

                  final cat = cats[i - 3];
                  final isSelected = selectedCatId == cat.id;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: cat.name,
                      isSelected: isSelected,
                      onTap: () {
                        ref.read(_posCategoryProvider.notifier).state = isSelected ? null : cat.id;
                      },
                      isDark: widget.isDark,
                    ),
                  );
                },
              ),
            ),
            loading: () => const SizedBox(height: 44),
            error: (_, _) => const SizedBox.shrink(),
          ),

          // ── Always-Visible Product Catalog Grid / List ──
          Expanded(
            child: productsAsync.when(
              data: (products) {
                final filtered = products.where((p) {
                  final matchSearch = searchQuery.isEmpty || 
                                     p.name.toLowerCase().contains(searchQuery) ||
                                     (p.barcode?.toLowerCase().contains(searchQuery) ?? false) ||
                                     (p.sku?.toLowerCase().contains(searchQuery) ?? false) ||
                                     (p.brand?.toLowerCase().contains(searchQuery) ?? false);
                  final matchCat = selectedCatId == null || p.categoryId == selectedCatId;
                  
                  bool matchStock = true;
                  if (stockFilter == 'in_stock') {
                    matchStock = p.stock > 0;
                  } else if (stockFilter == 'low_stock') {
                    matchStock = p.isLowStock;
                  }

                  return matchSearch && matchCat && matchStock && p.isActive;
                }).toList();

                if (filtered.isEmpty) {
                  return _NoResults(query: searchQuery);
                }

                if (viewMode == 'list') {
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _ProductListRow(product: filtered[i], isDark: widget.isDark),
                  );
                }

                // Grid View
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 100),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: MediaQuery.of(context).size.width < 700 ? 200 : 230,
                    childAspectRatio: 0.76,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _ProductCard(product: filtered[i], isDark: widget.isDark),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _instantAddBarcode(String code) {
    final products = ref.read(productsProvider).value ?? [];
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;

    final match = products.firstWhere(
      (p) => (p.barcode?.toLowerCase() == trimmed.toLowerCase() || p.sku?.toLowerCase() == trimmed.toLowerCase()),
      orElse: () => const Product(name: '', sellingPrice: 0, stock: 0, unit: '', categoryId: 0),
    );

    if (match.name.isNotEmpty) {
      final error = ref.read(billingProvider.notifier).addProduct(match);
      if (error != null) {
        AppAlert.warning(ref, error);
      } else {
        _searchController.clear();
        ref.read(_posSearchProvider.notifier).state = '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${match.name}" to cart'),
            duration: const Duration(milliseconds: 800),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }
}

// ── View Mode Toggle ─────────────────────────────────────────────────────────
class _ViewModeToggle extends ConsumerWidget {
  final bool isDark;
  final String current;
  const _ViewModeToggle({required this.isDark, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              Icons.grid_view_rounded, 
              size: 18, 
              color: current == 'grid' ? AppColors.primary : AppColors.textMuted
            ),
            tooltip: 'Grid View',
            onPressed: () => ref.read(_posViewModeProvider.notifier).state = 'grid',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: Icon(
              Icons.view_list_rounded, 
              size: 20, 
              color: current == 'list' ? AppColors.primary : AppColors.textMuted
            ),
            tooltip: 'Compact List View',
            onPressed: () => ref.read(_posViewModeProvider.notifier).state = 'list',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── Filter Chip ─────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.white : AppColors.primary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textLight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Rich Product Card (Grid Mode) ─────────────────────────────────────────────
double _resolveEffectiveProductPrice(
  Product product,
  String priceList,
  CustomerModel? customer, {
  Map<int, List<ProductTierPrice>>? allTiers,
  double quantity = 1.0,
}) {
  final activeScale = (customer?.customerTypeName != null && customer!.customerTypeName!.trim().isNotEmpty)
      ? customer.customerTypeName!
      : priceList;
  final lower = activeScale.toLowerCase();

  // 1. Check custom Tiered Prices for this product matching category id or category name
  if (allTiers != null && product.id != null && allTiers.containsKey(product.id)) {
    final tiers = allTiers[product.id!]!;
    final matchingTier = tiers.firstWhere(
      (t) =>
          ((customer?.customerTypeId != null && t.categoryId == customer!.customerTypeId) ||
           (t.categoryName != null && t.categoryName!.toLowerCase() == lower)) &&
          quantity >= t.minQty &&
          (quantity <= t.maxQty),
      orElse: () => tiers.firstWhere(
        (t) =>
            (customer?.customerTypeId != null && t.categoryId == customer!.customerTypeId) ||
            (t.categoryName != null && t.categoryName!.toLowerCase() == lower),
        orElse: () => const ProductTierPrice(productId: 0, categoryId: 0, price: -1),
      ),
    );

    if (matchingTier.price >= 0) {
      return matchingTier.price;
    }
  }

  // 2. Dedicated Wholesale Price
  if (lower.contains('wholesale') && product.wholesalePrice > 0) {
    return product.wholesalePrice;
  }

  // 3. Dedicated Dealer Price
  if (lower.contains('dealer') && product.dealerPrice > 0) {
    return product.dealerPrice;
  }

  // 4. Default Standard Selling Price
  return product.sellingPrice;
}

String _resolveActiveScaleName(String priceList, CustomerModel? customer) {
  if (customer?.customerTypeName != null && customer!.customerTypeName!.trim().isNotEmpty) {
    return customer.customerTypeName!;
  }
  return priceList;
}

class _ProductCard extends ConsumerWidget {
  final Product product;
  final bool isDark;

  const _ProductCard({required this.product, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billing = ref.watch(billingProvider);
    final priceList = ref.watch(_posPriceListProvider);
    final customers = ref.watch(customersProvider).value ?? [];
    final allTiers = ref.watch(allProductTierPricesProvider).value;
    final selectedCustomer = billing.selectedCustomerId != null
        ? customers.where((c) => c.id == billing.selectedCustomerId).firstOrNull
        : null;

    final effectivePrice = _resolveEffectiveProductPrice(product, priceList, selectedCustomer, allTiers: allTiers);
    final activeScale = _resolveActiveScaleName(priceList, selectedCustomer);
    final isSpecialTier = effectivePrice != product.sellingPrice;

    final inCartQty = billing.items
        .where((item) => item.product.id == product.id)
        .fold(0.0, (sum, item) => sum + item.quantity);

    final isOut = product.stock <= 0;
    final isLow = product.isLowStock;
    final statusColor = isOut ? AppColors.error : (isLow ? AppColors.warning : AppColors.success);

    final hasDiscount = product.mrp > effectivePrice;
    final discountPercent = hasDiscount ? (((product.mrp - effectivePrice) / product.mrp) * 100).round() : 0;

    return InkWell(
      onTap: isOut ? null : () => _handleProductTap(context, ref, product),
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: inCartQty > 0 
                ? AppColors.primary 
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: inCartQty > 0 ? 2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: inCartQty > 0 
                  ? AppColors.primary.withValues(alpha: 0.15) 
                  : Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: inCartQty > 0 ? 16 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Badges & Thumbnail Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          statusColor.withValues(alpha: 0.2),
                          statusColor.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.inventory_2_rounded, color: statusColor, size: 20),
                  ),
                  if (inCartQty > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${inCartQty.toInt()} in Cart',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    )
                  else if (isSpecialTier)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        activeScale.toUpperCase(),
                        style: const TextStyle(color: Colors.indigo, fontSize: 9, fontWeight: FontWeight.w900),
                      ),
                    )
                  else if (hasDiscount)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$discountPercent% OFF',
                        style: const TextStyle(color: AppColors.success, fontSize: 9, fontWeight: FontWeight.w900),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // Product Name & Brand
              Text(
                product.name,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, height: 1.2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${product.brand != null && product.brand!.isNotEmpty ? "${product.brand} • " : ""}${product.sku ?? product.barcode ?? "NO SKU"}',
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              // Stock & Pricing details
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      isOut ? 'Out of Stock' : '${product.stock.toInt()} ${product.unit} left',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasDiscount || isSpecialTier)
                          Text(
                            CurrencyFormatter.format(isSpecialTier ? product.sellingPrice : product.mrp),
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: AppColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            CurrencyFormatter.format(effectivePrice),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: isSpecialTier ? AppColors.primary : (isDark ? Colors.white : AppColors.textLight),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isOut ? Colors.grey.withValues(alpha: 0.1) : AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.add_rounded, size: 16, color: isOut ? AppColors.textMuted : Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _handleProductTap(BuildContext context, WidgetRef ref, Product product) async {
  final priceList = ref.read(_posPriceListProvider);
  final billing = ref.read(billingProvider);
  final customers = ref.read(customersProvider).value ?? [];
  final allTiers = ref.read(allProductTierPricesProvider).value;
  final selectedCustomer = billing.selectedCustomerId != null
      ? customers.where((c) => c.id == billing.selectedCustomerId).firstOrNull
      : null;

  final effectivePrice = _resolveEffectiveProductPrice(product, priceList, selectedCustomer, allTiers: allTiers);
  final activeScale = _resolveActiveScaleName(priceList, selectedCustomer);

  if (effectivePrice != product.sellingPrice) {
    // Automatically apply category price scale
    final error = ref.read(billingProvider.notifier).addProduct(
      product,
      overridePrice: effectivePrice,
      priceScaleName: activeScale,
    );
    if (error != null) AppAlert.warning(ref, error);
    return;
  }

  final tiers = await ref.read(productRepositoryProvider).getProductPrices(product.id!);
  if (tiers.isNotEmpty && context.mounted) {
    _showPriceSelectionModal(context, ref, product, tiers);
  } else {
    final error = ref.read(billingProvider.notifier).addProduct(product);
    if (error != null) AppAlert.warning(ref, error);
  }
}

void _showPriceSelectionModal(BuildContext context, WidgetRef ref, Product product, List<ProductTierPrice> tiers) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Pricing for ${product.name}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.shopping_cart_rounded, color: AppColors.primary),
                title: const Text('Standard Retail Price', style: TextStyle(fontWeight: FontWeight.w900)),
                trailing: Text(CurrencyFormatter.format(product.sellingPrice), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(billingProvider.notifier).addProduct(product, overridePrice: product.sellingPrice, priceScaleName: 'Retail');
                },
              ),
              if (product.wholesalePrice > 0)
                ListTile(
                  leading: const Icon(Icons.storefront_rounded, color: Colors.blue),
                  title: const Text('Wholesale Price', style: TextStyle(fontWeight: FontWeight.w900)),
                  trailing: Text(CurrencyFormatter.format(product.wholesalePrice), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(billingProvider.notifier).addProduct(product, overridePrice: product.wholesalePrice, priceScaleName: 'Wholesale');
                  },
                ),
              if (product.dealerPrice > 0)
                ListTile(
                  leading: const Icon(Icons.local_shipping_rounded, color: Colors.purple),
                  title: const Text('Dealer Price', style: TextStyle(fontWeight: FontWeight.w900)),
                  trailing: Text(CurrencyFormatter.format(product.dealerPrice), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(billingProvider.notifier).addProduct(product, overridePrice: product.dealerPrice, priceScaleName: 'Dealer');
                  },
                ),
              ...tiers.map((t) => ListTile(
                leading: const Icon(Icons.layers_rounded, color: AppColors.success),
                title: Text('${t.categoryName ?? "Tier Price"} (Min: ${t.minQty.toInt()})', style: const TextStyle(fontWeight: FontWeight.w900)),
                trailing: Text(CurrencyFormatter.format(t.price), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(billingProvider.notifier).addProduct(product, overridePrice: t.price, priceScaleName: t.categoryName ?? 'Tier');
                },
              )),
            ],
          ),
        ),
      ),
    ),
  );
}

// ── Compact Product List Row (List Mode) ──────────────────────────────────────
class _ProductListRow extends ConsumerWidget {
  final Product product;
  final bool isDark;
  const _ProductListRow({required this.product, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billing = ref.watch(billingProvider);
    final priceList = ref.watch(_posPriceListProvider);
    final customers = ref.watch(customersProvider).value ?? [];
    final allTiers = ref.watch(allProductTierPricesProvider).value;
    final selectedCustomer = billing.selectedCustomerId != null
        ? customers.where((c) => c.id == billing.selectedCustomerId).firstOrNull
        : null;

    final effectivePrice = _resolveEffectiveProductPrice(product, priceList, selectedCustomer, allTiers: allTiers);
    final activeScale = _resolveActiveScaleName(priceList, selectedCustomer);
    final isSpecialTier = effectivePrice != product.sellingPrice;

    final isOut = product.stock <= 0;
    final statusColor = isOut ? AppColors.error : (product.isLowStock ? AppColors.warning : AppColors.success);

    return Material(
      color: isDark ? AppColors.darkCard : Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: () => _handleProductTap(context, ref, product),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.inventory_2_rounded, color: statusColor, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            if (isSpecialTier)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  activeScale.toUpperCase(),
                  style: const TextStyle(color: Colors.indigo, fontSize: 9, fontWeight: FontWeight.w900),
                ),
              ),
          ],
        ),
        subtitle: Text(
          'SKU: ${product.sku ?? "—"} • Stock: ${product.stock.toInt()} ${product.unit}',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isSpecialTier)
                  Text(
                    CurrencyFormatter.format(product.sellingPrice),
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  CurrencyFormatter.format(effectivePrice),
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: isSpecialTier ? AppColors.primary : (isDark ? Colors.white : AppColors.textLight),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              icon: const Icon(Icons.add, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isOut ? null : () => _handleProductTap(context, ref, product),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search Bar ───────────────────────────────────────────────────────────────
class _ProfessionalSearchBar extends StatelessWidget {
  final Function(String) onChanged;
  final bool isDark;
  final TextEditingController controller;
  final FocusNode? focusNode;

  const _ProfessionalSearchBar({
    required this.onChanged,
    required this.isDark,
    required this.controller,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by product name, SKU, barcode, or brand...',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ── Price List Selector ─────────────────────────────────────────────────────
class _PriceListSelector extends ConsumerWidget {
  final bool isDark;
  const _PriceListSelector({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_posPriceListProvider);
    final customerTypesAsync = ref.watch(customerTypesProvider);
    final priceCategoriesAsync = ref.watch(priceCategoriesProvider);

    final dynamicCategories = <String>{'Standard', 'Wholesale', 'Dealer'};
    // We intentionally do not add Customer Types here.
    // The user requested to show ONLY valid Product Price Categories.
    priceCategoriesAsync.whenData((cats) {
      for (final c in cats) {
        if (c.name.trim().isNotEmpty) dynamicCategories.add(c.name.trim());
      }
    });

    final lists = dynamicCategories.toList();
    final effectiveSelected = lists.contains(selected) ? selected : 'Standard';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveSelected,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 18),
          isDense: true,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.textLight),
          onChanged: (v) {
            if (v != null) {
              ref.read(_posPriceListProvider.notifier).state = v;
              ref.read(billingProvider.notifier).setPriceScale(v);
            }
          },
          items: lists.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
        ),
      ),
    );
  }
}

// ── Barcode Scanner Button ──────────────────────────────────────────────────
class _BarcodeScannerButton extends ConsumerWidget {
  final Function(String) onScan;
  const _BarcodeScannerButton({required this.onScan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: IconButton(
        onPressed: () async {
          final setting = ref.read(featureSettingsProvider).scannerDevice;
          if (setting == 'embedded') {
            ref.read(_isCameraVisibleProvider.notifier).state = true;
          } else {
            String? code;
            final cameraIndex = ref.read(featureSettingsProvider).selectedCameraIndex;
            code = await Navigator.push<String>(
              context,
              MaterialPageRoute(builder: (context) => QRScannerScreen(initialCameraIndex: cameraIndex)),
            );
            if (code != null && code != '-1') {
              onScan(code);
            }
          }
        },
        icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Colors.white),
        padding: const EdgeInsets.all(12),
      ),
    );
  }
}

// ── Cart Panel (Checkout Panel) ──────────────────────────────────────────────
class _CartPanel extends ConsumerWidget {
  final bool isDark;
  const _CartPanel({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billing = ref.watch(billingProvider);
    final customersAsync = ref.watch(customersProvider);

    return Column(
      children: [
        // ── Cart Header & Customer Selector ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Current Bill',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : AppColors.textLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${billing.totalItemCount} ITEMS',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (billing.items.isNotEmpty) ...[
                        IconButton(
                          icon: const Icon(Icons.pause_circle_outline_rounded, size: 20, color: Colors.amber),
                          tooltip: 'Hold / Park This Cart',
                          onPressed: () {
                            final err = ref.read(billingProvider.notifier).holdCurrentOrder();
                            if (err != null) {
                              AppAlert.warning(ref, err);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Cart parked successfully'), backgroundColor: Colors.amber),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_sweep_outlined, size: 20, color: AppColors.error),
                          tooltip: 'Clear Cart',
                          onPressed: () => ref.read(billingProvider.notifier).clearCart(),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Customer Dropdown & Active Price Category Flow
              customersAsync.when(
                data: (customers) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSearchableDropdown<int?>(
                      value: billing.selectedCustomerId,
                      labelText: 'Select Customer',
                      prefixIcon: Icons.person_rounded,
                      isDark: isDark,
                      addLabel: 'NEW',
                      onAdd: (name) => _quickAddCustomer(context, ref, name),
                      items: [
                        SearchableDropdownItem(value: null, label: 'Walk-in Customer (General)'),
                        ...customers.map((c) => SearchableDropdownItem(
                          value: c.id, 
                          label: '${c.name}${c.customerTypeName != null && c.customerTypeName!.trim().isNotEmpty ? " [${c.customerTypeName}]" : ""}'
                        )),
                      ],
                      onChanged: (v) {
                        if (v == null) {
                          ref.read(billingProvider.notifier).clearCustomer();
                          ref.read(_posPriceListProvider.notifier).state = 'Standard';
                        } else {
                          final c = customers.firstWhere((c) => c.id == v);
                          ref.read(billingProvider.notifier).selectCustomer(v, c.name);
                          if (c.customerTypeName != null && c.customerTypeName!.trim().isNotEmpty) {
                            ref.read(_posPriceListProvider.notifier).state = c.customerTypeName!;
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 6),
                    // Active Price Scale / Category Indicator
                    Consumer(
                      builder: (context, ref, _) {
                        final currentScale = ref.watch(_posPriceListProvider);
                        final selectedCust = billing.selectedCustomerId != null
                            ? customers.where((c) => c.id == billing.selectedCustomerId).firstOrNull
                            : null;
                        final activeScaleName = (selectedCust?.customerTypeName != null && selectedCust!.customerTypeName!.trim().isNotEmpty)
                            ? selectedCust.customerTypeName!
                            : currentScale;
                        final isNonStandard = activeScaleName != 'Standard';

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isNonStandard 
                                    ? Colors.indigo.withValues(alpha: 0.1) 
                                    : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isNonStandard 
                                      ? Colors.indigo.withValues(alpha: 0.3) 
                                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isNonStandard ? Icons.local_offer_rounded : Icons.price_check_rounded,
                                    size: 13,
                                    color: isNonStandard ? Colors.indigo : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Pricing: $activeScaleName',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isNonStandard ? Colors.indigo : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selectedCust != null && selectedCust.loyaltyPoints > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, size: 13, color: AppColors.warning),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${selectedCust.loyaltyPoints.toStringAsFixed(0)} Pts',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 10),
              // Payment Mode Selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AppConstants.paymentModes.map((mode) {
                    final isSelected = billing.paymentMode == mode;
                    return GestureDetector(
                      onTap: () => ref.read(billingProvider.notifier).setPaymentMode(mode),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : (isDark ? Colors.white.withValues(alpha: 0.04) : AppColors.lightBg),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                        ),
                        child: Text(
                          mode.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isSelected ? Colors.white : AppColors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── Bill Cart Items List ──
        Expanded(
          child: billing.items.isEmpty
              ? _EmptyCart()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: billing.items.length,
                  itemBuilder: (ctx, i) => _CartItemRow(item: billing.items[i], index: i),
                ),
        ),

        // ── Offers & Promotions Ribbon ──
        _OffersSection(isDark: isDark),

        // ── Bill Breakdown & Checkout ──
        _CheckoutSection(billing: billing, isDark: isDark),
      ],
    );
  }
}

// ── Cart Item Row ─────────────────────────────────────────────────────────────
class _CartItemRow extends ConsumerWidget {
  final PosItemModel item;
  final int index;
  const _CartItemRow({required this.item, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.priceScaleName != null) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.priceScaleName!.toUpperCase(),
                          style: const TextStyle(fontSize: 8, color: AppColors.primary, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${CurrencyFormatter.format(item.effectivePrice)} × ${item.quantity.toInt()} ${item.product.unit}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(item.total),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.primary),
                  ),
                  if (item.discount > 0)
                    Text(
                      '-${CurrencyFormatter.format(item.discount)}',
                      style: const TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w900),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: _QtyControl(
                  qty: item.quantity,
                  onChanged: (v) => ref.read(billingProvider.notifier).updateQuantity(index, v),
                ),
              ),
              const SizedBox(width: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PriceInput(
                    value: item.effectivePrice,
                    onChanged: (v) => _handlePriceOverride(context, ref, item, index, v),
                  ),
                  const SizedBox(width: 3),
                  _TierSelector(item: item, index: index),
                  const SizedBox(width: 2),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                    onPressed: () => ref.read(billingProvider.notifier).removeItem(index),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handlePriceOverride(BuildContext context, WidgetRef ref, PosItemModel item, int index, double newPrice) async {
    if (newPrice == item.effectivePrice) return;
    
    if (item.product.minSellingPrice > 0 && newPrice < item.product.minSellingPrice) {
      final approved = await _showManagerApprovalDialog(
        context,
        productName: item.product.name,
        requestedPrice: newPrice,
        minPrice: item.product.minSellingPrice,
      );
      if (!approved) {
        AppAlert.warning(ref, 'Price cannot be below minimum selling price ₹${item.product.minSellingPrice} without manager approval');
        return;
      }
    }
    
    ref.read(billingProvider.notifier).updatePrice(index, newPrice, scaleName: 'Manual Override');
  }
}

Future<bool> _showManagerApprovalDialog(
  BuildContext context, {
  required String productName,
  required double requestedPrice,
  required double minPrice,
}) async {
  final pinCtrl = TextEditingController();
  return await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Icon(Icons.gavel_rounded, color: Colors.orange, size: 24),
          SizedBox(width: 8),
          Text('Manager Approval Required', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Requested price ₹$requestedPrice for "$productName" is below minimum floor price ₹$minPrice.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          const Text('Enter Manager PIN / Authorization Code:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: pinCtrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Manager PIN',
              prefixIcon: const Icon(Icons.lock_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (pinCtrl.text.trim().isNotEmpty) {
              Navigator.pop(ctx, true);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
          child: const Text('Approve Override'),
        ),
      ],
    ),
  ) ?? false;
}

// ── Quantity Control Stepper ──────────────────────────────────────────────────
class _QtyControl extends StatefulWidget {
  final double qty;
  final Function(double) onChanged;
  const _QtyControl({required this.qty, required this.onChanged});

  @override
  State<_QtyControl> createState() => _QtyControlState();
}

class _QtyControlState extends State<_QtyControl> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _formatQty(widget.qty));
  }

  @override
  void didUpdateWidget(covariant _QtyControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.qty != widget.qty) {
      _ctrl.text = _formatQty(widget.qty);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _formatQty(double val) => val.truncateToDouble() == val ? val.toInt().toString() : val.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 16),
            onPressed: () => widget.onChanged(widget.qty - 1),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            color: AppColors.primary,
          ),
          SizedBox(
            width: 36,
            child: TextField(
              controller: _ctrl,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
              onSubmitted: (v) {
                final val = double.tryParse(v);
                if (val != null && val > 0) {
                  widget.onChanged(val);
                } else {
                  _ctrl.text = _formatQty(widget.qty);
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 16),
            onPressed: () => widget.onChanged(widget.qty + 1),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _PriceInput extends StatelessWidget {
  final double value;
  final Function(double) onChanged;
  const _PriceInput({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('₹', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success)),
          const SizedBox(width: 3),
          Expanded(
            child: TextField(
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.success),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
              controller: TextEditingController(text: value.toStringAsFixed(0)),
              onSubmitted: (v) => onChanged(double.tryParse(v) ?? value),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierSelector extends ConsumerStatefulWidget {
  final PosItemModel item;
  final int index;
  const _TierSelector({required this.item, required this.index});

  @override
  ConsumerState<_TierSelector> createState() => _TierSelectorState();
}

class _TierSelectorState extends ConsumerState<_TierSelector> {
  late Future<List<ProductTierPrice>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(productRepositoryProvider).getProductPrices(widget.item.product.id!);
  }

  @override
  void didUpdateWidget(covariant _TierSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.product.id != widget.item.product.id) {
      _future = ref.read(productRepositoryProvider).getProductPrices(widget.item.product.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductTierPrice>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        final tiers = snapshot.data!;

        return PopupMenuButton<double>(
          icon: const Icon(Icons.layers_rounded, size: 16, color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tooltip: 'Select Price Tier',
          onSelected: (price) {
            final tierName = price == widget.item.product.sellingPrice ? 'Retail' : tiers.firstWhere((t) => t.price == price).categoryName;
            ref.read(billingProvider.notifier).updatePrice(widget.index, price, scaleName: tierName);
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: widget.item.product.sellingPrice,
              child: Row(
                children: [
                  const Icon(Icons.shopping_cart_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Retail: ₹${CurrencyFormatter.format(widget.item.product.sellingPrice)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ],
              ),
            ),
            ...tiers.map((t) => PopupMenuItem(
              value: t.price,
              child: Row(
                children: [
                  const Icon(Icons.layers_rounded, size: 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  Text('${t.categoryName}: ₹${CurrencyFormatter.format(t.price)}', style: const TextStyle(fontSize: 13)),
                ],
              ),
            )),
          ],
        );
      },
    );
  }
}

// ── Offers Section ────────────────────────────────────────────────────────────
class _OffersSection extends ConsumerStatefulWidget {
  final bool isDark;
  const _OffersSection({required this.isDark});

  @override
  ConsumerState<_OffersSection> createState() => _OffersSectionState();
}

class _OffersSectionState extends ConsumerState<_OffersSection> {
  bool _isExpanded = false;

  String _getOfferDescription(Offer offer) {
    if (offer.offerType == 'buy_x_get_y') {
      return 'Buy ${offer.buyQty.toInt()} Get ${offer.getQty.toInt()} Free';
    } else if (offer.offerType == 'bill_amount') {
      final val = offer.discountType == 'percentage' ? '${offer.discountValue}%' : '₹${CurrencyFormatter.format(offer.discountValue)}';
      return 'Get $val off on ₹${CurrencyFormatter.format(offer.minAmount)}';
    } else {
      final val = offer.discountType == 'percentage' ? '${offer.discountValue}%' : '₹${CurrencyFormatter.format(offer.discountValue)}';
      return 'Flat $val off';
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(featureSettingsProvider);
    if (!settings.offersEnabled) return const SizedBox.shrink();

    final offers = ref.watch(offersProvider);
    final validOffers = offers.where((o) => o.isCurrentlyValid).toList();
    if (validOffers.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkCard : AppColors.lightBg,
        border: Border(top: BorderSide(color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Row(
              children: [
                const Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Promotions & Offers (${validOffers.length})', 
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: widget.isDark ? Colors.white : AppColors.textLight)
                ),
                const Spacer(),
                Icon(_isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 16),
              ],
            ),
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: validOffers.length,
                itemBuilder: (ctx, i) {
                  final offer = validOffers[i];
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(offer.name, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 12)),
                        Text(_getOfferDescription(offer), style: TextStyle(fontSize: 9, color: AppColors.primary.withValues(alpha: 0.8))),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Checkout Section ──────────────────────────────────────────────────────────
class _CheckoutSection extends ConsumerStatefulWidget {
  final BillingState billing;
  final bool isDark;
  const _CheckoutSection({required this.billing, required this.isDark});

  @override
  ConsumerState<_CheckoutSection> createState() => _CheckoutSectionState();
}

class _CheckoutSectionState extends ConsumerState<_CheckoutSection> {
  double _tenderAmount = 0;

  @override
  void didUpdateWidget(covariant _CheckoutSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.billing.grandTotal != widget.billing.grandTotal) {
      _tenderAmount = widget.billing.grandTotal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = ref.watch(shortcutSettingsProvider);
    final posPayShortcut = shortcuts['pos_pay'] ?? ShortcutNotifier.defaults['pos_pay']?.defaultShortcut ?? '';
    final finalizeBtnText = posPayShortcut.isNotEmpty ? 'FINALIZE ($posPayShortcut)' : 'FINALIZE TRANSACTION';

    final changeDue = _tenderAmount > widget.billing.grandTotal ? _tenderAmount - widget.billing.grandTotal : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkSidebar : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
        border: Border(top: BorderSide(color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.5)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: AppShortcut(
          actionId: 'pos_pay',
          onPressed: widget.billing.items.isEmpty || widget.billing.isProcessing
              ? null
              : () => _showCheckoutModal(context, widget.billing, widget.isDark, ref),
          child: ElevatedButton(
            onPressed: widget.billing.items.isEmpty || widget.billing.isProcessing
                ? null
                : () => _showCheckoutModal(context, widget.billing, widget.isDark, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.billing.items.length} Items',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70),
                    ),
                    Text(
                      '₹${CurrencyFormatter.format(widget.billing.grandTotal)}',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text('PROCEED', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCheckoutModal(BuildContext context, BillingState billing, bool isDark, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CheckoutBottomSheet(billing: billing, isDark: isDark, onCompleteSale: () {
        Navigator.pop(ctx);
        _handleCompleteSale(context, ref, billing);
      }, onQuickCash: () {
        Navigator.pop(ctx);
        _handleOneClickCashCheckout(context, ref, billing);
      }),
    );
  }

  void _showDiscountDialog(BuildContext context, WidgetRef ref) {
    final discCtrl = TextEditingController(text: widget.billing.manualDiscount > 0 ? widget.billing.manualDiscount.toString() : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Apply Bill Discount', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: discCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Discount Amount (₹)',
                prefixIcon: Icon(Icons.discount_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [5, 10, 15, 20].map((pct) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: OutlinedButton(
                      child: Text('$pct%'),
                      onPressed: () {
                        final val = (widget.billing.subtotal * pct / 100);
                        discCtrl.text = val.toStringAsFixed(0);
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(discCtrl.text) ?? 0.0;
              ref.read(billingProvider.notifier).setDiscount(val);
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showNotesDialog(BuildContext context, WidgetRef ref) {
    final notesCtrl = TextEditingController(text: widget.billing.notes ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Transaction Notes', style: TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: notesCtrl,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Add PO number, delivery instructions, or notes...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              ref.read(billingProvider.notifier).setNotes(notesCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  void _handleOneClickCashCheckout(BuildContext context, WidgetRef ref, BillingState billing) async {
    ref.read(billingProvider.notifier).setPaymentMode('Cash');
    final isEditing = billing.editingSaleId != null;
    final saleId = await ref.read(billingProvider.notifier).completeSale();
    if (saleId != null) {
      if (context.mounted) {
        _printReceipt(context, ref, saleId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cash checkout finalized. Receipt generated.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
        ref.read(_posPriceListProvider.notifier).state = 'Retail';
        ref.read(_posSearchProvider.notifier).state = '';
        ref.read(_posCategoryProvider.notifier).state = null;
        ref.read(_posStockFilterProvider.notifier).state = 'all';
        if (isEditing) {
          Navigator.pop(context);
        }
      }
    } else {
      AppAlert.error(ref, 'One-click checkout failed: ${billing.lastError ?? "Unknown Error"}');
    }
  }

  void _handleCompleteSale(BuildContext context, WidgetRef ref, BillingState billing) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Confirm Transaction', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SummaryRow('Customer', billing.selectedCustomerName ?? 'Walk-in'),
            _SummaryRow('Total Items', billing.totalItemCount.toString()),
            _SummaryRow('Payment Mode', billing.paymentMode),
            _SummaryRow('Final Amount', '₹${CurrencyFormatter.format(billing.grandTotal)}', isBold: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Confirm & Finalize')
          ),
        ],
      ),
    );

    if (confirm == true) {
      final isEditing = billing.editingSaleId != null;
      final saleId = await ref.read(billingProvider.notifier).completeSale();
      if (saleId != null) {
        if (context.mounted) {
          _onSaleSuccess(context, ref, saleId, isEditing);
        }
      } else {
        AppAlert.error(ref, 'Transaction failed. ${ref.read(billingProvider).lastError ?? ''}');
      }
    }
  }

  void _onSaleSuccess(BuildContext context, WidgetRef ref, int saleId, bool isEditing) async {
    final printNow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 56),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Transaction Complete!', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Sale has been recorded and inventory updated successfully.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('New Sale')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.print_rounded),
            label: const Text('Print Receipt'),
          ),
        ],
      ),
    );

    if (printNow == true && context.mounted) {
      _printReceipt(context, ref, saleId);
    }

    ref.read(_posPriceListProvider.notifier).state = 'Retail';
    ref.read(_posSearchProvider.notifier).state = '';
    ref.read(_posCategoryProvider.notifier).state = null;
    ref.read(_posStockFilterProvider.notifier).state = 'all';

    if (isEditing && context.mounted) {
      Navigator.pop(context);
    }
  }

  void _printReceipt(BuildContext context, WidgetRef ref, int saleId) async {
    final business = ref.read(currentBusinessProvider);
    final sale = await ref.read(saleDetailProvider(saleId).future);
    if (business != null && sale != null) {
      await InvoiceService.generateAndPrintInvoice(business: business, sale: sale);
    }
  }
}

class _TenderChip extends StatelessWidget {
  final String label;
  final double amount;
  final Function(double) onSelect;

  const _TenderChip({required this.label, required this.amount, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(amount),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final double value;
  final Color? color;
  const _BillRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMuted, fontSize: 12)),
        Text(
          '₹${CurrencyFormatter.format(value)}',
          style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 13),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  const _SummaryRow(this.label, this.value, {this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.w800, fontSize: isBold ? 18 : 14, color: isBold ? AppColors.primary : null)),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: AppColors.textMuted.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(query.isEmpty ? 'Catalog is empty' : 'No items match "$query"', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_basket_outlined, size: 56, color: AppColors.textMuted.withValues(alpha: 0.15)),
            const SizedBox(height: 14),
            const Text('Bill is currently empty', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textMuted, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('Tap items in catalog or scan barcode', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

void _quickAddCustomer(BuildContext context, WidgetRef ref, String name) async {
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();
  final gstController = TextEditingController();
  final balanceController = TextEditingController(text: '0.0');
  int? selectedTypeId;
  String? selectedTypeName;

  final customerTypes = ref.read(customerTypesProvider).value ?? [];
  
  final result = await showDialog<CustomerModel?>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.person_add_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            const Text('Quick Add Customer', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: TextEditingController(text: name),
                  onChanged: (v) => name = v,
                  decoration: const InputDecoration(labelText: 'Full Name*', prefixIcon: Icon(Icons.person_rounded)),
                ),
                const SizedBox(height: 16),
                if (customerTypes.isNotEmpty) ...[
                  DropdownButtonFormField<int?>(
                    value: selectedTypeId,
                    decoration: const InputDecoration(
                      labelText: 'Customer Type / Pricing Category',
                      prefixIcon: Icon(Icons.category_rounded),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Standard / Retail Customer')),
                      ...customerTypes.map((t) => DropdownMenuItem(
                        value: t.id,
                        child: Text(t.name),
                      )),
                    ],
                    onChanged: (v) {
                      setState(() {
                        selectedTypeId = v;
                        selectedTypeName = customerTypes.where((t) => t.id == v).firstOrNull?.name;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: phoneController,
                        decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_rounded)),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_rounded)),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on_rounded)),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (ref.watch(featureSettingsProvider).gstEnabled)
                      Expanded(
                        child: TextField(
                          controller: gstController,
                          decoration: const InputDecoration(labelText: 'GST Number', prefixIcon: Icon(Icons.tag_rounded)),
                          textCapitalization: TextCapitalization.characters,
                        ),
                      ),
                    if (ref.watch(featureSettingsProvider).gstEnabled)
                      const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: balanceController,
                        decoration: const InputDecoration(labelText: 'Opening Balance', prefixIcon: Icon(Icons.account_balance_wallet_rounded)),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (name.trim().isEmpty) return;
              final bizId = ref.read(activeBusinessIdProvider);
              
              final newCustomer = CustomerModel(
                name: name.trim(),
                phone: phoneController.text.trim(),
                email: emailController.text.trim(),
                address: addressController.text.trim(),
                gstNumber: gstController.text.trim().toUpperCase(),
                customerTypeId: selectedTypeId,
                customerTypeName: selectedTypeName,
                balance: double.tryParse(balanceController.text) ?? 0.0,
                businessId: bizId,
              );
              Navigator.pop(ctx, newCustomer);
            },
            child: const Text('Save & Select'),
          ),
        ],
      ),
    ),
  );

  if (result != null) {
    final success = await ref.read(customerFormProvider.notifier).saveCustomer(result);
    if (success) {
      final customers = await ref.read(customersProvider.future);
      final added = customers.firstWhere((c) => c.name == result.name && (result.phone == null || c.phone == result.phone));
      ref.read(billingProvider.notifier).selectCustomer(added.id!, added.name);
      if (added.customerTypeName != null && added.customerTypeName!.trim().isNotEmpty) {
        ref.read(_posPriceListProvider.notifier).state = added.customerTypeName!;
      }
      AppAlert.success(ref, 'Customer added successfully with ${added.customerTypeName ?? "Standard"} pricing');
    } else {
      AppAlert.error(ref, 'Failed to add customer');
    }
  }
}

class _MobileCartSheet extends ConsumerWidget {
  final bool isDark;
  const _MobileCartSheet({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billing = ref.watch(billingProvider);
    if (billing.items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 25)],
        border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${billing.totalItemCount} ITEMS IN CART', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 0.5)),
                Text('₹${CurrencyFormatter.format(billing.grandTotal)}', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: -1)),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => Container(
                    height: MediaQuery.of(context).size.height * 0.9,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: _CartPanel(isDark: isDark),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('REVIEW BILL', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmbeddedScanner extends StatefulWidget {
  final Function(String) onScan;
  final bool isDark;
  final VoidCallback? onClose;
  final int initialCameraIndex;

  const _EmbeddedScanner({required this.onScan, required this.isDark, this.onClose, this.initialCameraIndex = 0});

  @override
  State<_EmbeddedScanner> createState() => _EmbeddedScannerState();
}

class _EmbeddedScannerState extends State<_EmbeddedScanner> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  late int _selectedCameraIndex;

  @override
  void initState() {
    super.initState();
    _selectedCameraIndex = widget.initialCameraIndex;
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        if (_selectedCameraIndex >= _cameras!.length) {
          _selectedCameraIndex = 0;
        }

        if (_controller != null) {
          final old = _controller;
          _controller = null;
          try {
            await old?.dispose();
          } catch (_) {}
        }

        final cameraDesc = _cameras![_selectedCameraIndex];
        CameraController? newController;
        final presets = [
          ResolutionPreset.medium,
          ResolutionPreset.low,
          ResolutionPreset.high,
        ];

        for (final preset in presets) {
          try {
            newController = CameraController(
              cameraDesc,
              preset,
              enableAudio: false,
            );
            await newController.initialize();
            if (newController.value.isInitialized) {
              break;
            }
          } catch (e) {
            if (kDebugMode) debugPrint('Preset $preset failed: $e');
            try {
              await newController?.dispose();
            } catch (_) {}
            newController = null;
          }
        }

        if (mounted) {
          setState(() {
            _controller = newController;
            _isInitialized = newController != null && newController.value.isInitialized;
          });
        } else {
          try {
            await newController?.dispose();
          } catch (_) {}
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Camera init error: $e');
    }
  }

  @override
  void dispose() {
    final c = _controller;
    _controller = null;
    try {
      c?.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Container(
        height: 120,
        width: 180,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.videocam_off_rounded, color: AppColors.warning, size: 24),
                  const SizedBox(height: 4),
                  const Text(
                    'Camera In Use / Off',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_cameras != null && _cameras!.length > 1)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
                            });
                            _initCamera();
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.cameraswitch_rounded, size: 12, color: AppColors.primary),
                                SizedBox(width: 2),
                                Text('Switch', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      InkWell(
                        onTap: () => _initCamera(),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            children: [
                              Icon(Icons.refresh_rounded, size: 12, color: AppColors.primary),
                              SizedBox(width: 2),
                              Text('Retry', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (widget.onClose != null)
              Positioned(
                top: 0,
                right: 0,
                child: InkWell(
                  onTap: widget.onClose,
                  child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      height: 120,
      width: 160,
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            CameraPreview(_controller!),
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                onTap: () {
                  if (widget.onClose != null) {
                    widget.onClose!();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                ),
              ),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              child: InkWell(
                onTap: () {
                  if (_cameras != null && _cameras!.length > 1) {
                    setState(() {
                      _isInitialized = false;
                      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
                    });
                    _initCamera();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 16),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Checkout Bottom Sheet ─────────────────────────────────────────────────────
class _CheckoutBottomSheet extends ConsumerStatefulWidget {
  final BillingState billing;
  final bool isDark;
  final VoidCallback onCompleteSale;
  final VoidCallback onQuickCash;

  const _CheckoutBottomSheet({
    required this.billing,
    required this.isDark,
    required this.onCompleteSale,
    required this.onQuickCash,
  });

  @override
  ConsumerState<_CheckoutBottomSheet> createState() => _CheckoutBottomSheetState();
}

class _CheckoutBottomSheetState extends ConsumerState<_CheckoutBottomSheet> {
  double _tenderAmount = 0;
  double _redeemPoints = 0;

  @override
  void initState() {
    super.initState();
    _tenderAmount = widget.billing.grandTotal;
    _redeemPoints = widget.billing.pointsRedeemed;
  }

  @override
  void didUpdateWidget(covariant _CheckoutBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.billing.grandTotal != widget.billing.grandTotal) {
      _tenderAmount = widget.billing.grandTotal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final changeDue = _tenderAmount > widget.billing.grandTotal ? _tenderAmount - widget.billing.grandTotal : 0.0;
    
    final loyaltySettings = ref.watch(loyaltySettingsProvider);
    final selectedCust = widget.billing.selectedCustomerId != null
        ? ref.watch(customersProvider).value?.where((c) => c.id == widget.billing.selectedCustomerId).firstOrNull
        : null;

    final canRedeem = selectedCust != null && 
        selectedCust.loyaltyPoints > 0 && 
        loyaltySettings != null && 
        loyaltySettings.isActive;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkSidebar : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
        border: Border(top: BorderSide(color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.5)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Text(
                'Complete Sale',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 20),
              
              if (canRedeem) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, color: AppColors.warning, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Loyalty Points',
                                style: TextStyle(fontWeight: FontWeight.w900, color: widget.isDark ? Colors.white : AppColors.textLight),
                              ),
                            ],
                          ),
                          Text(
                            'Available: ${selectedCust.loyaltyPoints.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: AppColors.warning,
                                thumbColor: AppColors.warning,
                                overlayColor: AppColors.warning.withValues(alpha: 0.2),
                              ),
                              child: Slider(
                                value: _redeemPoints.clamp(0.0, selectedCust.loyaltyPoints.clamp(0.0, loyaltySettings.maxRedeemLimit > 0 ? loyaltySettings.maxRedeemLimit.toDouble() : double.infinity).toDouble()),
                                max: selectedCust.loyaltyPoints.clamp(0.0, loyaltySettings.maxRedeemLimit > 0 ? loyaltySettings.maxRedeemLimit.toDouble() : double.infinity).toDouble(),
                                divisions: selectedCust.loyaltyPoints > 0 ? selectedCust.loyaltyPoints.toInt() : 1,
                                label: _redeemPoints.round().toString(),
                                onChanged: (val) {
                                  setState(() => _redeemPoints = val);
                                  ref.read(billingProvider.notifier).redeemPoints(val);
                                },
                              ),
                            ),
                          ),
                          Container(
                            width: 60,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: widget.isDark ? AppColors.darkCard : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            ),
                            child: Text(
                              _redeemPoints.round().toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      if (widget.billing.loyaltyDiscount > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          'You save: ₹${CurrencyFormatter.format(widget.billing.loyaltyDiscount)}',
                          style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Subtotals & Discounts
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.black.withValues(alpha: 0.25) : AppColors.lightBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _BillRow(label: 'Subtotal', value: widget.billing.subtotal),
                    if (ref.watch(featureSettingsProvider).gstEnabled) ...[
                      const SizedBox(height: 8),
                      _BillRow(
                        label: widget.billing.isTaxInclusive ? 'Tax (Incl. in Total)' : 'Total GST', 
                        value: widget.billing.totalGst,
                        color: widget.billing.isTaxInclusive ? AppColors.textMuted : null,
                      ),
                    ],
                    if (widget.billing.pointsRedeemed > 0) ...[
                      const SizedBox(height: 8),
                      _BillRow(
                        label: 'Loyalty Points Used (${widget.billing.pointsRedeemed.toStringAsFixed(0)} pts)', 
                        value: -widget.billing.loyaltyDiscount, 
                        color: AppColors.success
                      ),
                    ],
                    if (widget.billing.totalDiscounts > widget.billing.loyaltyDiscount) ...[
                      const SizedBox(height: 8),
                      _BillRow(
                        label: widget.billing.pointsRedeemed > 0 ? 'Other Discounts & Offers' : 'Discounts & Offers', 
                        value: -(widget.billing.totalDiscounts - widget.billing.loyaltyDiscount), 
                        color: AppColors.success
                      ),
                    ],
                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'GRAND TOTAL',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                        Text(
                          '₹${CurrencyFormatter.format(widget.billing.grandTotal)}',
                          style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: -1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (widget.billing.paymentMode == 'Cash' && widget.billing.items.isNotEmpty) ...[
                // Quick Cash Tender Suggester
                Row(
                  children: [
                    _TenderChip(label: 'Exact', amount: widget.billing.grandTotal, onSelect: (a) => setState(() => _tenderAmount = a)),
                    const SizedBox(width: 6),
                    _TenderChip(label: '₹500', amount: 500, onSelect: (a) => setState(() => _tenderAmount = a)),
                    const SizedBox(width: 6),
                    _TenderChip(label: '₹1000', amount: 1000, onSelect: (a) => setState(() => _tenderAmount = a)),
                    const SizedBox(width: 6),
                    _TenderChip(label: '₹2000', amount: 2000, onSelect: (a) => setState(() => _tenderAmount = a)),
                  ],
                ),
                if (changeDue > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Change to Return:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.warning)),
                        Text('₹${CurrencyFormatter.format(changeDue)}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.warning)),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
              ],

              // Finalize Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: widget.billing.items.isEmpty || widget.billing.isProcessing
                      ? null
                      : widget.onCompleteSale,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 8,
                  ),
                  child: widget.billing.isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 24),
                            const SizedBox(width: 10),
                            Text('FINALIZE TRANSACTION', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 0.5)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 10),
              // 1-Click Quick Cash Checkout
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: widget.billing.items.isEmpty || widget.billing.isProcessing
                      ? null
                      : widget.onQuickCash,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.flash_on_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text('QUICK CASH OUT', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
