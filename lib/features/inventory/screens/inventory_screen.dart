// lib/features/inventory/screens/inventory_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/layout_toggle.dart';
import '../models/product_model.dart';
import '../providers/inventory_provider.dart';
import 'add_edit_product_screen.dart';
import '../../../core/widgets/category_manager_screen.dart';
import '../../../core/providers/notification_provider.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  LayoutMode _layoutMode = LayoutMode.grid;

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final filter = ref.watch(inventoryFilterProvider);
    final productsAsync = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final statsAsync = ref.watch(inventoryStatsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _InventoryHeader(
              isDark: isDark,
              filter: filter,
              ref: ref,
              layoutMode: _layoutMode,
              onLayoutChanged: (m) => setState(() => _layoutMode = m),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(
              child: statsAsync.when(
                data: (s) => _InventoryStatsStrip(stats: s, isDark: isDark),
                loading: () => const _StatsSkeleton(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            sliver: SliverToBoxAdapter(
              child: categoriesAsync.when(
                data: (cats) => _FilterBar(categories: cats, filter: filter, isDark: isDark, ref: ref),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
            sliver: productsAsync.when(
              data: (products) => products.isEmpty
                  ? SliverFillRemaining(child: _EmptyState(isDark: isDark))
                  : (_layoutMode == LayoutMode.grid
                      ? _ProductGrid(products: products, isDark: isDark)
                      : SliverToBoxAdapter(
                          child: _ProductTable(products: products, isDark: isDark),
                        )),
              loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SliverFillRemaining(child: Center(child: Text('Error: $e'))),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'inventory_fab',
        onPressed: () => _openAddProduct(context),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ).animate().scale(delay: 500.ms, curve: Curves.elasticOut),
    );
  }

  void _openAddProduct(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddEditProductScreen()));
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _InventoryHeader extends StatefulWidget {
  final bool isDark;
  final InventoryFilter filter;
  final WidgetRef ref;
  final LayoutMode layoutMode;
  final ValueChanged<LayoutMode> onLayoutChanged;

  const _InventoryHeader({
    required this.isDark,
    required this.filter,
    required this.ref,
    required this.layoutMode,
    required this.onLayoutChanged,
  });

  @override
  State<_InventoryHeader> createState() => _InventoryHeaderState();
}

class _InventoryHeaderState extends State<_InventoryHeader> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.filter.searchQuery);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: isMobile 
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inventory Master',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  color: widget.isDark ? Colors.white : AppColors.textLight,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => widget.ref.read(inventoryFilterProvider.notifier).update((s) => s.copyWith(searchQuery: v)),
                      decoration: InputDecoration(
                        hintText: 'Search SKU, name, barcode...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: widget.isDark ? AppColors.darkCard : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.receipt_long_rounded),
                    tooltip: 'Stock Movement Ledger',
                    onPressed: () => _showStockLedgerDialog(context, widget.ref),
                  ),
                  const SizedBox(width: 8),
                  LayoutToggle(
                    current: widget.layoutMode,
                    onChanged: widget.onLayoutChanged,
                    isDark: widget.isDark,
                  ),
                ],
              ),
            ],
          )
        : Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inventory & Stock Control',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                        color: widget.isDark ? Colors.white : AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.inventory_2_rounded, size: 14, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Transaction-driven stock ledger, price levels & batch tracking',
                          style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => widget.ref.read(inventoryFilterProvider.notifier).update((s) => s.copyWith(searchQuery: v)),
                  decoration: InputDecoration(
                    hintText: 'Search SKU, barcode...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: widget.isDark ? AppColors.darkCard : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showStockLedgerDialog(context, widget.ref),
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: const Text('Stock Ledger'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.category_rounded, color: AppColors.primary),
                onPressed: () => _showCategoryManager(context),
                tooltip: 'Manage Categories',
                style: IconButton.styleFrom(
                  backgroundColor: widget.isDark ? AppColors.darkCard : Colors.white,
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(width: 12),
              LayoutToggle(
                current: widget.layoutMode,
                onChanged: widget.onLayoutChanged,
                isDark: widget.isDark,
              ),
            ],
          ),
    );
  }

  void _showCategoryManager(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryManagerScreen(
          title: 'Product Categories',
          categoriesProvider: categoriesProvider,
          onSave: (name, id) => widget.ref.read(productFormProvider.notifier).saveCategory(Category(id: id, name: name)),
          onDelete: (id) => widget.ref.read(productFormProvider.notifier).deleteCategory(id),
        ),
      ),
    );
  }
}

