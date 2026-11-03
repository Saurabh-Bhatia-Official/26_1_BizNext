// lib/features/inventory/screens/add_edit_product_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../models/product_model.dart';
import '../providers/inventory_provider.dart';
import '../../suppliers/providers/supplier_provider.dart';
import '../../../core/widgets/searchable_dropdown.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../core/services/media_upload_service.dart';
import '../../../core/services/shortcut_service.dart';
import '../../../core/widgets/qr_scanner_screen.dart';
import '../../../core/services/hardware_scanner_service.dart';

class AddEditProductScreen extends ConsumerStatefulWidget {
  final Product? product;
  final String? initialName;
  const AddEditProductScreen({super.key, this.product, this.initialName});

  @override
  ConsumerState<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends ConsumerState<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _skuCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _hsnSacCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _purchasePriceCtrl;
  late final TextEditingController _mrpCtrl;
  late final TextEditingController _sellingPriceCtrl;
  late final TextEditingController _wholesalePriceCtrl;
  late final TextEditingController _dealerPriceCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _minStockCtrl;

  // Dynamic controllers for tiered prices
  final Map<int, TextEditingController> _tieredPriceCtrls = {};

  int? _selectedCategoryId;
  int? _selectedSubcategoryId;
  int? _selectedSupplierId;
  String _selectedUnit = 'pcs';
  double _selectedGst = 0;
  bool _isActive = true;
  String? _selectedImagePath;

  String? _nameError;

  bool get isEditing => widget.product != null;
  static const _units = ['pcs', 'kg', 'g', 'l', 'ml', 'box', 'pack', 'm', 'bundle', 'pair'];

