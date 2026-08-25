// lib/features/billing/screens/pos_billing_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../providers/sales_stats_provider.dart';
import '../utils/invoice_service.dart';
import '../../../core/widgets/searchable_dropdown.dart';
import '../../../core/widgets/qr_scanner_screen.dart';
import '../../../core/services/shortcut_service.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';

// Local POS specific state
final _posSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final _isCameraVisibleProvider = StateProvider.autoDispose<bool>((ref) => false);
final _posCategoryProvider = StateProvider.autoDispose<int?>((ref) => null);
final _posPriceListProvider = StateProvider.autoDispose<String>((ref) => 'Standard');

class PosBillingScreen extends ConsumerWidget {
  const PosBillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 700;

    if (isMobile) {
      return AppShortcut(
        actionId: 'pos_clear',
        onPressed: () => ref.invalidate(billingProvider),
        child: PopScope(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) ref.invalidate(billingProvider);
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
            ),
            body: _ProductPicker(isDark: isDark),
            bottomSheet: _MobileCartSheet(isDark: isDark),
          ),
        ),
      );
    }

    return AppShortcut(
      actionId: 'pos_clear',
      onPressed: () => ref.invalidate(billingProvider),
      child: PopScope(
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) ref.invalidate(billingProvider);
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Row(
            children: [
              // ── Left: Product Catalog ──
              Expanded(
                flex: 10,
                child: _ProductPicker(isDark: isDark),
              ),
              
              // ── Right: Checkout Panel ──
              Expanded(
                flex: 4,
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

    return AppShortcut(
      actionId: 'pos_search',
      onPressed: () => _searchFocusNode.requestFocus(),
      child: Column(
        children: [
        // ── Catalog Header & Search ──
        Padding(
          padding: EdgeInsets.fromLTRB(MediaQuery.of(context).size.width < 700 ? 16 : 32, MediaQuery.of(context).size.width < 700 ? 20 : 40, MediaQuery.of(context).size.width < 700 ? 16 : 32, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Search & Add', 
                          style: GoogleFonts.outfit(
                            fontSize: 34, 
                            fontWeight: FontWeight.w900, 
                            letterSpacing: -1.5,
                            color: widget.isDark ? Colors.white : AppColors.textLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.flash_on_rounded, size: 14, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Type or scan to build the current transaction', 
                              style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _PriceListSelector(isDark: widget.isDark),
                  const SizedBox(width: 16),
                  _BarcodeScannerButton(
                    onScan: (code) {
                      _searchController.text = code;
                      ref.read(_posSearchProvider.notifier).state = code;
                      _instantAddBarcode(code);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 28),
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
                  const SizedBox(width: 16),
                  ref.watch(_isCameraVisibleProvider)
                      ? _EmbeddedScanner(
                          onScan: (code) {
                            _searchController.text = code;
                            ref.read(_posSearchProvider.notifier).state = code;
                            _instantAddBarcode(code);
                          },
                          isDark: widget.isDark,
                          onClose: () => ref.read(_isCameraVisibleProvider.notifier).state = false,
                          initialCameraIndex: ref.watch(featureSettingsProvider).selectedCameraIndex,
                        )
                      : const SizedBox.shrink(),
                ],
              ),
            ],
          ),
        ),

        // ── Category Selector ──
        categoriesAsync.when(
          data: (cats) => Container(
            height: 48,
            margin: const EdgeInsets.only(bottom: 16),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              scrollDirection: Axis.horizontal,
              itemCount: cats.length + 1,
              itemBuilder: (ctx, i) {
                final isAll = i == 0;
                final cat = isAll ? null : cats[i - 1];
                final isSelected = selectedCatId == cat?.id;

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _CategoryChip(
                    label: isAll ? 'All Products' : cat!.name,
                    isSelected: isSelected,
                    onTap: () => ref.read(_posCategoryProvider.notifier).state = cat?.id,
                    isDark: widget.isDark,
                  ),
                );
              },
            ),
          ),
          loading: () => const SizedBox(height: 48),
          error: (_, _) => const SizedBox.shrink(),
        ),

        // ── Product Grid ──
        Expanded(
          child: productsAsync.when(
            data: (products) {
              final filtered = products.where((p) {
                final matchSearch = searchQuery.isEmpty || 
                                   p.name.toLowerCase().contains(searchQuery) ||
                                   (p.barcode?.toLowerCase().contains(searchQuery) ?? false) ||
                                   (p.sku?.toLowerCase().contains(searchQuery) ?? false);
                final matchCat = selectedCatId == null || p.categoryId == selectedCatId;
                return matchSearch && matchCat;
              }).toList();

              if (searchQuery.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_rounded, size: 64, color: AppColors.textMuted.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('Search or scan to add products', style: TextStyle(color: AppColors.textMuted, fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }

              if (filtered.isEmpty) return _NoResults(query: searchQuery);

              return ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  MediaQuery.of(context).size.width < 450 ? 16 : 32, 
                  8, 
                  MediaQuery.of(context).size.width < 450 ? 16 : 32, 
                  100
                ),
                itemCount: filtered.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1, color: AppColors.lightBorder),
                itemBuilder: (ctx, i) {
                  final p = filtered[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Stock: ${p.stock} ${p.unit}   •   SKU: ${p.sku ?? "-"}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(CurrencyFormatter.format(p.sellingPrice), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 16)),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.add, color: AppColors.primary, size: 20),
                        ),
                      ],
                    ),
                    onTap: () {
                      final error = ref.read(billingProvider.notifier).addProduct(p);
                      if (error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.error));
                      } else {
                        ref.read(_posSearchProvider.notifier).state = '';
                        _searchController.clear();
                      }
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    ),);
  }

  void _instantAddBarcode(String code) {
    final products = ref.read(productsProvider).value ?? [];
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;

    final match = products.firstWhere(
      (p) => (p.barcode?.toLowerCase() == trimmed.toLowerCase() || p.sku?.toLowerCase() == trimmed.toLowerCase()),
      orElse: () => Product(name: '', sellingPrice: 0, stock: 0, unit: '', categoryId: 0),
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
            content: Text('Added ${match.name} to cart!'),
            duration: const Duration(milliseconds: 800),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }
}