// ── Stats Strip ───────────────────────────────────────────────────────────────
class _InventoryStatsStrip extends StatelessWidget {
  final Map<String, dynamic> stats;
  final bool isDark;

  const _InventoryStatsStrip({required this.stats, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _StatCard(
            label: 'Total Inventory Valuation',
            value: CurrencyFormatter.format((stats['inventory_value'] as num?)?.toDouble() ?? 0),
            icon: Icons.account_balance_wallet_rounded,
            colors: [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
            isDark: isDark,
          ),
          const SizedBox(width: 16),
          _StatCard(
            label: 'Total Products',
            value: '${stats['total_products'] ?? 0}',
            icon: Icons.layers_rounded,
            colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
            isDark: isDark,
          ),
          const SizedBox(width: 16),
          _StatCard(
            label: 'Low Stock Alert',
            value: '${stats['low_stock_count'] ?? 0}',
            icon: Icons.warning_amber_rounded,
            colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
            isDark: isDark,
          ),
          const SizedBox(width: 16),
          _StatCard(
            label: 'Out of Stock',
            value: '${stats['out_of_stock_count'] ?? 0}',
            icon: Icons.error_outline_rounded,
            colors: [const Color(0xFFEF4444), const Color(0xFFDC2626)],
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> colors;
  final bool isDark;

  const _StatCard({required this.label, required this.value, required this.icon, required this.colors, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth < 500 ? (screenWidth - 64) : 220.0;

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: colors[0].withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            top: -15,
            child: Icon(icon, color: Colors.white.withValues(alpha: 0.12), size: 80),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                ),
              ),
              Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, curve: Curves.easeOutCubic);
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (i) => Container(
        width: 160, height: 70, margin: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.darkBorder, borderRadius: BorderRadius.circular(20)),
      ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms)),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final List<Category> categories;
  final InventoryFilter filter;
  final bool isDark;
  final WidgetRef ref;

  const _FilterBar({required this.categories, required this.filter, required this.isDark, required this.ref});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _CategoryChip(
            label: 'All Items',
            isSelected: filter.categoryId == null && !filter.lowStockOnly,
            onTap: () => ref.read(inventoryFilterProvider.notifier).update((s) => s.copyWith(clearCategory: true, lowStockOnly: false)),
            isDark: isDark,
          ),
          const SizedBox(width: 12),
          _CategoryChip(
            label: 'Low Stock Alerts',
            icon: Icons.warning_amber_rounded,
            isSelected: filter.lowStockOnly,
            onTap: () => ref.read(inventoryFilterProvider.notifier).update((s) => s.copyWith(lowStockOnly: !s.lowStockOnly)),
            activeColor: const Color(0xFFF59E0B),
            isDark: isDark,
          ),
          const SizedBox(width: 12),
          ...categories.map((c) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _CategoryChip(
                  label: c.name,
                  isSelected: filter.categoryId == c.id,
                  onTap: () => ref.read(inventoryFilterProvider.notifier).update((s) => s.copyWith(categoryId: c.id)),
                  isDark: isDark,
                ),
              )),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;
  final bool isDark;

  const _CategoryChip({required this.label, this.icon, required this.isSelected, required this.onTap, this.activeColor = AppColors.primary, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? activeColor : (isDark ? AppColors.darkBorder : AppColors.lightBorder), width: 1.5),
        ),
        child: Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: isSelected ? Colors.white : activeColor), const SizedBox(width: 8)],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
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

