// lib/features/suppliers/screens/add_edit_supplier_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/supplier_model.dart';
import '../providers/supplier_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../core/services/shortcut_service.dart';

class AddEditSupplierScreen extends ConsumerStatefulWidget {
  final SupplierModel? supplier;
  const AddEditSupplierScreen({super.key, this.supplier});

  @override
  ConsumerState<AddEditSupplierScreen> createState() => _AddEditSupplierScreenState();
}

class _AddEditSupplierScreenState extends ConsumerState<AddEditSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _gstCtrl;
  late final TextEditingController _balanceCtrl;

  bool get isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _phoneCtrl = TextEditingController(text: s?.phone ?? '');
    _emailCtrl = TextEditingController(text: s?.email ?? '');
    _addressCtrl = TextEditingController(text: s?.address ?? '');
    _gstCtrl = TextEditingController(text: s?.gstNumber ?? '');
    _balanceCtrl = TextEditingController(text: s?.balance.toString() ?? '0');
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _phoneCtrl, _emailCtrl, _addressCtrl, _gstCtrl, _balanceCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formState = ref.watch(supplierFormProvider);
    final shortcuts = ref.watch(shortcutSettingsProvider);
    final saveShortcut = shortcuts['save'] ?? ShortcutNotifier.defaults['save']?.defaultShortcut ?? '';
    final saveBtnLabel = isEditing ? 'Save Changes' : 'Register Supplier';
    final saveBtnText = saveShortcut.isNotEmpty ? '$saveBtnLabel ($saveShortcut)' : saveBtnLabel;

    return AppShortcut(
      actionId: 'cancel',
      onPressed: () => Navigator.maybePop(context),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        appBar: AppBar(
          title: Text(isEditing ? 'Edit Supplier' : 'New Supplier'),
          backgroundColor: Colors.transparent,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _FormCard(
                title: 'Supplier Details',
                isDark: isDark,
                children: [
                  _SupplierField(
                    controller: _nameCtrl,
                    label: 'Supplier Name',
                    hint: 'e.g. ABC Wholesalers',
                    icon: Icons.business_rounded,
                    validator: (v) => v?.isEmpty == true ? 'Name required' : null,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _SupplierField(
                          controller: _phoneCtrl,
                          label: 'Phone',
                          hint: '+91...',
                          icon: Icons.phone_rounded,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _SupplierField(
                          controller: _emailCtrl,
                          label: 'Email',
                          hint: 'sales@abc.com',
                          icon: Icons.email_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _FormCard(
                title: 'Tax & Financials',
                isDark: isDark,
                children: [
                  if (ref.watch(featureSettingsProvider).gstEnabled)
                    _SupplierField(
                      controller: _gstCtrl,
                      label: 'GST Number',
                      hint: '15-digit GSTIN',
                      icon: Icons.tag_rounded,
                    ),
                  if (ref.watch(featureSettingsProvider).gstEnabled)
                    const SizedBox(height: 20),
                  _SupplierField(
                    controller: _balanceCtrl,
                    label: 'Current Balance',
                    hint: '0.00',
                    icon: Icons.account_balance_wallet_rounded,
                    keyboardType: TextInputType.number,
                    helperText: 'Positive for payable, Negative for receivable',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _FormCard(
                title: 'Full Address',
                isDark: isDark,
                children: [
                  _SupplierField(
                    controller: _addressCtrl,
                    label: 'Address',
                    hint: 'Full vendor address...',
                    icon: Icons.location_on_rounded,
                    maxLines: 2,
                  ),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: AppShortcut(
                  actionId: 'save',
                  onPressed: formState.isLoading ? null : _save,
                  child: ElevatedButton(
                    onPressed: formState.isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: formState.isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(saveBtnText, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),);
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    final businessId = ref.read(activeBusinessIdProvider);
    final supplier = SupplierModel(
      id: widget.supplier?.id,
      businessId: businessId,
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      gstNumber: _gstCtrl.text.trim(),
      balance: double.tryParse(_balanceCtrl.text) ?? 0,
    );
    final success = await ref.read(supplierFormProvider.notifier).saveSupplier(supplier);
    if (success && mounted) Navigator.pop(context);
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
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}

class _SupplierField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final TextInputType keyboardType;
  final String? helperText;
  final String? Function(String?)? validator;

  const _SupplierField({required this.controller, required this.label, required this.hint, required this.icon, this.maxLines = 1, this.keyboardType = TextInputType.text, this.helperText, this.validator});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : AppColors.lightBg,
      ),
    );
  }
}