  String _formatNum(double? val) {
    if (val == null || val <= 0) return '';
    if (val == val.truncateToDouble()) {
      return val.toInt().toString();
    }
    return val.toString();
  }

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? widget.initialName ?? '');
    _skuCtrl = TextEditingController(text: p?.sku ?? '');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _brandCtrl = TextEditingController(text: p?.brand ?? '');
    _hsnSacCtrl = TextEditingController(text: p?.hsnSac ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _purchasePriceCtrl = TextEditingController(text: p != null ? _formatNum(p.purchasePrice) : '');
    _mrpCtrl = TextEditingController(text: p != null ? _formatNum(p.mrp) : '');
    _sellingPriceCtrl = TextEditingController(text: p != null ? _formatNum(p.sellingPrice) : '');
    _wholesalePriceCtrl = TextEditingController(text: p != null ? _formatNum(p.wholesalePrice) : '');
    _dealerPriceCtrl = TextEditingController(text: p != null ? _formatNum(p.dealerPrice) : '');
    _stockCtrl = TextEditingController(text: p != null ? _formatNum(p.stock) : '0');
    _minStockCtrl = TextEditingController(text: p != null ? _formatNum(p.minStock) : '5');

    // Attach listeners for live profit margin calculations
    _purchasePriceCtrl.addListener(_onPriceInputsChanged);
    _sellingPriceCtrl.addListener(_onPriceInputsChanged);

    _selectedCategoryId = p?.categoryId;
    _selectedSubcategoryId = p?.subcategoryId;
    _selectedSupplierId = p?.defaultSupplierId;
    _selectedUnit = p?.unit ?? 'pcs';
    _selectedGst = p?.gstPercent ?? 0;
    _isActive = p?.isActive ?? true;
    _selectedImagePath = p?.imagePath;

    if (isEditing) {
      _loadTieredPrices();
    }
  }

  void _onPriceInputsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadTieredPrices() async {
    final prices = await ref.read(productRepositoryProvider).getProductPrices(widget.product!.id!);
    if (mounted) {
      for (final p in prices) {
        if (_tieredPriceCtrls.containsKey(p.categoryId)) {
          _tieredPriceCtrls[p.categoryId]!.text = _formatNum(p.price);
        } else {
          _tieredPriceCtrls[p.categoryId] = TextEditingController(text: _formatNum(p.price));
        }
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _purchasePriceCtrl.removeListener(_onPriceInputsChanged);
    _sellingPriceCtrl.removeListener(_onPriceInputsChanged);

    for (final c in [
      _nameCtrl, _skuCtrl, _barcodeCtrl, _brandCtrl, _hsnSacCtrl, _descCtrl,
      _purchasePriceCtrl, _mrpCtrl, _sellingPriceCtrl,
      _wholesalePriceCtrl, _dealerPriceCtrl, _stockCtrl, _minStockCtrl
    ]) {
      c.dispose();
    }
    for (final c in _tieredPriceCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _generateSku() {
    final name = _nameCtrl.text.trim();
    final cleanPrefix = name.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
    final prefix = cleanPrefix.length >= 3 ? cleanPrefix.substring(0, 3) : (cleanPrefix.isEmpty ? 'SKU' : cleanPrefix);
    final stamp = (DateTime.now().millisecondsSinceEpoch % 90000 + 10000).toString();
    final generatedCode = '$prefix-$stamp';
    setState(() {
      _skuCtrl.text = generatedCode;
      if (_barcodeCtrl.text.trim().isEmpty) {
        _barcodeCtrl.text = generatedCode;
      }
    });
  }

  void _generateBarcode() {
    final stamp = (DateTime.now().millisecondsSinceEpoch % 900000000000 + 100000000000).toString();
    setState(() {
      _barcodeCtrl.text = stamp;
      if (_skuCtrl.text.trim().isEmpty) {
        final name = _nameCtrl.text.trim();
        final cleanPrefix = name.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
        final prefix = cleanPrefix.length >= 3 ? cleanPrefix.substring(0, 3) : (cleanPrefix.isEmpty ? 'SKU' : cleanPrefix);
        _skuCtrl.text = '$prefix-${stamp.substring(stamp.length - 5)}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoriesAsync = ref.watch(categoriesProvider);
    final subcategoriesAsync = ref.watch(subcategoriesProvider(_selectedCategoryId));
    final suppliersAsync = ref.watch(suppliersProvider);
    final priceCatsAsync = ref.watch(customerTypesProvider);
    final shortcuts = ref.watch(shortcutSettingsProvider);
    final saveShortcut = shortcuts['save'] ?? ShortcutNotifier.defaults['save']?.defaultShortcut ?? '';
    final cancelShortcut = shortcuts['cancel'] ?? ShortcutNotifier.defaults['cancel']?.defaultShortcut ?? '';
    final saveBtnLabel = isEditing ? 'Save Changes' : 'Create Product';
    final saveBtnText = saveShortcut.isNotEmpty ? '$saveBtnLabel ($saveShortcut)' : saveBtnLabel;
    final cancelBtnText = cancelShortcut.isNotEmpty ? 'Cancel ($cancelShortcut)' : 'Cancel';
    return HardwareBarcodeScannerListener(
      onBarcodeScanned: (code) {
        setState(() {
          _barcodeCtrl.text = code;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Barcode "$code" scanned into product form')),
              ],
            ),
            backgroundColor: AppColors.primaryDark,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
      child: AppShortcut(
        actionId: 'cancel',
        onPressed: () => Navigator.maybePop(context),
        child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        appBar: AppBar(
          title: Text(
            isEditing ? 'Edit Product' : 'New Product Master',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          elevation: 0.5,
          centerTitle: true,
          actions: [
            if (isEditing)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                tooltip: 'Delete Product',
                onPressed: _confirmDelete,
              ),
            TextButton.icon(
              onPressed: _saveProduct,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 680;
            final double horizontalPadding = isMobile ? 16.0 : 32.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── PRODUCT IMAGE CARD ──
                        _ImagePicker(
                          imagePath: _selectedImagePath,
                          onPick: _pickImage,
                          onRemove: () => setState(() => _selectedImagePath = null),
                          isDark: isDark,
                          isMobile: isMobile,
                        ),
                        const SizedBox(height: 20),

                        // ── 1. BASIC INFORMATION ──
                        _FormCard(
                          title: 'Product Information',
                          subtitle: 'Core product identifiers, brand, categories and unit',
                          icon: Icons.inventory_2_rounded,
                          isDark: isDark,
                          isMobile: isMobile,
                          children: [
                            _PremiumField(
                              controller: _nameCtrl,
                              label: 'Product Name *',
                              hint: 'e.g. Basmati Rice 5kg, iPhone 15 Pro, Cotton T-Shirt',
                              icon: Icons.title_rounded,
                              externalError: _nameError,
                              onChanged: (_) {
                                if (_nameError != null) setState(() => _nameError = null);
                              },
                              validator: (v) => v?.trim().isEmpty == true ? 'Product name is required' : null,
                            ),
                            const SizedBox(height: 16),

                            _ResponsiveRow(
                              isMobile: isMobile,
                              children: [
                                _PremiumField(
                                  controller: _brandCtrl,
                                  label: 'Brand / Manufacturer',
                                  hint: 'e.g. Tata, Apple, Nestle',
                                  icon: Icons.business_rounded,
                                ),
                                _PremiumField(
                                  controller: _hsnSacCtrl,
                                  label: 'HSN / SAC Code',
                                  hint: 'e.g. 10063020, 85171300',
                                  icon: Icons.numbers_rounded,
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            _ResponsiveRow(
                              isMobile: isMobile,
                              children: [
                                _PremiumField(
                                  controller: _skuCtrl,
                                  label: 'SKU / Item Code',
                                  hint: 'e.g. RICE-001',
                                  icon: Icons.tag_rounded,
                                  suffix: IconButton(
                                    icon: const Icon(Icons.auto_fix_high_rounded, size: 20, color: AppColors.primary),
                                    tooltip: 'Auto-generate SKU',
                                    onPressed: _generateSku,
                                  ),
                                ),
                                _PremiumField(
                                  controller: _barcodeCtrl,
                                  label: 'Barcode / EAN / UPC',
                                  hint: 'Scan or enter barcode number',
                                  icon: Icons.qr_code_scanner_rounded,
                                  keyboardType: TextInputType.text,
                                  suffix: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: AppColors.primary),
                                        tooltip: 'Scan barcode with camera',
                                        onPressed: () async {
                                          final code = await Navigator.push<String>(
                                            context,
                                            MaterialPageRoute(builder: (context) => const QRScannerScreen()),
                                          );
                                          if (code != null && code.isNotEmpty) {
                                            setState(() {
                                              _barcodeCtrl.text = code;
                                            });
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.auto_fix_normal_rounded, size: 20, color: AppColors.primary),
                                        tooltip: 'Auto-generate barcode',
                                        onPressed: _generateBarcode,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            _PremiumField(
                              controller: _descCtrl,
                              label: 'Description & Notes',
                              hint: 'Specifications, dimensions, or internal notes',
                              maxLines: 2,
                              keyboardType: TextInputType.multiline,
                              icon: Icons.description_rounded,
                            ),
                            const SizedBox(height: 16),

                            _ResponsiveRow(
                              isMobile: isMobile,
                              children: [
                                categoriesAsync.when(
                                  data: (cats) => _PremiumDropdown<int?>(
                                    value: _selectedCategoryId,
                                    label: 'Category',
                                    addLabel: 'Add New Category',
                                    onAdd: (name) => _quickAddCategory(context, ref, name),
                                    items: cats.map((c) => SearchableDropdownItem(value: c.id, label: c.name)).toList(),
                                    onChanged: (v) {
                                      setState(() {
                                        _selectedCategoryId = v;
                                        _selectedSubcategoryId = null;
                                      });
                                    },
                                    icon: Icons.category_rounded,
                                  ),
                                  loading: () => const LinearProgressIndicator(),
                                  error: (_, _) => const SizedBox.shrink(),
                                ),
                                subcategoriesAsync.when(
                                  data: (subs) => _PremiumDropdown<int?>(
                                    value: _selectedSubcategoryId,
                                    label: 'Subcategory',
                                    addLabel: _selectedCategoryId != null ? 'Add Subcategory' : null,
                                    onAdd: _selectedCategoryId != null 
                                      ? (name) => _quickAddSubcategory(context, ref, name, _selectedCategoryId!)
                                      : null,
                                    items: subs.map((s) => SearchableDropdownItem(value: s.id, label: s.name)).toList(),
                                    onChanged: (v) => setState(() => _selectedSubcategoryId = v),
                                    icon: Icons.subdirectory_arrow_right_rounded,
                                  ),
                                  loading: () => const LinearProgressIndicator(),
                                  error: (_, _) => const SizedBox.shrink(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            _ResponsiveRow(
                              isMobile: isMobile,
                              children: [
                                _PremiumDropdown<String>(
                                  value: _selectedUnit,
                                  label: 'Base Measurement Unit',
                                  items: _units.map((u) => SearchableDropdownItem(value: u, label: u)).toList(),
                                  onChanged: (v) => setState(() => _selectedUnit = v ?? 'pcs'),
                                  icon: Icons.straighten_rounded,
                                ),
                                suppliersAsync.when(
                                  data: (suppliers) => _PremiumDropdown<int?>(
                                    value: _selectedSupplierId,
                                    label: 'Default Supplier / Vendor',
                                    items: suppliers.map((s) => SearchableDropdownItem(value: s.id, label: s.name)).toList(),
                                    onChanged: (v) => setState(() => _selectedSupplierId = v),
                                    icon: Icons.local_shipping_rounded,
                                  ),
                                  loading: () => const LinearProgressIndicator(),
                                  error: (_, _) => const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ── 2. PRICING & MARGIN MATRIX ──
                        _FormCard(
                          title: 'Pricing & Margins',
                          subtitle: 'Standard retail, cost price, price floors & live margin calculation',
                          icon: Icons.price_change_rounded,
                          isDark: isDark,
                          isMobile: isMobile,
                          children: [
                            // Real-time Profit & Margin HUD
                            _buildLiveMarginHud(isDark),

                            _ResponsiveRow(
                              isMobile: isMobile,
                              children: [
                                _PremiumField(
                                  controller: _purchasePriceCtrl,
                                  label: 'Purchase Cost / Rate (WAC) ₹',
                                  hint: '0.00',
                                  icon: Icons.shopping_bag_rounded,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                                _PremiumField(
                                  controller: _mrpCtrl,
                                  label: 'MRP (Maximum Retail Price) ₹',
                                  hint: '0.00',
                                  icon: Icons.verified_rounded,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            _PremiumField(
                              controller: _sellingPriceCtrl,
                              label: 'Standard Selling Price (Retail) ₹ *',
                              hint: '0.00',
                              icon: Icons.sell_rounded,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Selling price is required';
                                final numVal = double.tryParse(v);
                                if (numVal == null || numVal < 0) return 'Enter a valid positive price';
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Tiered Custom Price Lists
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: _SubLabel(text: 'Customer Price Tiers'),
                            ),
                            const SizedBox(height: 8),

                            priceCatsAsync.when(
                              data: (allCats) {
                                final cats = allCats.where((c) {
                                  final lower = c.name.toLowerCase();
                                  return lower != 'retail' && lower != 'standard';
                                }).toList();

                                if (cats.isEmpty) {
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withValues(alpha: 0.02) : AppColors.lightBg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
                                        SizedBox(width: 8),
                                        Text('No custom price tiers configured. Manage tiers in Settings.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                      ],
                                    ),
                                  );
                                }
                                return Column(
                                  children: [
                                    for (int i = 0; i < cats.length; i += 2)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        child: _ResponsiveRow(
                                          isMobile: isMobile,
                                          children: [
                                            _PremiumField(
                                              controller: _getTierCtrl(cats[i]),
                                              label: '${cats[i].name} Price ₹',
                                              hint: '0.00',
                                              icon: Icons.handshake_rounded,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            ),
                                            if (i + 1 < cats.length)
                                              _PremiumField(
                                                controller: _getTierCtrl(cats[i + 1]),
                                                label: '${cats[i + 1].name} Price ₹',
                                                hint: '0.00',
                                                icon: Icons.handshake_rounded,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              )
                                            else if (!isMobile)
                                              const SizedBox.shrink(),
                                          ],
                                        ),
                                      ),
                                  ],
                                );
                              },
                              loading: () => const LinearProgressIndicator(),
                              error: (_, _) => const SizedBox(),
                            ),

                            // GST Rates Selection
                            if (ref.watch(featureSettingsProvider).gstEnabled) ...[
                              const SizedBox(height: 16),
                              const _SubLabel(text: 'GST Tax Bracket'),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: AppConstants.gstRates.map((rate) => _ChoiceTag(
                                  label: rate == 0 ? '0% (Exempt)' : '${rate.toInt()}% GST',
                                  isSelected: _selectedGst == rate,
                                  onTap: () => setState(() => _selectedGst = rate),
                                )).toList(),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ── 3. INVENTORY & STOCK CARD ──
                        _FormCard(
                          title: isEditing ? 'Stock Status (Audited)' : 'Opening Inventory',
                          subtitle: 'Current physical quantity and low-stock alert trigger',
                          icon: Icons.warehouse_rounded,
                          isDark: isDark,
                          isMobile: isMobile,
                          children: [
                            if (isEditing) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.lock_clock_rounded, color: AppColors.primary, size: 28),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Current Stock: ${widget.product!.stock} ${widget.product!.unit}',
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'To maintain audit integrity, stock levels update automatically via Purchases, Sales, Returns & Adjustments.',
                                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            _ResponsiveRow(
                              isMobile: isMobile,
                              children: [
                                if (!isEditing)
                                  _PremiumField(
                                    controller: _stockCtrl,
                                    label: 'Initial Opening Stock Quantity',
                                    hint: '0',
                                    icon: Icons.inventory_2_rounded,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                _PremiumField(
                                  controller: _minStockCtrl,
                                  label: 'Low Stock Alert Threshold',
                                  hint: '5',
                                  icon: Icons.notifications_active_rounded,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            _SwitchRow(
                              label: 'Active Product Status',
                              subtitle: 'Allow item to be searched, sold, and included in stock calculations',
                              value: _isActive,
                              onChanged: (v) => setState(() => _isActive = v),
                              isDark: isDark,
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // ── ACTION BUTTONS ──
                        isMobile
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  AppShortcut(
                                    actionId: 'save',
                                    onPressed: _saveProduct,
                                    child: ElevatedButton.icon(
                                      onPressed: _saveProduct,
                                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                                      label: Text(saveBtnText, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 18),
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 3,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: Text(cancelBtnText, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 18),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: Text(cancelBtnText, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: AppShortcut(
                                      actionId: 'save',
                                      onPressed: _saveProduct,
                                      child: ElevatedButton.icon(
                                        onPressed: _saveProduct,
                                        icon: const Icon(Icons.check_circle_rounded, size: 20),
                                        label: Text(saveBtnText, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 18),
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          elevation: 4,
                                          shadowColor: AppColors.primary.withValues(alpha: 0.4),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
    );
  }

  Widget _buildLiveMarginHud(bool isDark) {
    final cost = double.tryParse(_purchasePriceCtrl.text) ?? 0.0;
    final sell = double.tryParse(_sellingPriceCtrl.text) ?? 0.0;
    if (cost <= 0 && sell <= 0) return const SizedBox.shrink();

    final profit = sell - cost;
    final margin = sell > 0 ? (profit / sell) * 100 : 0.0;
    final markup = cost > 0 ? (profit / cost) * 100 : 0.0;
    final isLoss = profit < 0;
    final isHealthy = profit > 0 && margin >= 15;

    final Color statusColor = isLoss
        ? AppColors.error
        : (isHealthy ? AppColors.success : AppColors.warning);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isLoss ? Icons.warning_amber_rounded : Icons.insights_rounded,
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isLoss ? 'Warning: Selling Below Cost Rate' : 'Live Margin & Profit Intelligence',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: statusColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${margin.toStringAsFixed(1)}% Margin',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _HudMetric(
                label: 'Gross Profit',
                value: '${profit >= 0 ? '+' : ''}₹${profit.toStringAsFixed(2)}',
                color: statusColor,
              ),
              _HudMetric(
                label: 'Markup on Cost',
                value: cost > 0 ? '${markup.toStringAsFixed(1)}%' : '0%',
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              _HudMetric(
                label: 'Selling Price',
                value: '₹${sell.toStringAsFixed(2)}',
                color: isDark ? Colors.white : AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  TextEditingController _getTierCtrl(CustomerType cat) {
    final catId = cat.id!;
    if (!_tieredPriceCtrls.containsKey(catId)) {
      String initialText = '';
      if (widget.product != null) {
        final lower = cat.name.toLowerCase();
        if (lower.contains('wholesale') && widget.product!.wholesalePrice > 0) {
          initialText = _formatNum(widget.product!.wholesalePrice);
        } else if ((lower.contains('dealer') || lower.contains('distributor')) && widget.product!.dealerPrice > 0) {
          initialText = _formatNum(widget.product!.dealerPrice);
        }
      }
      _tieredPriceCtrls[catId] = TextEditingController(text: initialText);
    }
    return _tieredPriceCtrls[catId]!;
  }

  void _saveProduct() async {
    setState(() => _nameError = null);
    if (!_formKey.currentState!.validate()) return;

    final tieredPrices = _tieredPriceCtrls.entries.map((e) {
      return ProductTierPrice(
        productId: widget.product?.id ?? 0,
        categoryId: e.key,
        price: double.tryParse(e.value.text) ?? 0,
      );
    }).where((p) => p.price > 0).toList();

    ref.read(productTieredPricesProvider.notifier).state = tieredPrices;

    double wholesale = double.tryParse(_wholesalePriceCtrl.text) ?? 0;
    double dealer = double.tryParse(_dealerPriceCtrl.text) ?? 0;

    final customerTypes = ref.read(customerTypesProvider).value ?? [];
    for (final tp in tieredPrices) {
      final ct = customerTypes.where((c) => c.id == tp.categoryId).firstOrNull;
      if (ct != null) {
        final lower = ct.name.toLowerCase();
        if (lower.contains('wholesale') && tp.price > 0) wholesale = tp.price;
        if ((lower.contains('dealer') || lower.contains('distributor')) && tp.price > 0) dealer = tp.price;
      }
    }

    final skuVal = _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim();
    final barcodeVal = _barcodeCtrl.text.trim().isNotEmpty
        ? _barcodeCtrl.text.trim()
        : skuVal;

    final product = Product(
      id: widget.product?.id,
      name: _nameCtrl.text.trim(),
      sku: skuVal,
      barcode: barcodeVal,
      brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      hsnSac: _hsnSacCtrl.text.trim().isEmpty ? null : _hsnSacCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      categoryId: _selectedCategoryId,
      subcategoryId: _selectedSubcategoryId,
      defaultSupplierId: _selectedSupplierId,
      purchasePrice: double.tryParse(_purchasePriceCtrl.text) ?? 0,
      mrp: double.tryParse(_mrpCtrl.text) ?? 0,
      sellingPrice: double.tryParse(_sellingPriceCtrl.text) ?? 0,
      minSellingPrice: 0,
      wholesalePrice: wholesale,
      dealerPrice: dealer,
      stock: double.tryParse(_stockCtrl.text) ?? 0,
      minStock: double.tryParse(_minStockCtrl.text) ?? 5,
      unit: _selectedUnit,
      gstPercent: _selectedGst,
      isActive: _isActive,
      imagePath: _selectedImagePath,
    );

    try {
      final success = await ref.read(productFormProvider.notifier).saveProduct(product);
      if (success && mounted) {
        Navigator.pop(context, product);
      }
    } on DuplicateProductNameException catch (e) {
      if (mounted) {
        setState(() => _nameError = 'A product named "${e.name}" already exists.');
        _formKey.currentState!.validate();
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Product?'),
        content: const Text('This will remove this item from active inventory. You can restore it afterwards.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final productId = widget.product!.id!;
              final productName = widget.product!.name;
              await ref.read(productFormProvider.notifier).deleteProduct(productId);
              if (mounted) {
                ref.read(notificationProvider.notifier).showWithUndo(
                  message: '"$productName" archived',
                  onUndo: () async {
                    await ref.read(productRepositoryProvider).restoreProduct(productId);
                    ref.invalidate(productsProvider);
                    ref.invalidate(inventoryStatsProvider);
                    AppAlert.success(ref, '"$productName" has been restored');
                  },
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _quickAddCategory(BuildContext context, WidgetRef ref, String name) async {
    final success = await ref.read(productFormProvider.notifier).saveCategory(Category(name: name));
    if (success) {
      final cats = await ref.read(categoriesProvider.future);
      final added = cats.firstWhere((c) => c.name == name);
      setState(() => _selectedCategoryId = added.id);
    }
  }

  void _quickAddSubcategory(BuildContext context, WidgetRef ref, String name, int categoryId) async {
    final success = await ref.read(productFormProvider.notifier).saveSubcategory(
      Subcategory(categoryId: categoryId, name: name),
    );
    if (success) {
      final subs = await ref.read(subcategoriesProvider(categoryId).future);
      final added = subs.firstWhere((s) => s.name == name);
      setState(() => _selectedSubcategoryId = added.id);
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedImagePath = result.files.single.path);

      final finalUrl = await MediaUploadService.uploadMedia(result.files.single.path!);
      if (mounted && finalUrl != result.files.single.path) {
        setState(() => _selectedImagePath = finalUrl);
      }
    }
  }
}

// ── RESPONSIVE ROW HELPER ──────────────────────────────────────────────────────

class _ResponsiveRow extends StatelessWidget {
  final bool isMobile;
  final List<Widget> children;
  static const double spacing = 16.0;

  const _ResponsiveRow({
    required this.isMobile,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final nonNullChildren = children.where((w) => w is! SizedBox || (w.width != 0 && w.height != 0)).toList();
    if (nonNullChildren.isEmpty) return const SizedBox.shrink();

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < nonNullChildren.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            nonNullChildren[i],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < nonNullChildren.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          Expanded(child: nonNullChildren[i]),
        ],
      ],
    );
  }
}

// ── HUD METRIC ─────────────────────────────────────────────────────────────────

class _HudMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HudMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color),
        ),
      ],
    );
  }
}

// ── IMAGE PICKER ───────────────────────────────────────────────────────────────

class _ImagePicker extends StatelessWidget {
  final String? imagePath;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final bool isDark;
  final bool isMobile;

  const _ImagePicker({
    this.imagePath,
    required this.onPick,
    required this.onRemove,
    required this.isDark,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final double height = isMobile ? 150 : 180;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.5,
        ),
      ),
      child: imagePath != null
          ? Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      File(imagePath!),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.black.withValues(alpha: 0.65),
                        child: IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
                          tooltip: 'Change Photo',
                          onPressed: onPick,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.error.withValues(alpha: 0.85),
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.white),
                          tooltip: 'Remove Photo',
                          onPressed: onRemove,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(22),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_a_photo_rounded,
                        size: 28,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Upload Product Photo',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap to browse files • Supports PNG, JPG, WebP',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
    ).animate().fadeIn(duration: 350.ms);
  }
}

// ── FORM CARD ──────────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;
  final bool isDark;
  final bool isMobile;

  const _FormCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.children,
    required this.isDark,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final double pad = isMobile ? 16.0 : 24.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

// ── PREMIUM FIELD ──────────────────────────────────────────────────────────────

class _PremiumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final String? externalError;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;

  const _PremiumField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.externalError,
    this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMultiline = maxLines > 1;
    final effectiveKeyboardType = isMultiline
        ? TextInputType.multiline
        : (keyboardType ?? TextInputType.text);
    final effectiveInputAction = isMultiline ? null : TextInputAction.next;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: effectiveKeyboardType,
      textInputAction: effectiveInputAction,
      onChanged: onChanged,
      validator: (v) {
        if (externalError != null) return externalError;
        return validator?.call(v);
      },
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, size: 20, color: AppColors.primary.withValues(alpha: 0.7)),
        suffixIcon: suffix,
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : AppColors.lightBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
      ),
    );
  }
}

// ── PREMIUM DROPDOWN ───────────────────────────────────────────────────────────

class _PremiumDropdown<T> extends StatelessWidget {
  final T value;
  final String label;
  final List<SearchableDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final IconData? icon;
  final Function(String)? onAdd;
  final String? addLabel;

  const _PremiumDropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
    this.icon,
    this.onAdd,
    this.addLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppSearchableDropdown<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      labelText: label,
      isDark: isDark,
      prefixIcon: icon ?? Icons.layers_rounded,
      onAdd: onAdd,
      addLabel: addLabel,
    );
  }
}

// ── CHOICE TAG ─────────────────────────────────────────────────────────────────

class _ChoiceTag extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _ChoiceTag({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.15),
            width: 1.4,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

// ── SUB LABEL ──────────────────────────────────────────────────────────────────

class _SubLabel extends StatelessWidget {
  final String text;
  const _SubLabel({required this.text});
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textMuted),
  );
}

// ── SWITCH ROW ─────────────────────────────────────────────────────────────────

class _SwitchRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;
  const _SwitchRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : AppColors.lightBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: AppColors.primary),
        ],
      ),
    );
  }
}