// ── Grid Layout ───────────────────────────────────────────────────────────────
class _ProductGrid extends StatelessWidget {
  final List<Product> products;
  final bool isDark;
  const _ProductGrid({required this.products, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossCount = width > 1400 ? 5 : (width > 1100 ? 4 : (width > 800 ? 3 : (width > 500 ? 2 : 1)));
    final aspectRatio = width < 500 ? 0.85 : (width < 900 ? 0.95 : 1.05);

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: aspectRatio,
      ),
      delegate: SliverChildBuilderDelegate(
        (_, i) => _ProductCard(product: products[i], isDark: isDark)
            .animate(delay: (i * 30).ms)
            .fadeIn()
            .slideY(begin: 0.05),
        childCount: products.length,
      ),
    );
  }
}

class _ProductCard extends ConsumerStatefulWidget {
  final Product product;
  final bool isDark;
  const _ProductCard({required this.product, required this.isDark});

  @override
  ConsumerState<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<_ProductCard> {
  bool _hovered = false;

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Archive Product?'),
        content: Text('Remove "${widget.product.name}" from active inventory?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final productId = widget.product.id!;
              final productName = widget.product.name;
              await ref.read(productFormProvider.notifier).deleteProduct(productId);
              ref.read(notificationProvider.notifier).showWithUndo(
                message: '"$productName" archived',
                onUndo: () async {
                  await ref.read(productRepositoryProvider).restoreProduct(productId);
                  ref.invalidate(productsProvider);
                  ref.invalidate(inventoryStatsProvider);
                  AppAlert.success(ref, '"$productName" has been restored');
                },
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.product.isOutOfStock 
        ? const Color(0xFFEF4444) 
        : (widget.product.isLowStock ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddEditProductScreen(product: widget.product))),
        child: AnimatedContainer(
          duration: 300.ms,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _hovered ? AppColors.primary : (widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _hovered 
                  ? AppColors.primary.withValues(alpha: 0.1) 
                  : (widget.isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04)),
                blurRadius: _hovered ? 25 : 15,
                offset: _hovered ? const Offset(0, 10) : const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08), 
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                    ),
                    child: widget.product.imagePath != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(File(widget.product.imagePath!), fit: BoxFit.cover))
                        : const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 24),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.04), borderRadius: BorderRadius.circular(10)),
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textMuted.withValues(alpha: 0.8)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onSelected: (val) async {
                        if (val == 'edit') {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddEditProductScreen(product: widget.product)));
                        } else if (val == 'ledger') {
                          _showStockLedgerDialog(context, ref, productId: widget.product.id, productName: widget.product.name);
                        } else if (val == 'adjust') {
                          _showStockAdjustmentDialog(context, ref, widget.product);
                        } else if (val == 'duplicate') {
                          final success = await ref.read(productFormProvider.notifier).duplicateProduct(widget.product);
                          if (success) AppAlert.success(ref, 'Product duplicated');
                        } else if (val == 'delete') {
                          _confirmDelete(context, ref);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 12), Text('Edit')])),
                        const PopupMenuItem(value: 'ledger', child: Row(children: [Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.primary), SizedBox(width: 12), Text('Stock Ledger')])),
                        const PopupMenuItem(value: 'adjust', child: Row(children: [Icon(Icons.tune_rounded, size: 18, color: Colors.orange), SizedBox(width: 12), Text('Stock Adjustment')])),
                        const PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy_rounded, size: 18), SizedBox(width: 12), Text('Duplicate')])),
                        const PopupMenuDivider(),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error), SizedBox(width: 12), Text('Archive', style: TextStyle(color: AppColors.error))])),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.product.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1.1),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.product.sku ?? (widget.product.barcode ?? 'NO SKU'),
                      style: const TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(width: 3, height: 3, decoration: const BoxDecoration(color: AppColors.textMuted, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.product.categoryName ?? 'General',
                      style: const TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            CurrencyFormatter.format(widget.product.sellingPrice),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: -0.6),
                          ),
                        ),
                        Text(
                          'COST: ${CurrencyFormatter.format(widget.product.purchasePrice)}',
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1), 
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            CurrencyFormatter.formatQty(widget.product.stock),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: statusColor, height: 1),
                          ),
                        ),
                        Text(
                          widget.product.unit.toUpperCase(),
                          style: TextStyle(fontSize: 7, color: statusColor, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ],
                    ),
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

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_rounded, size: 90, color: AppColors.primary.withValues(alpha: 0.12)),
          const SizedBox(height: 20),
          const Text('Inventory is empty', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          const Text('Click "+ Add Product" to create your product master.', style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ).animate().fadeIn(),
    );
  }
}

