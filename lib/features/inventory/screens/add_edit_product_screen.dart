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
import '../../../core/widgets/category_manager_screen.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../core/services/media_upload_service.dart';
import '../../../core/services/shortcut_service.dart';

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
  late final TextEditingController _minSellingPriceCtrl;
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
    _purchasePriceCtrl = TextEditingController(text: p != null ? p.purchasePrice.toString() : '');
    _mrpCtrl = TextEditingController(text: p != null && p.mrp > 0 ? p.mrp.toString() : '');
    _sellingPriceCtrl = TextEditingController(text: p != null ? p.sellingPrice.toString() : '');
    _minSellingPriceCtrl = TextEditingController(text: p != null && p.minSellingPrice > 0 ? p.minSellingPrice.toString() : '');
    _wholesalePriceCtrl = TextEditingController(text: p != null && p.wholesalePrice > 0 ? p.wholesalePrice.toString() : '');
    _dealerPriceCtrl = TextEditingController(text: p != null && p.dealerPrice > 0 ? p.dealerPrice.toString() : '');
    _stockCtrl = TextEditingController(text: p != null ? p.stock.toString() : '0');
    _minStockCtrl = TextEditingController(text: p != null ? p.minStock.toString() : '5');
    
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

  Future<void> _loadTieredPrices() async {
    final prices = await ref.read(productRepositoryProvider).getProductPrices(widget.product!.id!);
    if (mounted) {
      for (final p in prices) {
        _tieredPriceCtrls[p.categoryId] = TextEditingController(text: p.price.toString());
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _skuCtrl, _barcodeCtrl, _brandCtrl, _hsnSacCtrl, _descCtrl,
      _purchasePriceCtrl, _mrpCtrl, _sellingPriceCtrl, _minSellingPriceCtrl,
      _wholesalePriceCtrl, _dealerPriceCtrl, _stockCtrl, _minStockCtrl
    ]) {
      c.dispose();
    }
    for (final c in _tieredPriceCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoriesAsync = ref.watch(categoriesProvider);
    final subcategoriesAsync = ref.watch(subcategoriesProvider(_selectedCategoryId));
    final suppliersAsync = ref.watch(suppliersProvider);
    final priceCatsAsync = ref.watch(priceCategoriesProvider);
    final shortcuts = ref.watch(shortcutSettingsProvider);
    final saveShortcut = shortcuts['save'] ?? ShortcutNotifier.defaults['save']?.defaultShortcut ?? '';
    final cancelShortcut = shortcuts['cancel'] ?? ShortcutNotifier.defaults['cancel']?.defaultShortcut ?? '';
    final saveBtnLabel = isEditing ? 'Save Changes' : 'Create Product';
    final saveBtnText = saveShortcut.isNotEmpty ? '$saveBtnLabel ($saveShortcut)' : saveBtnLabel;
    final cancelBtnText = cancelShortcut.isNotEmpty ? 'Cancel ($cancelShortcut)' : 'Cancel';

    return AppShortcut(
      actionId: 'cancel',
      onPressed: () => Navigator.maybePop(context),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        appBar: AppBar(
          title: Text(isEditing ? 'Edit Product' : 'New Product Master'),
          backgroundColor: Colors.transparent,
          centerTitle: true,
          actions: [
            if (isEditing)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                onPressed: _confirmDelete,
              ),
            const SizedBox(width: 12),
          ],
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _ImagePicker(imagePath: _selectedImagePath, onPick: _pickImage, isDark: isDark),
                const SizedBox(height: 24),

                // ── GENERAL DETAILS CARD ──
                _FormCard(
                  title: 'Product Information',
                  isDark: isDark,
                  children: [
                    _PremiumField(
                      controller: _nameCtrl,
                      label: 'Product Name *',
                      hint: 'e.g. Basmati Rice 5kg, iPhone 15 Pro',
                      icon: Icons.title_rounded,
                      externalError: _nameError,
                      onChanged: (_) {
                        if (_nameError != null) setState(() => _nameError = null);
                      },
                      validator: (v) => v?.trim().isEmpty == true ? 'Product name is required' : null,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _PremiumField(
                            controller: _brandCtrl,
                            label: 'Brand / Manufacturer',
                            hint: 'e.g. Apple, Nestle',
                            icon: Icons.business_rounded,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _PremiumField(
                            controller: _hsnSacCtrl,
                            label: 'HSN / SAC Code',
                            hint: 'e.g. 10063020',
                            icon: Icons.numbers_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _PremiumField(
                            controller: _skuCtrl,
                            label: 'SKU / Item Code',
                            hint: 'Unique SKU identifier',
                            icon: Icons.tag_rounded,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _PremiumField(
                            controller: _barcodeCtrl,
                            label: 'Barcode / EAN',
                            hint: 'Scan or type barcode',
                            icon: Icons.qr_code_scanner_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _PremiumField(
                      controller: _descCtrl,
                      label: 'Description',
                      hint: 'Detailed product specifications & notes',
                      maxLines: 2,
                      icon: Icons.description_rounded,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: categoriesAsync.when(
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
                            ),
                            loading: () => const LinearProgressIndicator(),
                            error: (_, _) => const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: subcategoriesAsync.when(
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _PremiumDropdown<String>(
                            value: _selectedUnit,
                            label: 'Base Unit',
                            items: _units.map((u) => SearchableDropdownItem(value: u, label: u)).toList(),
                            onChanged: (v) => setState(() => _selectedUnit = v ?? 'pcs'),
                            icon: Icons.straighten_rounded,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: suppliersAsync.when(
                            data: (suppliers) => _PremiumDropdown<int?>(
                              value: _selectedSupplierId,
                              label: 'Default Supplier',
                              items: suppliers.map((s) => SearchableDropdownItem(value: s.id, label: s.name)).toList(),
                              onChanged: (v) => setState(() => _selectedSupplierId = v),
                              icon: Icons.local_shipping_rounded,
                            ),
                            loading: () => const LinearProgressIndicator(),
                            error: (_, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── PRICING MATRIX CARD ──
                _FormCard(
                  title: 'Pricing Architecture & Floor Control',
                  isDark: isDark,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _PremiumField(
                            controller: _purchasePriceCtrl,
                            label: 'Purchase Rate / Cost (WAC) ₹',
                            hint: '0.00',
                            icon: Icons.shopping_bag_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _PremiumField(
                            controller: _mrpCtrl,
                            label: 'MRP (Maximum Retail) ₹',
                            hint: '0.00',
                            icon: Icons.verified_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _PremiumField(
                            controller: _sellingPriceCtrl,
                            label: 'Standard Selling Price (Retail) ₹ *',
                            hint: '0.00',
                            icon: Icons.sell_rounded,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Selling price is required';
                              final numVal = double.tryParse(v);
                              if (numVal == null || numVal < 0) return 'Invalid price';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _PremiumField(
                            controller: _minSellingPriceCtrl,
                            label: 'Min Price (Floor Limit) ₹',
                            hint: 'Manager PIN below this',
                            icon: Icons.gavel_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _PremiumField(
                            controller: _wholesalePriceCtrl,
                            label: 'Wholesale Price ₹',
                            hint: 'For wholesale customers',
                            icon: Icons.storefront_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _PremiumField(
                            controller: _dealerPriceCtrl,
                            label: 'Dealer / Distributor Price ₹',
                            hint: 'For dealers & distributors',
                            icon: Icons.hub_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Dynamic Selling Price Tiers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _SubLabel(text: 'Customer-Specific Price Lists'),
                        TextButton.icon(
                          onPressed: () => _showPriceCategoryManager(context),
                          icon: const Icon(Icons.settings_suggest_rounded, size: 16),
                          label: const Text('Manage Lists', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    priceCatsAsync.when(
                      data: (cats) {
                        if (cats.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('No custom price lists configured.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          );
                        }
                        return Column(
                          children: [
                            for (int i = 0; i < cats.length; i += 2)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _PremiumField(
                                        controller: _getTierCtrl(cats[i].id!),
                                        label: '${cats[i].name} Price ₹',
                                        hint: '0.00',
                                        icon: Icons.handshake_rounded,
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    if (i + 1 < cats.length)
                                      Expanded(
                                        child: _PremiumField(
                                          controller: _getTierCtrl(cats[i + 1].id!),
                                          label: '${cats[i + 1].name} Price ₹',
                                          hint: '0.00',
                                          icon: Icons.handshake_rounded,
                                          keyboardType: TextInputType.number,
                                        ),
                                      )
                                    else
                                      const Expanded(child: SizedBox()),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const SizedBox(),
                    ),

                    if (ref.watch(featureSettingsProvider).gstEnabled) ...[
                      const SizedBox(height: 12),
                      const _SubLabel(text: 'Tax Rate (GST %)'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: AppConstants.gstRates.map((rate) => _ChoiceTag(
                          label: '${rate.toInt()}%',
                          isSelected: _selectedGst == rate,
                          onTap: () => setState(() => _selectedGst = rate),
                        )).toList(),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 24),

                // ── STOCK AUDIT CARD ──
                _FormCard(
                  title: isEditing ? 'Stock Status (Audited)' : 'Opening Inventory',
                  isDark: isDark,
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
                                    'Stock can only be modified via Purchase Entries, Sales, Returns, or Stock Adjustments.',
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
                    Row(
                      children: [
                        if (!isEditing) ...[
                          Expanded(
                            child: _PremiumField(
                              controller: _stockCtrl,
                              label: 'Opening Stock',
                              hint: '0',
                              icon: Icons.inventory_2_rounded,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        Expanded(
                          child: _PremiumField(
                            controller: _minStockCtrl,
                            label: 'Low Stock Alert Level',
                            hint: '5',
                            icon: Icons.notifications_active_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SwitchRow(
                      label: 'Active in POS & Catalog',
                      subtitle: 'Allow item to be sold and searched across terminals',
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      isDark: isDark,
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(cancelBtnText, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: AppShortcut(
                        actionId: 'save',
                        onPressed: _saveProduct,
                        child: ElevatedButton(
                          onPressed: _saveProduct,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: AppColors.primary.withValues(alpha: 0.4),
                          ),
                          child: Text(saveBtnText),
                        ),
                      ),
                    ),
                  ],
                ).animate().slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextEditingController _getTierCtrl(int catId) {
    if (!_tieredPriceCtrls.containsKey(catId)) {
      _tieredPriceCtrls[catId] = TextEditingController();
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

    final product = Product(
      id: widget.product?.id,
      name: _nameCtrl.text.trim(),
      sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
      barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
      brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      hsnSac: _hsnSacCtrl.text.trim().isEmpty ? null : _hsnSacCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      categoryId: _selectedCategoryId,
      subcategoryId: _selectedSubcategoryId,
      defaultSupplierId: _selectedSupplierId,
      purchasePrice: double.tryParse(_purchasePriceCtrl.text) ?? 0,
      mrp: double.tryParse(_mrpCtrl.text) ?? 0,
      sellingPrice: double.tryParse(_sellingPriceCtrl.text) ?? 0,
      minSellingPrice: double.tryParse(_minSellingPriceCtrl.text) ?? 0,
      wholesalePrice: double.tryParse(_wholesalePriceCtrl.text) ?? 0,
      dealerPrice: double.tryParse(_dealerPriceCtrl.text) ?? 0,
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
        Navigator.pop(context);
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

  void _showPriceCategoryManager(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryManagerScreen(
          title: 'Selling Price Lists',
          categoriesProvider: priceCategoriesProvider,
          onSave: (name, id) => ref.read(productFormProvider.notifier).savePriceCategory(PriceCategory(id: id, name: name)),
          onDelete: (id) => ref.read(productFormProvider.notifier).deletePriceCategory(id),
        ),
      ),
    );
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

class _ImagePicker extends StatelessWidget {
  final String? imagePath;
  final VoidCallback onPick;
  final bool isDark;
  const _ImagePicker({this.imagePath, required this.onPick, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 180, width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.5),
        ),
        child: imagePath != null
            ? ClipRRect(borderRadius: BorderRadius.circular(22), child: Image.file(File(imagePath!), fit: BoxFit.cover))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_rounded, size: 40, color: AppColors.primary.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  const Text('Add Product Image', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                ],
              ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }
}

class _FormCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isDark;
  const _FormCard({required this.title, required this.children, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class _PremiumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final bool enabled;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final String? externalError;
  final ValueChanged<String>? onChanged;

  const _PremiumField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.enabled = true,
    this.externalError,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator: (v) {
        if (externalError != null) return externalError;
        return validator?.call(v);
      },
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.primary.withValues(alpha: 0.7)),
        fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : AppColors.lightBg,
      ),
    );
  }
}

class _PremiumDropdown<T> extends StatelessWidget {
  final T value;
  final String label;
  final List<SearchableDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final IconData? icon;
  final Function(String)? onAdd;
  final String? addLabel;

  const _PremiumDropdown({required this.value, required this.label, required this.items, required this.onChanged, this.icon, this.onAdd, this.addLabel});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppSearchableDropdown<T>(
      value: value, items: items, onChanged: onChanged,
      labelText: label, isDark: isDark,
      prefixIcon: icon ?? Icons.layers_rounded,
      onAdd: onAdd, addLabel: addLabel,
    );
  }
}

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.1), width: 1.5),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.primary)),
      ),
    );
  }
}

class _SubLabel extends StatelessWidget {
  final String text;
  const _SubLabel({required this.text});
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted));
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;
  const _SwitchRow({required this.label, required this.subtitle, required this.value, required this.onChanged, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.03) : AppColors.lightBg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
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