class _PriceListSelector extends ConsumerWidget {
  final bool isDark;
  const _PriceListSelector({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_posPriceListProvider);
    final lists = ['Standard', 'Wholesale', 'VIP Customer', 'Employee'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
          isDense: true,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textLight),
          onChanged: (v) {
            if (v != null) ref.read(_posPriceListProvider.notifier).state = v;
          },
          items: lists.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _CategoryChip({required this.label, required this.isSelected, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder), 
            width: 1.5
          ),
          boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textLight),
          ),
        ),
      ),
    );
  }
}

class _ProfessionalSearchBar extends ConsumerWidget {
  final Function(String) onChanged;
  final bool isDark;
  final TextEditingController controller;
  final FocusNode? focusNode;
  const _ProfessionalSearchBar({required this.onChanged, required this.isDark, required this.controller, this.focusNode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider).value ?? [];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: (v) {
          final trimmed = v.trim();
          if (trimmed.isEmpty) return;
          final match = products.firstWhere(
            (p) => (p.barcode?.toLowerCase() == trimmed.toLowerCase() || p.sku?.toLowerCase() == trimmed.toLowerCase()),
            orElse: () => Product(name: '', sellingPrice: 0, stock: 0, unit: '', categoryId: 0),
          );
          if (match.name.isNotEmpty) {
            final error = ref.read(billingProvider.notifier).addProduct(match);
            if (error != null) {
              AppAlert.warning(ref, error);
            } else {
              controller.clear();
              onChanged('');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added ${match.name} to cart!'),
                  duration: const Duration(milliseconds: 800),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          }
        },
        style: const TextStyle(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Search catalog or scan barcode...',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w500),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 24),
          filled: true,
          fillColor: Colors.transparent, // Handled by container
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        ),
      ),
    );
  }
}