// ── Table Layout ──────────────────────────────────────────────────────────────
class _ProductTable extends ConsumerStatefulWidget {
  final List<Product> products;
  final bool isDark;
  const _ProductTable({required this.products, required this.isDark});

  @override
  ConsumerState<_ProductTable> createState() => _ProductTableState();
}

class _ProductTableState extends ConsumerState<_ProductTable> {
  int _sortColumn = 0;
  bool _sortAscending = true;
  late List<Product> _sorted;

  @override
  void initState() {
    super.initState();
    _sorted = List.from(widget.products);
  }

  @override
  void didUpdateWidget(_ProductTable old) {
    super.didUpdateWidget(old);
    if (old.products != widget.products) _applySort(widget.products);
  }

  void _applySort(List<Product> src) {
    final list = List<Product>.from(src);
    list.sort((a, b) {
      int cmp;
      switch (_sortColumn) {
        case 0: cmp = a.name.compareTo(b.name); break;
        case 1: cmp = (a.sku ?? '').compareTo(b.sku ?? ''); break;
        case 2: cmp = (a.categoryName ?? '').compareTo(b.categoryName ?? ''); break;
        case 3: cmp = a.purchasePrice.compareTo(b.purchasePrice); break;
        case 4: cmp = a.sellingPrice.compareTo(b.sellingPrice); break;
        case 5: cmp = a.stock.compareTo(b.stock); break;
        default: cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
    setState(() => _sorted = list);
  }

  void _onSort(int col, bool asc) {
    _sortColumn = col;
    _sortAscending = asc;
    _applySort(widget.products);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          sortColumnIndex: _sortColumn,
          sortAscending: _sortAscending,
          headingRowColor: WidgetStateProperty.all(
            isDark ? Colors.white.withValues(alpha: 0.04) : AppColors.lightBg,
          ),
          headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.3),
          dataTextStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          dividerThickness: 1,
          columnSpacing: 20,
          columns: [
            DataColumn(label: const Text('Product Name'), onSort: _onSort),
            DataColumn(label: const Text('SKU / Code'), onSort: _onSort),
            DataColumn(label: const Text('Category'), onSort: _onSort),
            DataColumn(label: const Text('Cost (WAC)'), numeric: true, onSort: _onSort),
            DataColumn(label: const Text('Selling Price'), numeric: true, onSort: _onSort),
            DataColumn(label: const Text('Stock Level'), numeric: true, onSort: _onSort),
            const DataColumn(label: Text('Status')),
            const DataColumn(label: Text('Actions')),
          ],
          rows: _sorted.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final statusColor = p.isOutOfStock
                ? const Color(0xFFEF4444)
                : (p.isLowStock ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
            final statusLabel = p.isOutOfStock ? 'Out of Stock' : (p.isLowStock ? 'Low Stock' : 'In Stock');

            return DataRow(
              color: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) return AppColors.primary.withValues(alpha: 0.04);
                return i.isOdd
                    ? (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.withValues(alpha: 0.02))
                    : null;
              }),
              cells: [
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: p.imagePath != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(p.imagePath!), fit: BoxFit.cover))
                            : const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (p.brand != null && p.brand!.isNotEmpty)
                            Text(p.brand!, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddEditProductScreen(product: p))),
                ),
                DataCell(Text(p.sku ?? '—', style: const TextStyle(color: AppColors.textMuted))),
                DataCell(Text(p.categoryName ?? '—', style: const TextStyle(color: AppColors.textMuted))),
                DataCell(Text(CurrencyFormatter.format(p.purchasePrice))),
                DataCell(Text(CurrencyFormatter.format(p.sellingPrice), style: const TextStyle(fontWeight: FontWeight.w800))),
                DataCell(Text('${CurrencyFormatter.formatQty(p.stock)} ${p.unit}', style: TextStyle(color: statusColor, fontWeight: FontWeight.w800))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ),
                DataCell(_TableProductActions(product: p)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TableProductActions extends ConsumerWidget {
  final Product product;
  const _TableProductActions({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.primary),
          tooltip: 'Stock Ledger',
          visualDensity: VisualDensity.compact,
          onPressed: () => _showStockLedgerDialog(context, ref, productId: product.id, productName: product.name),
        ),
        IconButton(
          icon: const Icon(Icons.tune_rounded, size: 16, color: Colors.orange),
          tooltip: 'Adjust Stock',
          visualDensity: VisualDensity.compact,
          onPressed: () => _showStockAdjustmentDialog(context, ref, product),
        ),
        IconButton(
          icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
          tooltip: 'Edit',
          visualDensity: VisualDensity.compact,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddEditProductScreen(product: product))),
        ),
      ],
    );
  }
}

