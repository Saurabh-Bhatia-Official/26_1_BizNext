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
  late final TextEditingController _descCtrl;
  late final TextEditingController _purchasePriceCtrl;
  late final TextEditingController _sellingPriceCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _minStockCtrl;

  // Dynamic controllers for tiered prices
  final Map<int, TextEditingController> _tieredPriceCtrls = {};

  int? _selectedCategoryId;
  String _selectedUnit = 'pcs';
  double _selectedGst = 0;
  bool _isActive = true;
  String? _selectedImagePath;

  // Holds a duplicate-name error message from the server-side uniqueness check
  String? _nameError;

  bool get isEditing => widget.product != null;
  static const _units = ['pcs', 'kg', 'g', 'l', 'ml', 'box', 'pack', 'm'];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? widget.initialName ?? '');
    _skuCtrl = TextEditingController(text: p?.sku ?? '');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _purchasePriceCtrl = TextEditingController(text: p != null ? p.purchasePrice.toString() : '');
    _sellingPriceCtrl = TextEditingController(text: p != null ? p.sellingPrice.toString() : '');
    _stockCtrl = TextEditingController(text: p != null ? p.stock.toString() : '0');
    _minStockCtrl = TextEditingController(text: p != null ? p.minStock.toString() : '5');
    _selectedCategoryId = p?.categoryId;
    _selectedUnit = p?.unit ?? 'pcs';
    _selectedGst = p?.gstPercent ?? 0;
    _isActive = p?.isActive ?? true;
    _selectedImagePath = p?.imagePath;

    // Fetch existing tiered prices if editing
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
    for (final c in [_nameCtrl, _skuCtrl, _barcodeCtrl, _descCtrl, _purchasePriceCtrl, _sellingPriceCtrl, _stockCtrl, _minStockCtrl]) {
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
        title: Text(isEditing ? 'Edit Product' : 'New Product'),
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

              _FormCard(
                title: 'General Details',
                isDark: isDark,
                children: [
                  _PremiumField(
                    controller: _nameCtrl,
                    label: 'Product Name',
                    hint: 'Enter product title',
                    icon: Icons.title_rounded,
                    externalError: _nameError,
                    onChanged: (_) {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _PremiumField(
                          controller: _skuCtrl,
                          label: 'SKU',
                          hint: 'Stock keeping unit',
                          icon: Icons.tag_rounded,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _PremiumField(
                          controller: _barcodeCtrl,
                          label: 'Barcode',
                          hint: 'Scan or type',
                          icon: Icons.qr_code_scanner_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _PremiumField(
                    controller: _descCtrl,
                    label: 'Description',
                    hint: 'Brief product info',
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
                            onChanged: (v) => setState(() => _selectedCategoryId = v),
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (_, _) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _PremiumDropdown<String>(
                          value: _selectedUnit,
                          label: 'Unit',
                          items: _units.map((u) => SearchableDropdownItem(value: u, label: u)).toList(),
                          onChanged: (v) => setState(() => _selectedUnit = v ?? 'pcs'),
                          icon: Icons.straighten_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _FormCard(
                title: 'Pricing & Tax',
                isDark: isDark,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _PremiumField(
                          controller: _purchasePriceCtrl,
                          label: 'Cost Price',
                          hint: '0.00',
                          icon: Icons.shopping_bag_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _PremiumField(
                          controller: _sellingPriceCtrl,
                          label: 'Retail Price (Main)',
                          hint: '0.00',
                          icon: Icons.sell_rounded,
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
                      const _SubLabel(text: 'Additional Price Tiers'),
                      TextButton.icon(
                        onPressed: () => _showPriceCategoryManager(context),
                        icon: const Icon(Icons.settings_suggest_rounded, size: 16),
                        label: const Text('Manage Tiers', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  priceCatsAsync.when(
                    data: (cats) {
                      if (cats.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No custom price tiers defined.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
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
                                      label: cats[i].name,
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
                                        label: cats[i + 1].name,
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

              _FormCard(
                title: 'Stock Management',
                isDark: isDark,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _PremiumField(
                          controller: _stockCtrl,
                          label: 'Current Stock',
                          hint: '0',
                          icon: Icons.layers_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _PremiumField(
                          controller: _minStockCtrl,
                          label: 'Min Alert',
                          hint: '5',
                          icon: Icons.notifications_active_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SwitchRow(
                    label: 'Visible in POS',
                    subtitle: 'Show this product in billing screen',
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
    ),);
  }

  TextEditingController _getTierCtrl(int catId) {
    if (!_tieredPriceCtrls.containsKey(catId)) {
      _tieredPriceCtrls[catId] = TextEditingController();
    }
    return _tieredPriceCtrls[catId]!;
  }

  void _saveProduct() async {
    // Clear any previous name error before re-validating
    setState(() => _nameError = null);
    if (!_formKey.currentState!.validate()) return;

    // Collect tiered prices
    final tieredPrices = _tieredPriceCtrls.entries.map((e) {
      return ProductTierPrice(
        productId: widget.product?.id ?? 0,
        categoryId: e.key,
        price: double.tryParse(e.value.text) ?? 0,
      );
    }).where((p) => p.price > 0).toList();

    // Update the state provider so the notifier can pick it up
    ref.read(productTieredPricesProvider.notifier).state = tieredPrices;

    final product = Product(
      id: widget.product?.id,
      name: _nameCtrl.text.trim(),
      sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
      barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      categoryId: _selectedCategoryId,
      purchasePrice: double.tryParse(_purchasePriceCtrl.text) ?? 0,
      sellingPrice: double.tryParse(_sellingPriceCtrl.text) ?? 0,
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
        // Re-trigger form validation so the error is painted immediately
        _formKey.currentState!.validate();
      }
    }
  }

  /// Shows an animated success overlay for 1.5 s, then auto-pops the form.
  Future<void> _showSuccessAndClose(BuildContext context, bool wasEditing) async {
    if (!mounted) return;

    // Capture the navigator BEFORE any async gap – context may be stale later.
    final nav = Navigator.of(context);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => _SuccessOverlay(wasEditing: wasEditing),
    );

    // Let the animation play
    await Future.delayed(const Duration(milliseconds: 1600));

    // Close the overlay dialog (only if there's something to pop)
    if (nav.canPop()) nav.pop();

    await Future.delayed(const Duration(milliseconds: 100));

    // Close the product form screen
    if (nav.canPop()) nav.pop();
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Product?'),
        content: const Text('This will remove this item from your inventory. You can restore it afterwards.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final productId = widget.product!.id!;
              final productName = widget.product!.name;
              await ref.read(productFormProvider.notifier).deleteProduct(productId);
              if (mounted) {
                // Show undo notification
                ref.read(notificationProvider.notifier).showWithUndo(
                  message: '"$productName" deleted',
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

  void _showPriceCategoryManager(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryManagerScreen(
          title: 'Selling Price Tiers',
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
      // Temporarily show local path while uploading
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
  /// Error injected from outside (e.g. duplicate-name check from the server).
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
        // External error takes priority over the local validator
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

// ── Auto-closing success overlay ───────────────────────────────────────────────
class _SuccessOverlay extends StatelessWidget {
  final bool wasEditing;
  const _SuccessOverlay({required this.wasEditing});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated checkmark ring
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [
                  AppColors.success.withValues(alpha: 0.2),
                  AppColors.success.withValues(alpha: 0.05),
                ]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 56),
            )
                .animate()
                .scale(begin: const Offset(0.3, 0.3), end: const Offset(1, 1), duration: 450.ms, curve: Curves.elasticOut)
                .fadeIn(duration: 200.ms),
            const SizedBox(height: 24),
            Text(
              wasEditing ? 'Product Updated!' : 'Product Created!',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 300.ms)
                .slideY(begin: 0.15, end: 0, delay: 200.ms),
            const SizedBox(height: 8),
            Text(
              wasEditing
                  ? 'Changes saved successfully.'
                  : 'Added to your inventory.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.4),
            ).animate().fadeIn(delay: 350.ms, duration: 300.ms),
            const SizedBox(height: 28),
            // Thin progress bar showing auto-close countdown
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: null, // indeterminate
                backgroundColor: AppColors.success.withValues(alpha: 0.1),
                color: AppColors.success,
                minHeight: 4,
              ),
            ).animate().fadeIn(delay: 500.ms),
          ],
        ),
      ),
    );
  }
}
