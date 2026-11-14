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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        leading: IconButton(
          tooltip: 'Back to Workspaces',
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              size: 20,
            ),
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.initialBusiness == null
                  ? (isPhone ? 'Register Workspace' : 'Register Business Workspace')
                  : (isPhone ? 'Configure Business' : 'Configure Business Profile'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
                fontSize: isPhone ? 16 : 18,
                letterSpacing: -0.5,
              ),
            ),
            if (!isPhone)
              Text(
                widget.initialBusiness == null
                    ? 'Enter organization details, contact information, and tax parameters'
                    : 'Update organization details and operational parameters',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
            height: 1,
          ),
        ),
        actions: [
          SizedBox(width: isPhone ? 8 : 16),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: isPhone ? 14 : 24, vertical: isPhone ? 16 : 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FormContainer(
                    title: 'Business Identity & Organization',
                    isDark: isDark,
                    isPhone: isPhone,
                    children: [
                      _AuthInput(
                        controller: _nameCtrl,
                        label: 'Official Business Name',
                        icon: Icons.storefront_rounded,
                        hint: 'e.g. Company Name',
                        isDark: isDark,
                        isPhone: isPhone,
                        validator: (v) => v?.isEmpty == true ? 'Business name is required' : null,
                      ),
                      SizedBox(height: isPhone ? 14 : 20),
                      _TypeSelector(
                        selected: _selectedType,
                        isDark: isDark,
                        onChanged: (v) => setState(() => _selectedType = v!),
                      ),
                    ],
                  ),
                  SizedBox(height: isPhone ? 16 : 24),
                  _FormContainer(
                    title: 'Official Contact & Communication',
                    isDark: isDark,
                    isPhone: isPhone,
                    children: [
                      _AuthInput(
                        controller: _phoneCtrl,
                        label: 'Primary Phone Number',
                        icon: Icons.phone_rounded,
                        hint: 'e.g. +91 98765 43210',
                        isDark: isDark,
                        isPhone: isPhone,
                      ),
                      SizedBox(height: isPhone ? 14 : 20),
                      _AuthInput(
                        controller: _emailCtrl,
                        label: 'Official Email Address',
                        icon: Icons.email_rounded,
                        hint: 'e.g. billing@company.com',
                        isDark: isDark,
                        isPhone: isPhone,
                      ),
                      SizedBox(height: isPhone ? 14 : 20),
                      _AuthInput(
                        controller: _addressCtrl,
                        label: 'Registered Operational Address',
                        icon: Icons.location_on_rounded,
                        hint: 'Street, City, State, PIN code...',
                        maxLines: 2,
                        isDark: isDark,
                        isPhone: isPhone,
                      ),
                    ],
                  ),
                  SizedBox(height: isPhone ? 16 : 24),
                  _FormContainer(
                    title: 'Legal & Tax Registration (GSTIN / PAN)',
                    isDark: isDark,
                    isPhone: isPhone,
                    children: [
                      _AuthInput(
                        controller: _gstCtrl,
                        label: 'GST Identification Number (GSTIN)',
                        icon: Icons.receipt_long_rounded,
                        hint: 'e.g. 27AAAAA0000A1Z5 (Optional)',
                        isDark: isDark,
                        isPhone: isPhone,
                      ),
                    ],
                  ),
                  SizedBox(height: isPhone ? 24 : 40),
                  SizedBox(
                    width: double.infinity,
                    height: isPhone ? 50 : 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: AppColors.primary.withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  isPhone ? 'Saving...' : 'Saving Workspace Details...',
                                  style: TextStyle(fontSize: isPhone ? 14 : 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.initialBusiness == null ? Icons.add_business_rounded : Icons.check_circle_outline_rounded,
                                  size: isPhone ? 18 : 20,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    isPhone
                                        ? (widget.initialBusiness == null ? 'Register Workspace' : 'Save Changes')
                                        : (widget.initialBusiness == null ? 'Complete Workspace Registration' : 'Save Business Profile Changes'),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(fontSize: isPhone ? 14 : 16, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormContainer extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isDark;
  final bool isPhone;

  const _FormContainer({
    required this.title,
    required this.children,
    required this.isDark,
    this.isPhone = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isPhone ? 16 : 26),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E).withValues(alpha: 0.8) : Colors.white,
        borderRadius: BorderRadius.circular(isPhone ? 18 : 24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: isPhone ? 14 : 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: isPhone ? 14 : 20),
          ...children,
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }
}

class _AuthInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final bool isDark;
  final bool isPhone;
  final String? Function(String?)? validator;

  const _AuthInput({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.isDark,
    this.isPhone = false,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? AppColors.textMuted : const Color(0xFF475569),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: maxLines > 1 ? TextInputType.multiline : TextInputType.text,
          textInputAction: maxLines > 1 ? null : TextInputAction.next,
          validator: validator,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF94A3B8),
              fontSize: 14,
            ),
            prefixIcon: Icon(icon, color: AppColors.primary.withValues(alpha: 0.8), size: 20),
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
            contentPadding: EdgeInsets.symmetric(horizontal: isPhone ? 14 : 16, vertical: isPhone ? 12 : 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFCBD5E1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeSelector extends StatelessWidget {
  final String selected;
  final bool isDark;
  final ValueChanged<String?> onChanged;

  const _TypeSelector({
    required this.selected,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Business Category / Classification',
          style: TextStyle(
            color: isDark ? AppColors.textMuted : const Color(0xFF475569),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        AppSearchableDropdown<String>(
          value: selected,
          labelText: 'Business Type',
          isDark: isDark,
          items: AppConstants.businessTypes.map((t) => SearchableDropdownItem(value: t, label: t)).toList(),
          onChanged: onChanged,
          prefixIcon: Icons.category_rounded,
        ),
      ],
    );
  }
}