// ── Stock Adjustment Modal Dialog ─────────────────────────────────────────────
void _showStockAdjustmentDialog(BuildContext context, WidgetRef ref, Product product) {
  final qtyCtrl = TextEditingController();
  final reasonCtrl = TextEditingController();
  String selectedType = 'PHYSICAL_DISCREPANCY';
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.tune_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 10),
            Text('Adjust Stock: ${product.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Ledger Stock:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('${product.stock} ${product.unit}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.orange)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Adjustment Reason Type *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'PHYSICAL_DISCREPANCY', child: Text('Physical Count Discrepancy')),
                    DropdownMenuItem(value: 'DAMAGE', child: Text('Damaged Goods / Breakage')),
                    DropdownMenuItem(value: 'WASTAGE', child: Text('Wastage / Spoilage')),
                    DropdownMenuItem(value: 'EXPIRED', child: Text('Expired Inventory')),
                    DropdownMenuItem(value: 'RETURN_TO_STOCK', child: Text('Found / Returned Stock')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedType = v ?? 'PHYSICAL_DISCREPANCY'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Quantity Change (+ or -) *',
                    hintText: 'e.g. -2 for damage, +5 for found stock',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter adjustment quantity';
                    final numVal = double.tryParse(v);
                    if (numVal == null || numVal == 0) return 'Must be a non-zero number';
                    if (product.stock + numVal < 0) return 'Cannot reduce stock below 0';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Mandatory Audit Note *',
                    hintText: 'Describe why this adjustment is being made...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v?.trim().isEmpty == true ? 'Reason is required for audit trail' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final qty = double.parse(qtyCtrl.text.trim());
              final reason = reasonCtrl.text.trim();
              Navigator.pop(ctx);

              final success = await ref.read(productFormProvider.notifier).recordStockAdjustment(
                productId: product.id!,
                adjustedQty: qty,
                adjustmentType: selectedType,
                reason: reason,
              );

              if (success) {
                ref.invalidate(productsProvider);
                ref.invalidate(inventoryStatsProvider);
                AppAlert.success(ref, 'Stock adjusted and logged in Stock Ledger.');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Confirm Adjustment'),
          ),
        ],
      ),
    ),
  );
}

