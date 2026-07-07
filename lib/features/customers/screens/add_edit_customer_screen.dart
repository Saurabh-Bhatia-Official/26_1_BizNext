// lib/features/customers/screens/add_edit_customer_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/customer_model.dart';
import '../providers/customer_provider.dart';

class AddEditCustomerScreen extends ConsumerStatefulWidget {
  final CustomerModel? customer;
  const AddEditCustomerScreen({super.key, this.customer});

  @override
  ConsumerState<AddEditCustomerScreen> createState() => _AddEditCustomerScreenState();
}

class _AddEditCustomerScreenState extends ConsumerState<AddEditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _gstCtrl;
  late final TextEditingController _balanceCtrl;

  bool get isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _addressCtrl = TextEditingController(text: c?.address ?? '');
    _gstCtrl = TextEditingController(text: c?.gstNumber ?? '');
    _balanceCtrl = TextEditingController(text: c?.balance.toString() ?? '0');
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
    final formState = ref.watch(customerFormProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Customer' : 'New Customer'),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _CustomerFormCard(
                title: 'Contact Information',
                isDark: isDark,
                children: [
                  _CustomerField(
                    controller: _nameCtrl,
                    label: 'Customer Name',
                    hint: 'e.g. John Doe',
                    icon: Icons.person_rounded,
                    validator: (v) => v?.isEmpty == true ? 'Name required' : null,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _CustomerField(
                          controller: _phoneCtrl,
                          label: 'Phone Number',
                          hint: '+91...',
                          icon: Icons.phone_rounded,
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _CustomerField(
                          controller: _emailCtrl,
                          label: 'Email',
                          hint: 'john@example.com',
                          icon: Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _CustomerFormCard(
                title: 'Address & Business',
                isDark: isDark,
                children: [
                  _CustomerField(
                    controller: _addressCtrl,
                    label: 'Address',
                    hint: 'Full street address...',
                    icon: Icons.location_on_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  _CustomerField(
                    controller: _gstCtrl,
                    label: 'GST Number',
                    hint: 'Optional GSTIN',
                    icon: Icons.receipt_long_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _CustomerFormCard(
                title: 'Financial Balance',
                isDark: isDark,
                children: [
                  _CustomerField(
                    controller: _balanceCtrl,
                    label: 'Opening Balance',
                    hint: '0.00',
                    icon: Icons.account_balance_wallet_rounded,
                    keyboardType: TextInputType.number,
                    helperText: 'Positive for receivable, Negative for payable',
                  ),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: formState.isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: formState.isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(isEditing ? 'Update Customer' : 'Create Customer', style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ).animate().slideY(begin: 0.2, end: 0),
            ],
          ),
        ),
      ),
    );
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    final businessId = ref.read(activeBusinessIdProvider);
    final customer = CustomerModel(
      id: widget.customer?.id,
      businessId: businessId,
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      gstNumber: _gstCtrl.text.trim(),
      balance: double.tryParse(_balanceCtrl.text) ?? 0,
    );

    final success = await ref.read(customerFormProvider.notifier).saveCustomer(customer);
    if (success && mounted) Navigator.pop(context);
  }
}

class _CustomerFormCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isDark;

  const _CustomerFormCard({required this.title, required this.children, required this.isDark});

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
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
  }
}

class _CustomerField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final TextInputType keyboardType;
  final String? helperText;
  final String? Function(String?)? validator;

  const _CustomerField({required this.controller, required this.label, required this.hint, required this.icon, this.maxLines = 1, this.keyboardType = TextInputType.text, this.helperText, this.validator});

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
