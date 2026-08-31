// lib/features/suppliers/screens/add_edit_supplier_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/supplier_model.dart';
import '../providers/supplier_provider.dart';
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
  late final TextEditingController _companyCtrl;
  late final TextEditingController _contactPersonCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _gstCtrl;
  late final TextEditingController _panCtrl;
  late final TextEditingController _paymentTermsCtrl;
  late final TextEditingController _creditLimitCtrl;
  late final TextEditingController _openingBalanceCtrl;
  late final TextEditingController _bankDetailsCtrl;
  late final TextEditingController _notesCtrl;

  bool get isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _companyCtrl = TextEditingController(text: s?.companyName ?? '');
    _contactPersonCtrl = TextEditingController(text: s?.contactPerson ?? '');
    _phoneCtrl = TextEditingController(text: s?.phone ?? '');
    _emailCtrl = TextEditingController(text: s?.email ?? '');
    _addressCtrl = TextEditingController(text: s?.address ?? '');
    _stateCtrl = TextEditingController(text: s?.state ?? '');
    _gstCtrl = TextEditingController(text: s?.gstNumber ?? '');
    _panCtrl = TextEditingController(text: s?.pan ?? '');
    _paymentTermsCtrl = TextEditingController(text: s?.paymentTerms ?? 'Net 30');
    _creditLimitCtrl = TextEditingController(text: s != null && s.creditLimit > 0 ? s.creditLimit.toString() : '');
    _openingBalanceCtrl = TextEditingController(text: s != null ? s.openingBalance.toString() : '0');
    _bankDetailsCtrl = TextEditingController(text: s?.bankDetails ?? '');
    _notesCtrl = TextEditingController(text: s?.notes ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _companyCtrl, _contactPersonCtrl, _phoneCtrl, _emailCtrl,
      _addressCtrl, _stateCtrl, _gstCtrl, _panCtrl, _paymentTermsCtrl,
      _creditLimitCtrl, _openingBalanceCtrl, _bankDetailsCtrl, _notesCtrl
    ]) {
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
          title: Text(isEditing ? 'Edit Supplier' : 'Register New Supplier'),
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
                  title: 'Supplier & Business Profile',
                  isDark: isDark,
                  children: [
                    _SupplierField(
                      controller: _nameCtrl,
                      label: 'Supplier Display Name *',
                      hint: 'e.g. ABC Wholesalers Ltd',
                      icon: Icons.business_rounded,
                      validator: (v) => v?.trim().isEmpty == true ? 'Supplier name is required' : null,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _SupplierField(
                            controller: _companyCtrl,
                            label: 'Company Legal Name',
                            hint: 'Official registered entity name',
                            icon: Icons.domain_rounded,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _SupplierField(
                            controller: _contactPersonCtrl,
                            label: 'Contact Person / Rep',
                            hint: 'Key account manager name',
                            icon: Icons.person_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _SupplierField(
                            controller: _phoneCtrl,
                            label: 'Phone / Mobile',
                            hint: '+91...',
                            icon: Icons.phone_rounded,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _SupplierField(
                            controller: _emailCtrl,
                            label: 'Email Address',
                            hint: 'orders@supplier.com',
                            icon: Icons.email_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                _FormCard(
                  title: 'Tax Compliance & Credit Terms',
                  isDark: isDark,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SupplierField(
                            controller: _gstCtrl,
                            label: 'GSTIN / Tax ID',
                            hint: '15-digit GST Number',
                            icon: Icons.tag_rounded,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _SupplierField(
                            controller: _panCtrl,
                            label: 'PAN Card Number',
                            hint: 'Permanent Account Number',
                            icon: Icons.badge_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _SupplierField(
                            controller: _paymentTermsCtrl,
                            label: 'Payment Terms',
                            hint: 'e.g. Net 30, Due on Receipt',
                            icon: Icons.schedule_rounded,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _SupplierField(
                            controller: _creditLimitCtrl,
                            label: 'Credit Limit ₹',
                            hint: '0.00',
                            icon: Icons.credit_card_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SupplierField(
                      controller: _openingBalanceCtrl,
                      label: 'Opening Balance (Payable) ₹',
                      hint: '0.00',
                      icon: Icons.account_balance_wallet_rounded,
                      keyboardType: TextInputType.number,
                      helperText: 'Initial outstanding owed to this supplier upon setup',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                _FormCard(
                  title: 'Location & Banking Details',
                  isDark: isDark,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _SupplierField(
                            controller: _addressCtrl,
                            label: 'Billing / Dispatch Address',
                            hint: 'Full physical address...',
                            icon: Icons.location_on_rounded,
                            maxLines: 2,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _SupplierField(
                            controller: _stateCtrl,
                            label: 'State / Region',
                            hint: 'e.g. Maharashtra',
                            icon: Icons.map_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SupplierField(
                      controller: _bankDetailsCtrl,
                      label: 'Bank Account & NEFT Details',
                      hint: 'Bank Name, Account #, IFSC, Branch...',
                      icon: Icons.account_balance_rounded,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    _SupplierField(
                      controller: _notesCtrl,
                      label: 'Internal Notes',
                      hint: 'Special discounts, delivery preferences, contract remarks...',
                      icon: Icons.note_alt_rounded,
                      maxLines: 2,
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  child: AppShortcut(
                    actionId: 'save',
                    onPressed: _save,
                    child: ElevatedButton(
                      onPressed: formState.isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: formState.isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(saveBtnText, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final businessId = ref.read(activeBusinessIdProvider);
    final supplier = SupplierModel(
      id: widget.supplier?.id,
      businessId: businessId,
      name: _nameCtrl.text.trim(),
      companyName: _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim(),
      contactPerson: _contactPersonCtrl.text.trim().isEmpty ? null : _contactPersonCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      state: _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
      gstNumber: _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim(),
      pan: _panCtrl.text.trim().isEmpty ? null : _panCtrl.text.trim(),
      paymentTerms: _paymentTermsCtrl.text.trim().isEmpty ? null : _paymentTermsCtrl.text.trim(),
      creditLimit: double.tryParse(_creditLimitCtrl.text) ?? 0,
      openingBalance: double.tryParse(_openingBalanceCtrl.text) ?? 0,
      balance: widget.supplier?.balance ?? (double.tryParse(_openingBalanceCtrl.text) ?? 0),
      bankDetails: _bankDetailsCtrl.text.trim().isEmpty ? null : _bankDetailsCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      isActive: widget.supplier?.isActive ?? true,
    );

    final success = await ref.read(supplierFormProvider.notifier).saveSupplier(supplier);
    if (success && mounted) {
      Navigator.pop(context);
    }
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
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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

class _SupplierField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final String? helperText;

  const _SupplierField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefixIcon: Icon(icon, size: 20, color: AppColors.primary.withValues(alpha: 0.7)),
        fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : AppColors.lightBg,
      ),
    );
  }
}