// ── Stock Movement Ledger Dialog ──────────────────────────────────────────────
void _showStockLedgerDialog(BuildContext context, WidgetRef ref, {int? productId, String? productName}) {
  if (productId != null) {
    ref.read(stockLedgerFilterProvider.notifier).update((s) => s.copyWith(productId: productId));
  } else {
    ref.read(stockLedgerFilterProvider.notifier).update((s) => s.copyWith(clearProduct: true));
  }

  showDialog(
    context: context,
    builder: (ctx) => Consumer(
      builder: (context, ref, _) {
        final ledgerAsync = ref.watch(stockLedgerProvider);
        final filter = ref.watch(stockLedgerFilterProvider);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            width: 900,
            height: 650,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName != null ? 'Stock Ledger: $productName' : 'Master Stock Movement Ledger',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          const Text('Immutable double-entry log of all inventory transactions', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All Transactions',
                        isSelected: filter.transactionType == null,
                        onTap: () => ref.read(stockLedgerFilterProvider.notifier).update((s) => s.copyWith(clearType: true)),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Purchases (IN)',
                        isSelected: filter.transactionType == AppConstants.transactionTypePurchase,
                        onTap: () => ref.read(stockLedgerFilterProvider.notifier).update((s) => s.copyWith(transactionType: AppConstants.transactionTypePurchase)),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Sales (OUT)',
                        isSelected: filter.transactionType == AppConstants.transactionTypeSale,
                        onTap: () => ref.read(stockLedgerFilterProvider.notifier).update((s) => s.copyWith(transactionType: AppConstants.transactionTypeSale)),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Adjustments / Spoilage',
                        isSelected: filter.transactionType == AppConstants.transactionTypeStockAdjustment,
                        onTap: () => ref.read(stockLedgerFilterProvider.notifier).update((s) => s.copyWith(transactionType: AppConstants.transactionTypeStockAdjustment)),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Opening Stock',
                        isSelected: filter.transactionType == AppConstants.transactionTypeOpeningStock,
                        onTap: () => ref.read(stockLedgerFilterProvider.notifier).update((s) => s.copyWith(transactionType: AppConstants.transactionTypeOpeningStock)),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Table
                Expanded(
                  child: ledgerAsync.when(
                    data: (entries) {
                      if (entries.isEmpty) {
                        return const Center(child: Text('No stock movement records found matching criteria.', style: TextStyle(color: AppColors.textMuted)));
                      }
                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(isDark ? Colors.white.withValues(alpha: 0.04) : AppColors.lightBg),
                                headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                                columns: const [
                                  DataColumn(label: Text('Date & Time')),
                                  DataColumn(label: Text('Type')),
                                  DataColumn(label: Text('Reference #')),
                                  DataColumn(label: Text('Product')),
                                  DataColumn(label: Text('Change (Qty)'), numeric: true),
                                  DataColumn(label: Text('Opening')),
                                  DataColumn(label: Text('Closing')),
                                  DataColumn(label: Text('Cost Rate')),
                                  DataColumn(label: Text('Remarks / Audit')),
                                ],
                                rows: entries.map((e) {
                                  final type = e['transaction_type'] as String? ?? '';
                                  final qty = (e['quantity'] as num?)?.toDouble() ?? 0.0;
                                  final isPositive = qty > 0;
                                  final color = type.contains('PURCHASE') || type.contains('OPENING')
                                      ? Colors.green
                                      : (type.contains('SALE') ? Colors.blue : Colors.orange);

                                  return DataRow(
                                    cells: [
                                      DataCell(Text((e['created_date'] as String? ?? '').substring(0, 16))),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                                          child: Text(type, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
                                        ),
                                      ),
                                      DataCell(Text(e['reference_number'] as String? ?? '—', style: const TextStyle(fontWeight: FontWeight.w700))),
                                      DataCell(Text(e['product_name'] as String? ?? 'Product')),
                                      DataCell(
                                        Text(
                                          '${isPositive ? '+' : ''}$qty ${e['product_unit'] ?? ''}',
                                          style: TextStyle(fontWeight: FontWeight.w900, color: isPositive ? Colors.green : Colors.red),
                                        ),
                                      ),
                                      DataCell(Text('${e['opening_stock'] ?? 0}')),
                                      DataCell(Text('${e['closing_stock'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700))),
                                      DataCell(Text(CurrencyFormatter.format((e['unit_cost'] as num?)?.toDouble() ?? 0))),
                                      DataCell(Text(e['remarks'] as String? ?? '—', style: const TextStyle(fontSize: 11, color: AppColors.textMuted))),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textLight),
          ),
        ),
      ),
    );
  }
}