class _BarcodeScannerButton extends ConsumerWidget {
  final Function(String) onScan;
  const _BarcodeScannerButton({required this.onScan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 6)),
        ],
      ),
      child: IconButton(
        onPressed: () async {
          final setting = ref.read(featureSettingsProvider).scannerDevice;
          if (setting == 'embedded') {
            ref.read(_isCameraVisibleProvider.notifier).state = true;
          } else if (setting == 'external') {
            _showExternalScannerDialog(context);
          } else {
            // Default to full screen camera
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
        icon: const Icon(Icons.qr_code_scanner_rounded, size: 24, color: Colors.white),
        padding: const EdgeInsets.all(18),
      ),
    );
  }

  void _showExternalScannerDialog(BuildContext context) {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    showDialog(
      context: context,
      builder: (ctx) {
        // Auto focus the text field
        WidgetsBinding.instance.addPostFrameCallback((_) {
          focusNode.requestFocus();
        });

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('External Scanner Mode', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please scan the barcode using your external device.'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  hintText: 'Waiting for scan...',
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
                onSubmitted: (v) {
                  onScan(v);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ],
        );
      },
    );
  }
}

class _SourceTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SourceTile({required this.title, required this.subtitle, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ProductTile extends ConsumerWidget {
  final Product product;
  final bool isDark;
  const _ProductTile({required this.product, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOut = product.stock <= 0;
    final statusColor = isOut ? AppColors.error : (product.isLowStock ? AppColors.warning : AppColors.primary);
    final tiers = ref.watch(tieredPricesForProductProvider(product.id!)).value ?? [];
    
    String displayPrice = CurrencyFormatter.format(product.sellingPrice);
    if (tiers.isNotEmpty) {
      double minPrice = product.sellingPrice;
      double maxPrice = product.sellingPrice;
      for (var t in tiers) {
        if (t.price < minPrice) minPrice = t.price;
        if (t.price > maxPrice) maxPrice = t.price;
      }
      if (minPrice != maxPrice) {
        displayPrice = '${CurrencyFormatter.format(minPrice)} - ${CurrencyFormatter.format(maxPrice)}';
      }
    }

    return InkWell(
      onTap: isOut ? null : () => _onProductTap(context, ref),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.inventory_2_rounded, color: statusColor, size: 24),
                ),
                const Spacer(),
                if (!isOut) _AddIcon(color: statusColor),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, height: 1.2, letterSpacing: -0.5),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              product.sku ?? product.barcode ?? 'NO SKU',
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w800, letterSpacing: 0.5),
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
                          displayPrice,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textLight,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      Text(
                        isOut ? 'OUT OF STOCK' : '${product.stock.toInt()} ${product.unit} available',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onProductTap(BuildContext context, WidgetRef ref) async {
    final tiers = await ref.read(productRepositoryProvider).getProductPrices(product.id!);
    if (tiers.isNotEmpty) {
      if (context.mounted) {
        _showPriceTierMenu(context, ref, product, tiers);
      }
    } else {
      final error = ref.read(billingProvider.notifier).addProduct(product);
      if (error != null) AppAlert.warning(ref, error);
    }
  }

  void _showPriceTierMenu(BuildContext context, WidgetRef ref, Product product, List<ProductTierPrice> tiers) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final selectedPrice = await showMenu<double>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      items: [
        PopupMenuItem(
          value: product.sellingPrice,
          child: Row(
            children: [
              const Icon(Icons.shopping_cart_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 12),
              Text('Retail: ${CurrencyFormatter.format(product.sellingPrice)}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        ...tiers.map((t) => PopupMenuItem(
          value: t.price,
          child: Row(
            children: [
              const Icon(Icons.layers_rounded, size: 18, color: AppColors.success),
              const SizedBox(width: 12),
              Text('${t.categoryName}: ${CurrencyFormatter.format(t.price)}'),
            ],
          ),
        )),
      ],
    );

    if (selectedPrice != null) {
      final tierName = selectedPrice == product.sellingPrice ? 'Retail' : tiers.firstWhere((t) => t.price == selectedPrice).categoryName;
      ref.read(billingProvider.notifier).addProduct(product, overridePrice: selectedPrice, priceScaleName: tierName);
    }
  }
}

class _AddIcon extends StatelessWidget {
  final Color color;
  const _AddIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Icon(Icons.add_rounded, color: color, size: 20),
    );
  }
}

