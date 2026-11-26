// lib/features/purchases/screens/add_purchase_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/widgets/searchable_dropdown.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../suppliers/models/supplier_model.dart';
import '../../suppliers/providers/supplier_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../models/purchase_model.dart';
import '../providers/purchase_provider.dart';
import '../../inventory/models/product_model.dart';
import '../../settings/providers/gst_settings_provider.dart';
import '../../inventory/screens/add_edit_product_screen.dart';
import '../../../core/widgets/qr_scanner_screen.dart';
import '../../../core/services/hardware_scanner_service.dart';
import 'package:intl/intl.dart';

class AddPurchaseScreen extends ConsumerStatefulWidget {
  final PurchaseModel? initialPurchase;
  const AddPurchaseScreen({super.key, this.initialPurchase});

  @override
  ConsumerState<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends ConsumerState<AddPurchaseScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  
  // Controllers for header fields to support editing
  late final TextEditingController _billNoController;

  @override
  void initState() {
    super.initState();
    _billNoController = TextEditingController(text: widget.initialPurchase?.billNo);
    
    if (widget.initialPurchase != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(purchaseFormProvider.notifier).initForEdit(widget.initialPurchase!, widget.initialPurchase!.items ?? []);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _billNoController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _handleCompletePurchase(BuildContext context, WidgetRef ref) async {
    final success = await ref.read(purchaseFormProvider.notifier).savePurchase();
    if (success && context.mounted) {
      AppAlert.success(ref, 'Purchase recorded successfully');
      if (widget.initialPurchase != null) {
        Navigator.pop(context);
      } else {
        // Reset local state for next purchase
        _billNoController.clear();
        _searchController.clear();
        _searchFocus.requestFocus();
      }
    } else if (context.mounted) {
      final err = ref.read(purchaseFormProvider).lastError;
      AppAlert.error(ref, err ?? 'Failed to save purchase. Please ensure all required fields are filled.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final form = ref.watch(purchaseFormProvider);
    
    return HardwareBarcodeScannerListener(
      onBarcodeScanned: _onBarcodeScanned,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 800 || constraints.maxHeight < 700;

          Widget mainContent = isMobile 
            ? Column(
                children: [
                  _buildProductSearch(context, ref, isDark),
                  SizedBox(height: 400, child: _PurchaseItemTable(isDark: isDark)),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      boxShadow: isDark ? [] : [const BoxShadow(color: Color(0x08000000), blurRadius: 30, offset: Offset(0, 10))],
                    ),
                    child: SizedBox(
                      height: 600,
                      child: _SummaryDetailsPanel(isDark: isDark, onComplete: () => _handleCompletePurchase(context, ref)),
                    ),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Main Entry Area ──
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [
                        _buildProductSearch(context, ref, isDark),
                        Expanded(child: _PurchaseItemTable(isDark: isDark)),
                      ],
                    ),
                  ),

                  // ── Summary & Payment Panel ──
                  Expanded(
                    flex: 3,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(0, 0, 24, 24),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        boxShadow: isDark ? [] : [const BoxShadow(color: Color(0x08000000), blurRadius: 30, offset: Offset(0, 10))],
                      ),
                      child: _SummaryDetailsPanel(isDark: isDark, onComplete: () => _handleCompletePurchase(context, ref)),
                    ),
                  ),
                ],
              );

          Widget body = Column(
            children: [
              // ── Header Bar ──
              _buildHeader(context, ref, isDark, form),

              if (isMobile)
                mainContent
              else
                Expanded(child: mainContent),
            ],
          );

          if (isMobile) {
            return SingleChildScrollView(child: body);
          }

          return body;
        },
      ),
    ),
    );
  }

  Future<void> _addPurchasedProduct(Product p) async {
    final currentForm = ref.read(purchaseFormProvider);
    final businessId = ref.read(activeBusinessIdProvider);
    double itemPrice = p.purchasePrice;
    if (currentForm.supplierId != null && p.id != null) {
      final lastPrice = await ref.read(purchaseRepositoryProvider).getLastPurchasePrice(currentForm.supplierId!, p.id!, businessId);
      if (lastPrice != null && lastPrice > 0) {
        itemPrice = lastPrice;
      }
    }
    ref.read(purchaseFormProvider.notifier).addItem(PurchaseItemModel(
      productId: p.id!,
      productName: p.name,
      quantity: 1,
      purchasePrice: itemPrice,
      gstPercent: p.gstPercent,
      total: itemPrice,
    ));
    setState(() {
      _searchController.clear();
      _searchFocus.requestFocus();
    });
  }

  void _onBarcodeScanned(String code) {
    final products = ref.read(productsProvider).value ?? [];
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;

    final match = products.firstWhere(
      (p) => (p.barcode?.toLowerCase() == trimmed.toLowerCase() || p.sku?.toLowerCase() == trimmed.toLowerCase()),
      orElse: () => const Product(name: '', sellingPrice: 0, stock: 0, unit: '', categoryId: 0),
    );

    if (match.name.isNotEmpty) {
      _addPurchasedProduct(match);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Scanned & added "${match.name}" to purchase')),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      _searchController.text = trimmed;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Barcode "$trimmed" not found. Click + to add new product.')),
            ],
          ),
          backgroundColor: AppColors.primaryDark,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, bool isDark, PurchaseFormState form) {
    final suppliersAsync = ref.watch(suppliersProvider);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Container(
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, isMobile ? 18 : 24, isMobile ? 16 : 24, isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isMobile) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.initialPurchase == null ? 'New Purchase Entry' : 'Edit Purchase',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Supplier purchase record entry',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (form.isProcessing)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _HeaderActionButton(
                    label: 'Reset',
                    icon: Icons.refresh_rounded,
                    color: AppColors.error,
                    onPressed: () {
                      _billNoController.clear();
                      ref.read(purchaseFormProvider.notifier).reset();
                    },
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: form.items.isEmpty || form.supplierId == null || form.isProcessing
                        ? null
                        : () => _handleCompletePurchase(context, ref),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Complete Purchase', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.initialPurchase == null ? 'New Purchase Entry' : 'Edit Purchase',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Optimized for high-volume data entry',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (form.isProcessing)
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: CircularProgressIndicator(),
                  ),
                _HeaderActionButton(
                  label: 'Reset Form',
                  icon: Icons.refresh_rounded,
                  color: AppColors.error,
                  onPressed: () {
                    _billNoController.clear();
                    ref.read(purchaseFormProvider.notifier).reset();
                  },
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: form.items.isEmpty || form.supplierId == null || form.isProcessing
                      ? null
                      : () => _handleCompletePurchase(context, ref),
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: const Text('Complete Purchase'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          if (isMobile)
            Column(
              children: [
                suppliersAsync.when(
                  data: (suppliers) => AppSearchableDropdown<int?>(
                    value: form.supplierId,
                    labelText: 'Select Supplier*',
                    prefixIcon: Icons.business_rounded,
                    isDark: isDark,
                    addLabel: 'Quick Add Supplier',
                    onAdd: (name) => _quickAddSupplier(context, ref, name),
                    items: suppliers.map((s) => SearchableDropdownItem(value: s.id, label: s.name)).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        final s = suppliers.firstWhere((sup) => sup.id == v);
                        ref.read(purchaseFormProvider.notifier).selectSupplier(v, s.name);
                      }
                    },
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _billNoController,
                  onChanged: (v) => ref.read(purchaseFormProvider.notifier).setBillNo(v),
                  decoration: AppTheme.inputDecoration(
                    labelText: 'Bill Number',
                    prefixIcon: Icons.receipt_long_rounded,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: form.date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) ref.read(purchaseFormProvider.notifier).setDate(date);
                  },
                  child: InputDecorator(
                    decoration: AppTheme.inputDecoration(
                      labelText: 'Purchase Date',
                      prefixIcon: Icons.calendar_today_rounded,
                      isDark: isDark,
                    ),
                    child: Text(DateFormat('dd MMM yyyy').format(form.date), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: suppliersAsync.when(
                    data: (suppliers) => AppSearchableDropdown<int?>(
                      value: form.supplierId,
                      labelText: 'Select Supplier*',
                      prefixIcon: Icons.business_rounded,
                      isDark: isDark,
                      addLabel: 'Quick Add Supplier',
                      onAdd: (name) => _quickAddSupplier(context, ref, name),
                      items: suppliers.map((s) => SearchableDropdownItem(value: s.id, label: s.name)).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          final s = suppliers.firstWhere((sup) => sup.id == v);
                          ref.read(purchaseFormProvider.notifier).selectSupplier(v, s.name);
                        }
                      },
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _billNoController,
                    onChanged: (v) => ref.read(purchaseFormProvider.notifier).setBillNo(v),
                    decoration: AppTheme.inputDecoration(
                      labelText: 'Bill Number',
                      prefixIcon: Icons.receipt_long_rounded,
                      isDark: isDark,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: form.date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) ref.read(purchaseFormProvider.notifier).setDate(date);
                    },
                    child: InputDecorator(
                      decoration: AppTheme.inputDecoration(
                        labelText: 'Purchase Date',
                        prefixIcon: Icons.calendar_today_rounded,
                        isDark: isDark,
                      ),
                      child: Text(DateFormat('dd MMM yyyy').format(form.date), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildProductSearch(BuildContext context, WidgetRef ref, bool isDark) {
    final productsAsync = ref.watch(productsProvider);
    final searchQuery = _searchController.text.toLowerCase();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onChanged: (v) => setState(() {}),
                  decoration: AppTheme.inputDecoration(
                    labelText: 'Search Product',
                    prefixIcon: Icons.search_rounded,
                    isDark: isDark,
                  ).copyWith(
                    hintText: 'Search product by name or scan barcode...',
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => setState(() => _searchController.clear()))
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: () async {
                  final code = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(builder: (context) => const QRScannerScreen()),
                  );
                  if (code != null && code.isNotEmpty) {
                    _onBarcodeScanned(code);
                  }
                },
                icon: const Icon(Icons.qr_code_scanner_rounded),
                tooltip: 'Scan Barcode with Camera',
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () => _quickAddProduct(context, ref, _searchController.text),
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Add New Product',
              ),
            ],
          ),
          if (searchQuery.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
              ),
              child: Material(
                color: isDark ? AppColors.darkSurface : Colors.white,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: productsAsync.when(
                data: (products) {
                  final filtered = products.where((p) =>
                      p.name.toLowerCase().contains(searchQuery) ||
                      (p.barcode != null && p.barcode!.toLowerCase().contains(searchQuery)) ||
                      (p.sku != null && p.sku!.toLowerCase().contains(searchQuery))).toList();
                  if (filtered.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Icon(Icons.search_off_rounded, color: isDark ? Colors.white54 : Colors.black45, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'No products found matching "$searchQuery"',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: isDark ? Colors.white : AppColors.textLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tap "+ Add New Product" to create it now',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white54 : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _quickAddProduct(context, ref, _searchController.text),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final p = filtered[i];
                      return ListTile(
                        leading: const Icon(Icons.inventory_2_outlined, size: 20),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('Current Stock: ${p.stock} | Last Cost: ₹${p.purchasePrice}'),
                        trailing: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                        onTap: () => _addPurchasedProduct(p),
                      );
                    },
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _quickAddProduct(BuildContext context, WidgetRef ref, String name) async {
    final created = await Navigator.push<Product?>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditProductScreen(initialName: name),
      ),
    );
    if (created != null && context.mounted) {
      ref.invalidate(productsProvider);
      ref.read(purchaseFormProvider.notifier).addItem(PurchaseItemModel(
        productId: created.id ?? 0,
        productName: created.name,
        quantity: 1,
        purchasePrice: created.purchasePrice,
        gstPercent: created.gstPercent,
        total: created.purchasePrice,
      ));
      _searchController.clear();
      AppAlert.success(ref, 'Added "${created.name}" to purchase');
    }
  }

  void _quickAddSupplier(BuildContext context, WidgetRef ref, String initialName) async {
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    final gstController = TextEditingController();
    final balanceController = TextEditingController(text: '0.0');
    String name = initialName;
    
    final result = await showDialog<SupplierModel?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Quick Add Supplier', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Builder(
          builder: (dialogCtx) {
            final isDialogMobile = MediaQuery.of(dialogCtx).size.width < 550;
            return SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: TextEditingController(text: name),
                      onChanged: (v) => name = v,
                      decoration: const InputDecoration(labelText: 'Supplier Name*', prefixIcon: Icon(Icons.business_rounded)),
                    ),
                    const SizedBox(height: 16),
                    if (isDialogMobile) ...[
                      TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_rounded)), keyboardType: TextInputType.phone),
                      const SizedBox(height: 16),
                      TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_rounded)), keyboardType: TextInputType.emailAddress),
                    ] else
                      Row(
                        children: [
                          Expanded(child: TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_rounded)), keyboardType: TextInputType.phone)),
                          const SizedBox(width: 12),
                          Expanded(child: TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_rounded)), keyboardType: TextInputType.emailAddress)),
                        ],
                      ),
                    const SizedBox(height: 16),
                    TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on_rounded))),
                    const SizedBox(height: 16),
                    if (isDialogMobile) ...[
                      TextField(controller: gstController, decoration: const InputDecoration(labelText: 'GST Number', prefixIcon: Icon(Icons.badge_rounded))),
                      const SizedBox(height: 16),
                      TextField(controller: balanceController, decoration: const InputDecoration(labelText: 'Opening Balance', prefixIcon: Icon(Icons.account_balance_rounded)), keyboardType: TextInputType.number),
                    ] else
                      Row(
                        children: [
                          Expanded(child: TextField(controller: gstController, decoration: const InputDecoration(labelText: 'GST Number', prefixIcon: Icon(Icons.badge_rounded)))),
                          const SizedBox(width: 12),
                          Expanded(child: TextField(controller: balanceController, decoration: const InputDecoration(labelText: 'Opening Balance', prefixIcon: Icon(Icons.account_balance_rounded)), keyboardType: TextInputType.number)),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (name.trim().isEmpty) return;
              final businessId = ref.read(activeBusinessIdProvider);
              final supplier = SupplierModel(
                businessId: businessId,
                name: name.trim(),
                phone: phoneController.text.trim(),
                email: emailController.text.trim(),
                address: addressController.text.trim(),
                gstNumber: gstController.text.trim(),
                balance: double.tryParse(balanceController.text) ?? 0.0,
              );
              Navigator.pop(ctx, supplier);
            },
            child: const Text('Save Supplier'),
          ),
        ],
      ),
    );

    if (result != null) {
      final success = await ref.read(supplierFormProvider.notifier).saveSupplier(result);
      if (success) {
        final suppliers = await ref.read(suppliersProvider.future);
        final added = suppliers.firstWhere((s) => s.name == result.name);
        ref.read(purchaseFormProvider.notifier).selectSupplier(added.id!, added.name);
      }
    }
  }
}

