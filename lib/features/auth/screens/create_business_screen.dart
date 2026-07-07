// lib/features/auth/screens/create_business_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../models/business_model.dart';
import '../providers/auth_provider.dart';
import '../../../core/widgets/searchable_dropdown.dart';

class CreateBusinessScreen extends ConsumerStatefulWidget {
  final BusinessModel? initialBusiness;
  const CreateBusinessScreen({super.key, this.initialBusiness});

  @override
  ConsumerState<CreateBusinessScreen> createState() => _CreateBusinessScreenState();
}

class _CreateBusinessScreenState extends ConsumerState<CreateBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();

  String _selectedType = AppConstants.businessTypes.first;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialBusiness != null) {
      _nameCtrl.text = widget.initialBusiness!.name;
      _addressCtrl.text = widget.initialBusiness!.address ?? '';
      _phoneCtrl.text = widget.initialBusiness!.phone ?? '';
      _emailCtrl.text = widget.initialBusiness!.email ?? '';
      _gstCtrl.text = widget.initialBusiness!.gstNumber ?? '';
      _selectedType = widget.initialBusiness!.type;
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _addressCtrl, _phoneCtrl, _emailCtrl, _gstCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final biz = BusinessModel(
      id: widget.initialBusiness?.id,
      ownerId: widget.initialBusiness?.ownerId,
      name: _nameCtrl.text.trim(),
      type: _selectedType,
      address: _addressCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      gstNumber: _gstCtrl.text.trim(),
    );

    bool success;
    if (widget.initialBusiness == null) {
      success = await ref.read(authProvider.notifier).createNewBusiness(biz);
    } else {
      success = await ref.read(authProvider.notifier).updateBusiness(biz);
    }

    if (mounted) setState(() => _isLoading = false);
    if (success && mounted) {
      ref.invalidate(userBusinessesProvider);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: Text(widget.initialBusiness == null ? 'New Business' : 'Edit Business'),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _FormContainer(
                title: 'Business Identity',
                children: [
                  _AuthInput(
                    controller: _nameCtrl,
                    label: 'Business Name',
                    icon: Icons.storefront_rounded,
                    hint: 'e.g. Apex Solutions',
                    validator: (v) => v?.isEmpty == true ? 'Name required' : null,
                  ),
                  const SizedBox(height: 20),
                  _TypeSelector(
                    selected: _selectedType,
                    onChanged: (v) => setState(() => _selectedType = v!),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _FormContainer(
                title: 'Contact Details',
                children: [
                  _AuthInput(controller: _phoneCtrl, label: 'Phone Number', icon: Icons.phone_rounded, hint: '+91...'),
                  const SizedBox(height: 20),
                  _AuthInput(controller: _emailCtrl, label: 'Email Address', icon: Icons.email_rounded, hint: 'hello@business.com'),
                  const SizedBox(height: 20),
                  _AuthInput(controller: _addressCtrl, label: 'Full Address', icon: Icons.location_on_rounded, hint: 'City, State...', maxLines: 2),
                ],
              ),
              const SizedBox(height: 24),
              _FormContainer(
                title: 'Legal Info',
                children: [
                  _AuthInput(controller: _gstCtrl, label: 'GST Number', icon: Icons.receipt_long_rounded, hint: 'Optional'),
                ],
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(widget.initialBusiness == null ? 'Register Business' : 'Update Business', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormContainer extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _FormContainer({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
  }
}

class _AuthInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;

  const _AuthInput({required this.controller, required this.label, required this.hint, required this.icon, this.maxLines = 1, this.validator});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            fillColor: Colors.white.withValues(alpha: 0.04),
          ),
        ),
      ],
    );
  }
}

class _TypeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String?> onChanged;
  const _TypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Business Type', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        AppSearchableDropdown<String>(
          value: selected,
          labelText: 'Business Type',
          isDark: true, // This screen has a fixed dark background
          items: AppConstants.businessTypes.map((t) => SearchableDropdownItem(value: t, label: t)).toList(),
          onChanged: onChanged,
          prefixIcon: Icons.category_rounded,
        ),
      ],
    );
  }
}
