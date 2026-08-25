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
import '../../settings/providers/gst_settings_provider.dart';
import '../../inventory/screens/add_edit_product_screen.dart';
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
      AppAlert.error(ref, 'Failed to save purchase. Please ensure all required fields are filled.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final form = ref.watch(purchaseFormProvider);
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxHeight < 700;

          Widget mainContent = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Main Entry Area ──
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    _buildProductSearch(context, ref, isDark),
                    if (isSmallScreen)
                      SizedBox(height: 400, child: _PurchaseItemTable(isDark: isDark))
                    else
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
                  child: isSmallScreen
                      ? SizedBox(height: 600, child: _SummaryDetailsPanel(isDark: isDark, onComplete: () => _handleCompletePurchase(context, ref)))
                      : _SummaryDetailsPanel(isDark: isDark, onComplete: () => _handleCompletePurchase(context, ref)),
                ),
              ),
            ],
          );

          Widget body = Column(
            children: [
              // ── Header Bar ──
              _buildHeader(context, ref, isDark, form),

              if (isSmallScreen)
                mainContent
              else
                Expanded(child: mainContent),
            ],
          );

          if (isSmallScreen) {
            return SingleChildScrollView(child: body);
          }

          return body;
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, bool isDark, PurchaseFormState form) {
    final suppliersAsync = ref.watch(suppliersProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      ),
      child: Column(
        children: [
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
              const SizedBox(width: 16),
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
          const SizedBox(height: 24),
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
                  decoration: const InputDecoration(labelText: 'Bill Number', prefixIcon: Icon(Icons.receipt_long_rounded)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: InkWell(
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
                    decoration: const InputDecoration(labelText: 'Purchase Date', prefixIcon: Icon(Icons.calendar_today_rounded)),
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
                  decoration: InputDecoration(
                    hintText: 'Search product by name or scan barcode...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => setState(() => _searchController.clear()))
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
              ),
              child: productsAsync.when(
                data: (products) {
                  final filtered = products.where((p) => p.name.toLowerCase().contains(searchQuery)).toList();
                  if (filtered.isEmpty) {
                    return ListTile(
                      title: const Text('No products found'),
                      subtitle: const Text('Click + to add a new product'),
                      onTap: () => _quickAddProduct(context, ref, _searchController.text),
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
                        onTap: () {
                          ref.read(purchaseFormProvider.notifier).addItem(PurchaseItemModel(
                            productId: p.id!,
                            productName: p.name,
                            quantity: 1,
                            purchasePrice: p.purchasePrice,
                            gstPercent: p.gstPercent,
                            total: p.purchasePrice,
                          ));
                          setState(() {
                            _searchController.clear();
                            _searchFocus.requestFocus();
                          });
                        },
                      );
                    },
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox(),
              ),
            ),
        ],
      ),
    );
  }

  void _quickAddProduct(BuildContext context, WidgetRef ref, String name) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditProductScreen(initialName: name),
      ),
    );
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
        content: SizedBox(
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
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : AppColors.lightBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                const Expanded(flex: 4, child: Text('Product Name', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                const Expanded(flex: 2, child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                const Expanded(flex: 2, child: Text('Cost Price', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                const Expanded(flex: 1, child: Text('GST%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                const Expanded(flex: 2, child: Text('Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                const SizedBox(width: 48), // Action space
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_rounded, size: 64, color: AppColors.textMuted.withValues(alpha: 0.1)),
                        const SizedBox(height: 16),
                        const Text('No items added yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 16, fontWeight: FontWeight.w600)),
                        const Text('Search and select products to start recording.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.separated(
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

  @override
  void initState() {
    super.initState();
    final form = ref.read(purchaseFormProvider);
    _discountController = TextEditingController(text: form.discount > 0 ? form.discount.toString() : '');
    _paidAmountController = TextEditingController(text: form.paidAmount > 0 ? form.paidAmount.toString() : '');
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
    
    final providerPaidStr = form.paidAmount > 0 ? form.paidAmount.toString() : '';
    if (_paidAmountController.text != providerPaidStr && double.tryParse(_paidAmountController.text) != form.paidAmount) {
      _paidAmountController.text = providerPaidStr;
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Payment Summary', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 24),
                _SummaryLine(label: 'Items Total', value: form.subtotal),
                _SummaryLine(label: 'Total GST', value: form.totalGst),
                const Divider(height: 32),
                TextField(
                  controller: _discountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Extra Discount', prefixIcon: Icon(Icons.discount_rounded), prefixText: '₹ '),
                  onChanged: (v) => ref.read(purchaseFormProvider.notifier).setDiscount(double.tryParse(v) ?? 0),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _paidAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount Paid', prefixIcon: Icon(Icons.payments_rounded), prefixText: '₹ '),
                  onChanged: (v) => ref.read(purchaseFormProvider.notifier).setPaidAmount(double.tryParse(v) ?? 0),
                ),
                const SizedBox(height: 16),
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
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.white.withValues(alpha: 0.02) : AppColors.lightBg,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text('Grand Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMuted), overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(CurrencyFormatter.format(form.grandTotal), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text('Balance Due', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMuted), overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(CurrencyFormatter.format(form.balanceDue), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: form.balanceDue > 0 ? AppColors.error : AppColors.success), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Payment Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
              const SizedBox(height: 12),
              Row(
                children: AppConstants.paymentModes.map((mode) {
                  final isSelected = form.paymentMode == mode;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => ref.read(purchaseFormProvider.notifier).setPaymentMode(mode),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : (widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
                            borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: form.items.isEmpty || form.supplierId == null || form.isProcessing
                      ? null
                      : widget.onComplete,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
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
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMuted)),
          Text(CurrencyFormatter.format(value), style: const TextStyle(fontWeight: FontWeight.w800)),
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