class _PurchaseItemTable extends ConsumerWidget {
  final bool isDark;
  const _PurchaseItemTable({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(purchaseFormProvider).items;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 650;

          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_rounded, size: 56, color: AppColors.textMuted.withValues(alpha: 0.15)),
                    const SizedBox(height: 14),
                    const Text('No items added yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text('Search and select products above to start building the invoice.', style: TextStyle(color: AppColors.textMuted, fontSize: 12), textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          if (isMobile) {
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return _MobilePurchaseItemCard(item: item, index: index, isDark: isDark);
              },
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: constraints.maxWidth < 800 ? 800 : constraints.maxWidth,
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.03) : AppColors.lightBg,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 4, child: Text('Product Name', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                        Expanded(flex: 2, child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                        Expanded(flex: 2, child: Text('Cost Price', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                        Expanded(flex: 1, child: Text('GST%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                        Expanded(flex: 2, child: Text('Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                        SizedBox(width: 48), // Action space
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(0),
                      itemCount: items.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _EditablePurchaseRow(item: item, index: index, isDark: isDark);
                      },
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
}

class _EditablePurchaseRow extends ConsumerWidget {
  final PurchaseItemModel item;
  final int index;
  final bool isDark;

  const _EditablePurchaseRow({required this.item, required this.index, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  softWrap: true,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    InkWell(
                      onTap: () => _editProduct(context, ref, item.productId),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_note_rounded, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text('Edit Product', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('PID: ${item.productId}', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TextFormField(
                initialValue: item.quantity.toString(),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontWeight: FontWeight.w700),
                decoration: _fieldDecoration(isDark),
                onChanged: (v) => ref.read(purchaseFormProvider.notifier).updateItem(item.productId, qty: double.tryParse(v) ?? 0),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TextFormField(
                initialValue: item.purchasePrice.toString(),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontWeight: FontWeight.w700),
                decoration: _fieldDecoration(isDark, prefix: '₹'),
                onChanged: (v) => ref.read(purchaseFormProvider.notifier).updateItem(item.productId, price: double.tryParse(v) ?? 0),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: DropdownButtonFormField<double>(
                initialValue: ref.watch(gstRatesProvider).contains(item.gstPercent) ? item.gstPercent : ref.watch(gstRatesProvider).first,
                isExpanded: true,
                items: ref.watch(gstRatesProvider).map((rate) => DropdownMenuItem(
                  value: rate,
                  child: Text('${rate.toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                )).toList(),
                onChanged: (v) => ref.read(purchaseFormProvider.notifier).updateItem(item.productId, gst: v),
                decoration: _fieldDecoration(isDark).copyWith(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              CurrencyFormatter.format(item.total),
              style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary),
            ),
          ),
          IconButton(
            onPressed: () => ref.read(purchaseFormProvider.notifier).removeItem(item.productId),
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  void _editProduct(BuildContext context, WidgetRef ref, int productId) async {
    final products = await ref.read(productsProvider.future);
    final product = products.firstWhere((p) => p.id == productId);
    
    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditProductScreen(product: product),
      ),
    );
  }

  InputDecoration _fieldDecoration(bool isDark, {String? prefix, String? suffix}) {
    return InputDecoration(
      prefixText: prefix != null ? '$prefix ' : null,
      suffixText: suffix != null ? ' $suffix' : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.lightBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      isDense: true,
    );
  }
}

class _MobilePurchaseItemCard extends ConsumerWidget {
  final PurchaseItemModel item;
  final int index;
  final bool isDark;

  const _MobilePurchaseItemCard({required this.item, required this.index, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => ref.read(purchaseFormProvider.notifier).removeItem(item.productId),
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Remove Item',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Quantity with stepper
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    _StepButton(
                      icon: Icons.remove,
                      onTap: () {
                        if (item.quantity > 1) {
                          ref.read(purchaseFormProvider.notifier).updateItem(item.productId, qty: item.quantity - 1);
                        }
                      },
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: TextFormField(
                          key: ValueKey('qty_${item.productId}_${item.quantity}'),
                          initialValue: item.quantity.toString(),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            filled: true,
                            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.lightBg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                          onChanged: (v) {
                            final q = double.tryParse(v);
                            if (q != null && q > 0) {
                              ref.read(purchaseFormProvider.notifier).updateItem(item.productId, qty: q);
                            }
                          },
                        ),
                      ),
                    ),
                    _StepButton(
                      icon: Icons.add,
                      onTap: () => ref.read(purchaseFormProvider.notifier).updateItem(item.productId, qty: item.quantity + 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Rate
              Expanded(
                flex: 3,
                child: TextFormField(
                  key: ValueKey('rate_${item.productId}_${item.purchasePrice}'),
                  initialValue: item.purchasePrice.toString(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  decoration: InputDecoration(
                    prefixText: '₹',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.lightBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => ref.read(purchaseFormProvider.notifier).updateItem(item.productId, price: double.tryParse(v) ?? 0),
                ),
              ),
              const SizedBox(width: 8),

              // GST %
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<double>(
                  initialValue: ref.watch(gstRatesProvider).contains(item.gstPercent) ? item.gstPercent : ref.watch(gstRatesProvider).first,
                  isExpanded: true,
                  items: ref.watch(gstRatesProvider).map((rate) => DropdownMenuItem(
                    value: rate,
                    child: Text('${rate.toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  )).toList(),
                  onChanged: (v) => ref.read(purchaseFormProvider.notifier).updateItem(item.productId, gst: v),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.lightBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                  dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PID #${item.productId}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              Text(
                'Total: ${CurrencyFormatter.format(item.total)}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}

class _SummaryDetailsPanel extends ConsumerStatefulWidget {
  final bool isDark;
  final VoidCallback onComplete;
  const _SummaryDetailsPanel({required this.isDark, required this.onComplete});

  @override
  ConsumerState<_SummaryDetailsPanel> createState() => _SummaryDetailsPanelState();
}

class _SummaryDetailsPanelState extends ConsumerState<_SummaryDetailsPanel> {
  late final TextEditingController _discountController;
  late final TextEditingController _paidAmountController;
  bool _isFolded = false;

  @override
  void initState() {
    super.initState();
    final form = ref.read(purchaseFormProvider);
    _discountController = TextEditingController(text: form.discount > 0 ? form.discount.toString() : '');
    _paidAmountController = TextEditingController(text: form.paidAmount > 0 ? form.paidAmount.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '') : '');
  }

  @override
  void dispose() {
    _discountController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(purchaseFormProvider);
    final accountsAsync = ref.watch(accountsProvider);

    // Sync from provider to controllers if modified externally (e.g. form reset or loaded for edit)
    final providerDiscountStr = form.discount > 0 ? form.discount.toString() : '';
    if (_discountController.text != providerDiscountStr && double.tryParse(_discountController.text) != form.discount) {
      _discountController.text = providerDiscountStr;
    }
    
    final providerPaidStr = form.paidAmount > 0 ? form.paidAmount.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '') : '';
    if (_paidAmountController.text != providerPaidStr && (double.tryParse(_paidAmountController.text) ?? -1) != form.paidAmount) {
      _paidAmountController.text = providerPaidStr;
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Fold / Expand Header Bar ──
                InkWell(
                  onTap: () => setState(() => _isFolded = !_isFolded),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Payment Summary',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _isFolded ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                if (!_isFolded) ...[
                  const SizedBox(height: 12),
                  // Collapsible items breakdown
                  _CollapsibleSummarySection(
                    isDark: widget.isDark,
                    form: form,
                  ),
                  const Divider(height: 24),
                  TextField(
                    controller: _discountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Extra Discount', prefixIcon: Icon(Icons.discount_rounded), prefixText: '₹ '),
                    onChanged: (v) => ref.read(purchaseFormProvider.notifier).setDiscount(double.tryParse(v) ?? 0),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _paidAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount Paid', prefixIcon: Icon(Icons.payments_rounded), prefixText: '₹ '),
                    onChanged: (v) => ref.read(purchaseFormProvider.notifier).setPaidAmount(double.tryParse(v) ?? 0),
                  ),
                  const SizedBox(height: 14),
                  accountsAsync.when(
                    data: (accounts) => AppSearchableDropdown<int?>(
                      value: form.selectedAccountId,
                      labelText: 'Paid From Account',
                      prefixIcon: Icons.account_balance_wallet_rounded,
                      items: accounts.map((a) => SearchableDropdownItem(value: a.id, label: '${a.name} (₹${a.balance})')).toList(),
                      onChanged: (v) => ref.read(purchaseFormProvider.notifier).setAccount(v),
                      isDark: widget.isDark,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const SizedBox(),
                  ),
                ],
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.white.withValues(alpha: 0.02) : AppColors.lightBg,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Grand Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          CurrencyFormatter.format(form.grandTotal), 
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Balance Due', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          CurrencyFormatter.format(form.balanceDue), 
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: form.balanceDue > 0 ? AppColors.error : AppColors.success),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payment Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: form.paymentStatus == 'paid'
                          ? AppColors.success.withValues(alpha: 0.1)
                          : (form.paymentStatus == 'partially_paid'
                              ? Colors.orange.withValues(alpha: 0.1)
                              : AppColors.error.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      form.paymentStatus.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: form.paymentStatus == 'paid'
                            ? AppColors.success
                            : (form.paymentStatus == 'partially_paid'
                                ? Colors.orange
                                : AppColors.error),
                      ),
                    ),
                  ),
                ],
              ),
              if (!_isFolded) ...[
                const SizedBox(height: 16),
                const Text('Payment Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                Row(
                  children: AppConstants.paymentModes.map((mode) {
                    final isSelected = form.paymentMode == mode;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          onTap: () => ref.read(purchaseFormProvider.notifier).setPaymentMode(mode),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : (widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? AppColors.primary : (widget.isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                            ),
                            alignment: Alignment.center,
                            child: Text(mode, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : AppColors.textMuted)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: form.items.isEmpty || form.supplierId == null || form.isProcessing
                      ? null
                      : widget.onComplete,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(form.isProcessing ? 'SAVING...' : 'SAVE PURCHASE (F2)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Collapsible Purchase Summary Section ─────────────────────────────────────
class _CollapsibleSummarySection extends StatelessWidget {
  final bool isDark;
  final dynamic form; // purchaseFormState

  const _CollapsibleSummarySection({required this.isDark, required this.form});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryLine(label: 'Items Total (Gross)', value: form.subtotal),
        if (form.totalDiscount > 0)
          _SummaryLine(label: 'Total Discount', value: -form.totalDiscount),
        _SummaryLine(label: 'Net Taxable Value', value: form.taxableAmount),
        _SummaryLine(label: 'Total GST (ITC)', value: form.totalGst),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final double value;
  const _SummaryLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMuted),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              CurrencyFormatter.format(value),
              style: const TextStyle(fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool isDark;

  const _HeaderActionButton({required this.label, required this.icon, required this.color, required this.onPressed, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      style: TextButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

