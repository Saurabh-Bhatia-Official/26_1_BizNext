// lib/features/auth/screens/register_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/notification_overlay.dart';
import '../providers/auth_provider.dart';
import 'package:confetti/confetti.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isLoading = false;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    final ok = await ref.read(authProvider.notifier).register(
      username: username,
      password: password,
      fullName: _fullNameCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
    );

    if (mounted) setState(() => _isLoading = false);

    if (ok && mounted) {
      _confettiController.play();
      AppAlert.success(ref, 'Account created successfully! Welcome!');
      
      await Future.delayed(const Duration(seconds: 3));
      
      if (mounted) {
        await ref.read(authProvider.notifier).login(username, password);
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } else if (!ok && mounted) {
      final err = ref.read(authProvider).error;
      AppAlert.error(ref, err ?? 'Registration failed');
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
          Positioned(top: -100, left: -100, child: _GlowOrb(color: AppColors.primary, size: 400)),
          Positioned(bottom: -150, right: -100, child: _GlowOrb(color: AppColors.accent, size: 500)),
          
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
                      _RegisterCard(
                        formKey: _formKey,
                        fullNameCtrl: _fullNameCtrl,
                        usernameCtrl: _usernameCtrl,
                        passwordCtrl: _passwordCtrl,
                        emailCtrl: _emailCtrl,
                        phoneCtrl: _phoneCtrl,
                        isLoading: _isLoading,
                        obscurePassword: _obscurePassword,
                        onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                        onRegister: _register,
                      ),
                    ],
                  )
                : _RegisterCard(
                    formKey: _formKey,
                    fullNameCtrl: _fullNameCtrl,
                    usernameCtrl: _usernameCtrl,
                    passwordCtrl: _passwordCtrl,
                    emailCtrl: _emailCtrl,
                    phoneCtrl: _phoneCtrl,
                    isLoading: _isLoading,
                    obscurePassword: _obscurePassword,
                    onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                    onRegister: _register,
                  ),
            ),
          ),
          
          // Back Button
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const NotificationOverlay(),
          
          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameCtrl;
  final TextEditingController usernameCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final bool isLoading;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onRegister;

  const _RegisterCard({
    required this.formKey,
    required this.fullNameCtrl,
    required this.usernameCtrl,
    required this.passwordCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.isLoading,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;

    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
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
            const Text('Create Account', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const Text('Join the premium business ecosystem', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
            const SizedBox(height: 32),
            _AuthField(
              controller: fullNameCtrl,
              label: 'Full Name',
              icon: Icons.person_outline_rounded,
              hint: 'John Doe',
              validator: (v) => v?.isEmpty == true ? 'Full name required' : null,
            ),
            const SizedBox(height: 20),
             isWide
                ? Row(
                    children: [
                      Expanded(
                        child: _AuthField(
                          controller: usernameCtrl,
                          label: 'Username',
                          icon: Icons.alternate_email_rounded,
                          hint: 'johndoe',
                          validator: (v) => v?.isEmpty == true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _AuthField(
                          controller: passwordCtrl,
                          label: 'Password',
                          icon: Icons.lock_outline_rounded,
                          hint: '••••••••',
                          isPassword: true,
                          obscure: obscurePassword,
                          onToggle: onTogglePassword,
                          validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 chars' : null,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _AuthField(
                        controller: usernameCtrl,
                        label: 'Username',
                        icon: Icons.alternate_email_rounded,
                        hint: 'johndoe',
                        validator: (v) => v?.isEmpty == true ? 'Required' : null,
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
                        validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 chars' : null,
                      ),
                    ],
                  ),
            const SizedBox(height: 20),
            _AuthField(
              controller: emailCtrl,
              label: 'Email Address (Optional)',
              icon: Icons.email_outlined,
              hint: 'john@example.com',
            ),
            const SizedBox(height: 20),
            _AuthField(
              controller: phoneCtrl,
              label: 'Phone Number (Optional)',
              icon: Icons.phone_outlined,
              hint: '+1...',
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: isLoading ? null : onRegister,
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
                        Text('Get Started', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        SizedBox(width: 12),
                        Icon(Icons.rocket_launch_rounded, size: 20),
                      ],
                    ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Already have an account? ', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Sign In', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ],
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
          'Start Your Business\nJourney Today',
          style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -1),
        ),
        const SizedBox(height: 20),
        const Text(
          'Create your unified account to manage inventory, POS, and finances across all your businesses.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 18, height: 1.6),
        ),
        const SizedBox(height: 48),
        _FeatureRow(icon: Icons.check_circle_rounded, text: 'Unlimited business profiles'),
        _FeatureRow(icon: Icons.check_circle_rounded, text: 'Secure local-first database'),
        _FeatureRow(icon: Icons.check_circle_rounded, text: 'Professional PDF invoicing'),
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

  const _AuthField({required this.controller, required this.label, required this.hint, required this.icon, this.isPassword = false, this.obscure = false, this.onToggle, this.validator});

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
