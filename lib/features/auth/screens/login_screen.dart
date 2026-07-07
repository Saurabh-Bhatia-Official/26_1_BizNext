// lib/features/auth/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/notification_overlay.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/database/database_helper.dart';
import 'dart:io';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  File? _detectedBackup;
  
  @override
  void initState() {
    super.initState();
    _checkForBackup();
  }

  Future<void> _checkForBackup() async {
    final file = await BackupService.findAvailableBackup();
    if (mounted) setState(() => _detectedBackup = file);
  }

  Future<void> _importData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Database?'),
        content: const Text('You will be asked to select a backup file (.db). This will replace all current data. Would you like to proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Select File')),
        ],
      ),
    );

    if (ok == true) {
      setState(() => _isLoading = true);
      final result = await BackupService.importDatabase();
      if (mounted) {
        setState(() => _isLoading = false);
        if (result != null && result.contains('successfully')) {
          AppAlert.success(ref, result);
          await Future.delayed(const Duration(seconds: 2));
          await ref.read(authProvider.notifier).reinitialize();
        } else if (result != null) {
          AppAlert.error(ref, result);
        }
      }
    }
  }

  Future<void> _resetSoftware() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Software?'),
        content: const Text('This action will permanently delete ALL software data, including all accounts, business data, inventory, and reports. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );

    if (ok == true) {
      setState(() => _isLoading = true);
      try {
        await DatabaseHelper.instance.resetSoftware();
        if (mounted) {
          AppAlert.success(ref, 'Software reset successfully. Restarting...');
          await Future.delayed(const Duration(seconds: 2));
          await ref.read(authProvider.notifier).reinitialize();
        }
      } catch (e) {
        if (mounted) AppAlert.error(ref, 'Reset failed: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }



  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    final ok = await ref.read(authProvider.notifier).login(
      _usernameCtrl.text.trim(),
      _passwordCtrl.text,
    );

    if (mounted) setState(() => _isLoading = false);

    if (!ok && mounted) {
      final err = ref.read(authProvider).error;
      AppAlert.error(ref, err ?? 'Invalid credentials');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;

    return Scaffold(
      body: Stack(
        children: [
          // ── Background ──
          Container(color: const Color(0xFF0F0F1A)),
          
          // ── Glow Orbs ──
          Positioned(top: -100, right: -100, child: _GlowOrb(color: AppColors.primary, size: 400)),
          Positioned(bottom: -150, left: -100, child: _GlowOrb(color: AppColors.accent, size: 500)),
          
          // ── Main Content ──
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 12, vertical: 24),
              child: isWide 
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Expanded(child: _BrandingSection()),
                      const SizedBox(width: 80),
                      _LoginCard(
                        formKey: _formKey,
                        usernameCtrl: _usernameCtrl,
                        passwordCtrl: _passwordCtrl,
                        isLoading: _isLoading,
                        obscurePassword: _obscurePassword,
                        onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                        onLogin: _login,
                        detectedBackup: _detectedBackup,
                        onImport: _importData,
                        onResetSoftware: _resetSoftware,
                      ),
                    ],
                  )
                : _LoginCard(
                    formKey: _formKey,
                    usernameCtrl: _usernameCtrl,
                    passwordCtrl: _passwordCtrl,
                    isLoading: _isLoading,
                    obscurePassword: _obscurePassword,
                    onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                    onLogin: _login,
                    detectedBackup: _detectedBackup,
                    onImport: _importData,
                    onResetSoftware: _resetSoftware,
                  ),
            ),
          ),
          const NotificationOverlay(),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.usernameCtrl,
    required this.passwordCtrl,
    required this.isLoading,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onLogin,
    this.detectedBackup,
    required this.onImport,
    required this.onResetSoftware,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController usernameCtrl;
  final TextEditingController passwordCtrl;
  final bool isLoading;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;
  final File? detectedBackup;
  final VoidCallback onImport;
  final VoidCallback onResetSoftware;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;
    
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: EdgeInsets.symmetric(horizontal: isWide ? 40 : 20, vertical: isWide ? 40 : 32),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 40, offset: const Offset(0, 20)),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: const Center(
                  child: Text(
                    '💼',
                    style: TextStyle(fontSize: 36),
                  ),
                ),
              ).animate().scale(curve: Curves.elasticOut, duration: 600.ms),
            ),
            const SizedBox(height: 24),
            const Text('Welcome Back', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const Text('Enter your credentials to manage your business', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
            const SizedBox(height: 40),
            _AuthField(
              controller: usernameCtrl,
              label: 'Username',
              icon: Icons.alternate_email_rounded,
              hint: 'admin',
              validator: (v) => v?.isEmpty == true ? 'Username required' : null,
            ),
            const SizedBox(height: 20),
            _AuthField(
              controller: passwordCtrl,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              hint: '••••••••',
              isPassword: true,
              obscure: obscurePassword,
              onToggle: onTogglePassword,
              validator: (v) => v?.isEmpty == true ? 'Password required' : null,
              onSubmitted: (_) => onLogin(),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: isLoading ? null : onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 8,
                  shadowColor: AppColors.primary.withValues(alpha: 0.5),
                ),
                child: isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        SizedBox(width: 12),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Don\'t have an account? ', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                    );
                  },
                  child: const Text('Create Account', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : onResetSoftware,
                icon: const Icon(Icons.delete_forever_rounded, size: 18),
                label: const Text('Reset Software', style: TextStyle(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : onImport,
                icon: const Icon(Icons.settings_backup_restore_rounded, size: 18),
                label: const Text('Import Existing Data', style: TextStyle(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Default Credentials: admin / admin123',
                style: TextStyle(color: AppColors.accent.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }
}

class _BrandingSection extends StatelessWidget {
  const _BrandingSection();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
          child: const Text('✦ ENTERPRISE EDITION', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ),
        const SizedBox(height: 24),
        const Text(
          'Unified Business\nManagement Platform',
          style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -1),
        ),
        const SizedBox(height: 20),
        const Text(
          'Automate your inventory, streamline POS billing, and track financials with powerful real-time analytics.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 18, height: 1.6),
        ),
        const SizedBox(height: 48),
        _FeatureRow(icon: Icons.check_circle_rounded, text: 'Multi-business workspace support'),
        _FeatureRow(icon: Icons.check_circle_rounded, text: 'Real-time inventory alerts'),
        _FeatureRow(icon: Icons.check_circle_rounded, text: 'Advanced financial reporting'),
      ],
    ).animate().fadeIn(duration: 800.ms);
  }
}

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool obscure;
  final VoidCallback? onToggle;
  final String? Function(String?)? validator;
  final Function(String)? onSubmitted;

  const _AuthField({required this.controller, required this.label, required this.hint, required this.icon, this.isPassword = false, this.obscure = false, this.onToggle, this.validator, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          onFieldSubmitted: onSubmitted,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.primary.withValues(alpha: 0.7), size: 20),
            suffixIcon: isPassword ? IconButton(icon: Icon(obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 20, color: AppColors.textMuted), onPressed: onToggle) : null,
            fillColor: Colors.white.withValues(alpha: 0.04),
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.success, size: 22),
          const SizedBox(width: 16),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}



class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowOrb({required this.color, required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color.withValues(alpha: 0.12), Colors.transparent])),
    );
  }
}