// ── Cart Panel (Checkout) ────────────────────────────────────────────────────
class _CartPanel extends ConsumerWidget {
  final bool isDark;
  const _CartPanel({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billing = ref.watch(billingProvider);
    final customersAsync = ref.watch(customersProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxHeight < 800;

        Widget cartList = billing.items.isEmpty
            ? _EmptyCart()
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: billing.items.length,
                itemBuilder: (ctx, i) => _CartItemRow(item: billing.items[i], index: i),
              );

        Widget body = Column(
          children: [
            // ── Cart Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bill Summary', 
                    style: GoogleFonts.outfit(
                      fontSize: 22, 
                      fontWeight: FontWeight.w900, 
                      letterSpacing: -1.0,
                      color: isDark ? Colors.white : AppColors.textLight,
                    )
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text('${billing.totalItemCount} ITEMS', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: AppColors.primary, letterSpacing: 0.5)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Customer Selection
              customersAsync.when(
                data: (customers) => AppSearchableDropdown<int?>(
                  value: billing.selectedCustomerId,
                  labelText: 'Select Customer',
                  prefixIcon: Icons.person_rounded,
                  isDark: isDark,
                  addLabel: 'NEW',
                  onAdd: (name) => _quickAddCustomer(context, ref, name),
                  items: [
                    SearchableDropdownItem(value: null, label: 'Walk-in Customer (General)'),
                    ...customers.map((c) => SearchableDropdownItem(value: c.id, label: c.name)),
                  ],
                  onChanged: (v) {
                    if (v == null) {
                      ref.read(billingProvider.notifier).clearCustomer();
                    } else {
                      final c = customers.firstWhere((c) => c.id == v);
                      ref.read(billingProvider.notifier).selectCustomer(v, c.name);
                    }
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              // Payment Mode
              Row(
                children: AppConstants.paymentModes.map((mode) {
                  final isSelected = billing.paymentMode == mode;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => ref.read(billingProvider.notifier).setPaymentMode(mode),
                      child: AnimatedContainer(
                        duration: 200.ms,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : (isDark ? Colors.white.withValues(alpha: 0.03) : AppColors.lightBg),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                        ),
                        child: Center(
                          child: Text(
                            mode.toUpperCase(),
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isSelected ? Colors.white : AppColors.textMuted, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── Bill Items ──
        if (isSmallScreen)
          SizedBox(height: 200, child: cartList)
        else
          Expanded(child: cartList),

        // ── Offers UI ──
        _OffersSection(isDark: isDark),

        // ── Summary & Checkout ──
        _CheckoutSection(billing: billing, isDark: isDark),
      ],
    );

        if (isSmallScreen) {
          return SingleChildScrollView(child: body);
        }

        return body;
      },
    );
  }
}

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
      final val = offer.discountType == 'percentage' ? '${offer.discountValue}%' : CurrencyFormatter.format(offer.discountValue);
      return 'Get $val off on ${CurrencyFormatter.format(offer.minAmount)}';
    } else {
      final val = offer.discountType == 'percentage' ? '${offer.discountValue}%' : CurrencyFormatter.format(offer.discountValue);
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkCard : AppColors.lightBg,
        border: Border(top: BorderSide(color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Row(
              children: [
                const Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Text('Available Offers (${validOffers.length})', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: widget.isDark ? Colors.white : AppColors.textLight)),
                const Spacer(),
                Icon(_isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 16),
              ],
            ),
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 54,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: validOffers.length,
                itemBuilder: (ctx, i) {
                  final offer = validOffers[i];
                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(offer.name, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 13)),
                        Text(_getOfferDescription(offer), style: TextStyle(fontSize: 10, color: AppColors.primary.withValues(alpha: 0.8))),
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

class _CartItemRow extends ConsumerWidget {
  final PosItemModel item;
  final int index;
  const _CartItemRow({required this.item, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, height: 1.1),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    if (item.priceScaleName != null)
                      Text(item.priceScaleName!.toUpperCase(), style: const TextStyle(fontSize: 8, color: AppColors.primary, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Text(
                      '${CurrencyFormatter.format(item.effectivePrice)} × ${item.quantity.toInt()} ${item.product.unit}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              // Subtotal
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(item.total),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primary),
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
          const SizedBox(height: 16),
          // Controls
          Wrap(
            spacing: 8,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _QtyControl(
                qty: item.quantity,
                onChanged: (v) => ref.read(billingProvider.notifier).updateQuantity(index, v),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PriceInput(
                    value: item.effectivePrice,
                    onChanged: (v) => ref.read(billingProvider.notifier).updatePrice(index, v),
                  ),
                  const SizedBox(width: 8),
                  _TierSelector(item: item, index: index),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () => ref.read(billingProvider.notifier).removeItem(index),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.error.withValues(alpha: 0.08),
                      foregroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CircleBtn(icon: Icons.remove_rounded, onTap: () => widget.onChanged(widget.qty - 1)),
          SizedBox(
            width: 44,
            child: TextField(
              controller: _ctrl,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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
          _CircleBtn(icon: Icons.add_rounded, onTap: () => widget.onChanged(widget.qty + 1)),
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
      width: 110,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_rounded, size: 12, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.success),
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

class _TierSelector extends ConsumerWidget {
  final PosItemModel item;
  final int index;
  const _TierSelector({required this.item, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<ProductTierPrice>>(
      future: ref.read(productRepositoryProvider).getProductPrices(item.product.id!),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        final tiers = snapshot.data!;

        return PopupMenuButton<double>(
          icon: const Icon(Icons.layers_rounded, size: 16, color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tooltip: 'Select Price Tier',
          onSelected: (price) {
            final tierName = price == item.product.sellingPrice ? 'Retail' : tiers.firstWhere((t) => t.price == price).categoryName;
            ref.read(billingProvider.notifier).updatePrice(index, price, scaleName: tierName);
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: item.product.sellingPrice,
              child: Row(
                children: [
                  const Icon(Icons.shopping_cart_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Retail: ${CurrencyFormatter.format(item.product.sellingPrice)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ],
              ),
            ),
            ...tiers.map((t) => PopupMenuItem(
              value: t.price,
              child: Row(
                children: [
                  const Icon(Icons.layers_rounded, size: 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  Text('${t.categoryName}: ${CurrencyFormatter.format(t.price)}', style: const TextStyle(fontSize: 13)),
                ],
              ),
            )),
          ],
        );
      },
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      color: AppColors.primary,
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(),
    );
  }
}

class _CheckoutSection extends ConsumerStatefulWidget {
  final BillingState billing;
  final bool isDark;
  const _CheckoutSection({required this.billing, required this.isDark});

  @override
  ConsumerState<_CheckoutSection> createState() => _CheckoutSectionState();
}

class _CheckoutSectionState extends ConsumerState<_CheckoutSection> {
  @override
  Widget build(BuildContext context) {
    final shortcuts = ref.watch(shortcutSettingsProvider);
    final posPayShortcut = shortcuts['pos_pay'] ?? ShortcutNotifier.defaults['pos_pay']?.defaultShortcut ?? '';
    final finalizeBtnText = posPayShortcut.isNotEmpty ? 'FINALIZE TRANSACTION ($posPayShortcut)' : 'FINALIZE TRANSACTION';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkSidebar : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
        border: Border(top: BorderSide(color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.black.withValues(alpha: 0.2) : AppColors.lightBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _BillRow(label: 'Net Subtotal', value: widget.billing.subtotal),
                if (ref.watch(featureSettingsProvider).gstEnabled) ...[
                  const SizedBox(height: 8),
                  _BillRow(label: 'Total GST', value: widget.billing.totalGst),
                ],
                if (widget.billing.totalDiscounts > 0) ...[
                  const SizedBox(height: 8),
                  _BillRow(label: 'Bill Discounts', value: -widget.billing.totalDiscounts, color: AppColors.success),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'GRAND TOTAL',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: widget.isDark ? Colors.white70 : AppColors.textLight),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          CurrencyFormatter.format(widget.billing.grandTotal),
                          style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: -1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          SizedBox(
            width: double.infinity,
            height: 56,
            child: AppShortcut(
              actionId: 'pos_pay',
              onPressed: widget.billing.items.isEmpty || widget.billing.isProcessing
                  ? null
                  : () => _handleCompleteSale(context, ref, widget.billing),
              child: ElevatedButton(
                onPressed: widget.billing.items.isEmpty || widget.billing.isProcessing
                    ? null
                    : () => _handleCompleteSale(context, ref, widget.billing),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  elevation: 12,
                  shadowColor: AppColors.primary.withValues(alpha: 0.5),
                ),
                child: widget.billing.isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 24),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(finalizeBtnText, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0)),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: widget.billing.items.isEmpty || widget.billing.isProcessing
                  ? null
                  : () => _handleOneClickCashCheckout(context, ref, widget.billing),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 4,
              ),
              child: widget.billing.isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.flash_on_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text('QUICK CASH OUT', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleOneClickCashCheckout(BuildContext context, WidgetRef ref, BillingState billing) async {
    ref.read(billingProvider.notifier).setPaymentMode('cash');
    final isEditing = billing.editingSaleId != null;
    final saleId = await ref.read(billingProvider.notifier).completeSale();
    if (saleId != null) {
      _printReceipt(context, ref, saleId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cash checkout finalized. Receipt generated.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
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
            _SummaryRow('Item Count', billing.totalItemCount.toString()),
            _SummaryRow('Final Amount', CurrencyFormatter.format(billing.grandTotal), isBold: true),
            _SummaryRow('Payment Method', billing.paymentMode),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Complete Sale')),
        ],
      ),
    );

    if (confirm == true) {
      final isEditing = billing.editingSaleId != null;
      final saleId = await ref.read(billingProvider.notifier).completeSale();
      if (saleId != null) {
        _onSaleSuccess(context, ref, saleId, isEditing);
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
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Success!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            SizedBox(height: 12),
            Text('The transaction has been recorded and inventory updated.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.print_rounded),
            label: const Text('Print Receipt'),
          ),
        ],
      ),
    );

    if (printNow == true) {
      _printReceipt(context, ref, saleId);
    }

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

class _BillRow extends StatelessWidget {
  final String label;
  final double value;
  final Color? color;
  const _BillRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMuted, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                CurrencyFormatter.format(value),
                style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
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
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.w800, fontSize: isBold ? 20 : 14, color: isBold ? AppColors.primary : null)),
        ],
      ),
    );
  }
}

// ── Shared Helper Widgets ──
class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: AppColors.textMuted.withValues(alpha: 0.1)),
          const SizedBox(height: 20),
          Text(query.isEmpty ? 'Catalog is empty' : 'No matches found', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          if (query.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('We couldn\'t find any items matching "$query"', style: const TextStyle(color: AppColors.textMuted)),
          ),
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
            Icon(Icons.shopping_basket_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.1)),
            const SizedBox(height: 20),
            const Text('Bill is currently empty', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textMuted, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Tap items on the left to add them', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
  
  final result = await showDialog<CustomerModel?>(
    context: context,
    builder: (ctx) => AlertDialog(
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
              balance: double.tryParse(balanceController.text) ?? 0.0,
              businessId: bizId,
            );
            Navigator.pop(ctx, newCustomer);
          },
          child: const Text('Save & Select'),
        ),
      ],
    ),
  );

  if (result != null) {
    final success = await ref.read(customerFormProvider.notifier).saveCustomer(result);
    if (success) {
      final customers = await ref.read(customersProvider.future);
      final added = customers.firstWhere((c) => c.name == result.name && (result.phone == null || c.phone == result.phone));
      ref.read(billingProvider.notifier).selectCustomer(added.id!, added.name);
      AppAlert.success(ref, 'Customer added successfully');
    } else {
      AppAlert.error(ref, 'Failed to add customer');
    }
  }
}

// Minimal mobile cart sheet
class _MobileCartSheet extends ConsumerWidget {
  final bool isDark;
  const _MobileCartSheet({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billing = ref.watch(billingProvider);
    if (billing.items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                Text(CurrencyFormatter.format(billing.grandTotal), style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: -1)),
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
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
        await _controller?.dispose();
        try {
          _controller = CameraController(
            _cameras![_selectedCameraIndex],
            ResolutionPreset.medium,
          );
          await _controller!.initialize();
        } catch (e) {
          if (kDebugMode) debugPrint('Failed with Medium, trying Low: $e');
          _controller = CameraController(
            _cameras![_selectedCameraIndex],
            ResolutionPreset.low,
          );
          await _controller!.initialize();
        }
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Camera init error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Container(
        height: 120,
        width: 160,
        decoration: BoxDecoration(
          color: widget.isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: const Center(
          child: Icon(Icons.videocam_off_rounded, color: AppColors.textMuted),
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
