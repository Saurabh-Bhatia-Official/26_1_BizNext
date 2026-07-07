// lib/features/inventory/screens/inventory_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      child: isMobile 
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Catalog',
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
                        hintText: 'Search...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        filled: true,
                        fillColor: widget.isDark ? AppColors.darkCard : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  LayoutToggle(
                    current: widget.layoutMode,
                    onChanged: widget.onLayoutChanged,
                    isDark: widget.isDark,
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.category_rounded, color: AppColors.primary, size: 20),
                    onPressed: () => _showCategoryManager(context),
                    style: IconButton.styleFrom(
                      backgroundColor: widget.isDark ? AppColors.darkCard : Colors.white,
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
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
                      'Product Catalog',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                        color: widget.isDark ? Colors.white : AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.inventory_2_rounded, size: 14, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Manage items, track stock movement & pricing',
                          style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => widget.ref.read(inventoryFilterProvider.notifier).update((s) => s.copyWith(searchQuery: v)),
                  decoration: InputDecoration(
                    hintText: 'Search items...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: widget.isDark ? AppColors.darkCard : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              LayoutToggle(
                current: widget.layoutMode,
                onChanged: widget.onLayoutChanged,
                isDark: widget.isDark,
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
            label: 'Total Valuation',
            value: CurrencyFormatter.format((stats['inventory_value'] as num?)?.toDouble() ?? 0),
            icon: Icons.account_balance_wallet_rounded,
            colors: [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
            isDark: isDark,
          ),
          const SizedBox(width: 16),
          _StatCard(
            label: 'Low Stock',
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
              Text(
                value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
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
            label: 'Low Stock',
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

class _ProductGrid extends StatelessWidget {
  final List<Product> products;
  final bool isDark;
  const _ProductGrid({required this.products, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossCount = width > 1400 ? 5 : (width > 1100 ? 4 : (width > 800 ? 3 : (width > 500 ? 2 : 1)));
    final aspectRatio = width < 500 ? 0.85 : (width < 900 ? 0.95 : 1.1);

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
        title: const Text('Delete Product?'),
        content: const Text('This will remove this item from your inventory. You can restore it right after.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final productId = widget.product.id!;
              final productName = widget.product.name;
              await ref.read(productFormProvider.notifier).deleteProduct(productId);
              ref.read(notificationProvider.notifier).showWithUndo(
                message: '"$productName" deleted',
                onUndo: () async {
                  await ref.read(productRepositoryProvider).restoreProduct(productId);
                  ref.invalidate(productsProvider);
                  ref.invalidate(inventoryStatsProvider);
                  AppAlert.success(ref, '"$productName" has been restored');
                },
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showStockAdjustment(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Adjust Stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Update quantity for ${widget.product.name}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Adjustment (+/-)',
                hintText: 'e.g. 10 or -5',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(controller.text) ?? 0;
              if (val == 0) return;
              Navigator.pop(ctx);
              await ref.read(productRepositoryProvider).adjustStock(widget.product.id!, val);
              ref.invalidate(productsProvider);
              ref.invalidate(inventoryStatsProvider);
              AppAlert.success(ref, 'Stock adjusted');
            },
            child: const Text('Adjust'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.product.isOutOfStock ? const Color(0xFFEF4444) : (widget.product.isLowStock ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

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
                        } else if (val == 'duplicate') {
                          final success = await ref.read(productFormProvider.notifier).duplicateProduct(widget.product);
                          if (success) AppAlert.success(ref, 'Product duplicated');
                        } else if (val == 'delete') {
                          _confirmDelete(context, ref);
                        } else if (val == 'adjust') {
                           _showStockAdjustment(context, ref);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 12), Text('Edit')])),
                        const PopupMenuItem(value: 'adjust', child: Row(children: [Icon(Icons.inventory_rounded, size: 18), SizedBox(width: 12), Text('Adjust Stock')])),
                        const PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy_rounded, size: 18), SizedBox(width: 12), Text('Duplicate')])),
                        const PopupMenuDivider(),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error), SizedBox(width: 12), Text('Delete', style: TextStyle(color: AppColors.error))])),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.product.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.6, height: 1.1),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.product.sku ?? 'NO SKU',
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
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: -0.8),
                          ),
                        ),
                        const Text('PER UNIT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1), 
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.1)),
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
          Icon(Icons.inventory_2_rounded, size: 100, color: AppColors.primary.withValues(alpha: 0.1)),
          const SizedBox(height: 24),
          const Text('Inventory is empty', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const Text('Start by adding your first business product.', style: TextStyle(color: AppColors.textMuted, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddEditProductScreen())),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add New Product'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          ),
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
        case 3: cmp = a.sellingPrice.compareTo(b.sellingPrice); break;
        case 4: cmp = a.stock.compareTo(b.stock); break;
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
          columnSpacing: 24,
          columns: [
            DataColumn(label: const Text('Product'), onSort: _onSort),
            DataColumn(label: const Text('SKU'), onSort: _onSort),
            DataColumn(label: const Text('Category'), onSort: _onSort),
            DataColumn(label: const Text('Price'), numeric: true, onSort: _onSort),
            DataColumn(label: const Text('Stock'), numeric: true, onSort: _onSort),
            const DataColumn(label: Text('Status')),
            const DataColumn(label: Text('Actions')),
          ],
          rows: _sorted.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final statusColor = p.isOutOfStock
                ? const Color(0xFFEF4444)
                : (p.isLowStock ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
            final statusLabel = p.isOutOfStock ? 'Out' : (p.isLowStock ? 'Low' : 'OK');

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
                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddEditProductScreen(product: p))),
                ),
                DataCell(Text(p.sku ?? '—', style: const TextStyle(color: AppColors.textMuted))),
                DataCell(Text(p.categoryName ?? '—', style: const TextStyle(color: AppColors.textMuted))),
                DataCell(Text(CurrencyFormatter.format(p.sellingPrice))),
                DataCell(Text('${CurrencyFormatter.formatQty(p.stock)} ${p.unit}', style: TextStyle(color: statusColor, fontWeight: FontWeight.w700))),
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
          icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
          tooltip: 'Edit',
          visualDensity: VisualDensity.compact,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddEditProductScreen(product: product))),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, size: 16, color: AppColors.textMuted),
          tooltip: 'More',
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (val) async {
            if (val == 'duplicate') {
              final success = await ref.read(productFormProvider.notifier).duplicateProduct(product);
              if (success) AppAlert.success(ref, 'Product duplicated');
            } else if (val == 'delete') {
              _confirmDelete(context, ref);
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy_rounded, size: 16), SizedBox(width: 10), Text('Duplicate')])),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error), SizedBox(width: 10), Text('Delete', style: TextStyle(color: AppColors.error))])),
          ],
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Product?'),
        content: Text('Remove "${product.name}" from inventory? You can undo this right after.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final productId = product.id!;
              final productName = product.name;
              await ref.read(productFormProvider.notifier).deleteProduct(productId);
              ref.read(notificationProvider.notifier).showWithUndo(
                message: '"$productName" deleted',
                onUndo: () async {
                  await ref.read(productRepositoryProvider).restoreProduct(productId);
                  ref.invalidate(productsProvider);
                  ref.invalidate(inventoryStatsProvider);
                  AppAlert.success(ref, '"$productName" has been restored');
                },
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
