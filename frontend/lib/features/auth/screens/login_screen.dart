// lib/features/auth/screens/login_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/notification_overlay.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _isCapsLockOn = false;
  File? _detectedBackup;

  @override
  void initState() {
    super.initState();
    _checkForBackup();
    _loadSavedPreferences();
    _initCapsLockListener();
  }

  void _initCapsLockListener() {
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _checkCapsLock();
  }

  bool _handleKeyEvent(KeyEvent event) {
    _checkCapsLock();
    return false;
  }

  void _checkCapsLock() {
    final capsOn = HardwareKeyboard.instance.lockModesEnabled.contains(KeyboardLockMode.capsLock);
    if (capsOn != _isCapsLockOn && mounted) {
      setState(() => _isCapsLockOn = capsOn);
    }
  }

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(AppConstants.prefRememberMe) ?? false;
    final savedUser = prefs.getString(AppConstants.prefSavedUsername);
    if (remember && savedUser != null && savedUser.isNotEmpty && mounted) {
      setState(() {
        _rememberMe = true;
        _usernameCtrl.text = savedUser;
      });
    }
  }

  Future<void> _checkForBackup() async {
    final file = await BackupService.findAvailableBackup();
    if (mounted) setState(() => _detectedBackup = file);
  }

  Future<void> _importData() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E34) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.settings_backup_restore_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              'Import Database Backup',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          'Select an encrypted backup file (.bzcfg or .db). This will securely restore your business accounts, inventory, and transaction records.',
          style: TextStyle(
            height: 1.5,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Select File & Restore'),
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E34) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Text('Factory Reset Software?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'This action will permanently delete ALL local software data, accounts, inventory, and settings. This operation is irreversible.',
          style: TextStyle(
            height: 1.5,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Permanently Reset Everything'),
          ),
        ],
      ),
    );

    if (ok == true) {
      setState(() => _isLoading = true);
      try {
        await DatabaseHelper.instance.resetSoftware();
        if (mounted) {
          AppAlert.success(ref, 'Software reset successfully. Restarting workspace...');
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

  Future<void> _cleanSampleData() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E34) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.cleaning_services_rounded, color: AppColors.accent),
            const SizedBox(width: 10),
            Text(
              'Clean Sample Data',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          'This will safely purge demo transactions, test sales, and sample purchases while preserving your Chart of Accounts, business profile, and category configurations.',
          style: TextStyle(
            height: 1.5,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Purge Sample Data'),
          ),
        ],
      ),
    );

    if (ok == true) {
      setState(() => _isLoading = true);
      try {
        await DatabaseHelper.instance.cleanSampleData(1);
        if (mounted) {
          AppAlert.success(ref, 'Sample transactions purged cleanly.');
        }
      } catch (e) {
        if (mounted) AppAlert.error(ref, 'Clean failed: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showMaintenanceModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E34) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.build_circle_outlined, color: AppColors.primary, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Data Backup & Maintenance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Backup, restore, and maintenance utilities for your business database.',
                  style: TextStyle(
                    color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.settings_backup_restore_rounded, color: AppColors.primary),
                  ),
                  title: Text(
                    'Import / Restore Database',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Load an existing .bzcfg or .db backup file',
                    style: TextStyle(
                      color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white54 : Colors.black45),
                  onTap: () {
                    Navigator.pop(ctx);
                    _importData();
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.cleaning_services_rounded, color: AppColors.accent),
                  ),
                  title: Text(
                    'Purge Sample / Demo Data',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Clean sample transactions while keeping accounts and inventory structure',
                    style: TextStyle(
                      color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white54 : Colors.black45),
                  onTap: () {
                    Navigator.pop(ctx);
                    _cleanSampleData();
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                  ),
                  title: const Text('Emergency Factory Reset', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'Permanently wipe all workspace data and start fresh',
                    style: TextStyle(
                      color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white54 : Colors.black45),
                  onTap: () {
                    Navigator.pop(ctx);
                    _resetSoftware();
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFirstTimeHelp() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E34) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.help_outline_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              'First-Time Admin Setup',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BizNext initializes with a secure owner account for first installation:',
              style: TextStyle(
                color: isDark ? AppColors.textMuted : const Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Text(
                'The account created during initial setup is your Primary Admin account with full system permissions.\n\nAdditional staff accounts can be created and managed anytime from Settings > Login Credentials.',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final ok = await ref.read(authProvider.notifier).login(
      _usernameCtrl.text.trim(),
      _passwordCtrl.text,
      rememberMe: _rememberMe,
    );

    if (mounted) setState(() => _isLoading = false);

    if (!ok && mounted) {
      final err = ref.read(authProvider).error;
      AppAlert.error(ref, err ?? 'Invalid username or password.');
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C17) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // ── Ambient Glow Elements ──
          Positioned(
            top: -120,
            right: -100,
            child: _GlowOrb(
              color: AppColors.primary,
              size: 450,
              opacity: isDark ? 0.14 : 0.08,
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: _GlowOrb(
              color: AppColors.accent,
              size: 550,
              opacity: isDark ? 0.14 : 0.07,
            ),
          ),

          // ── Back Button (if navigated to) ──
          if (Navigator.canPop(context))
            Positioned(
              top: 16,
              left: 16,
              child: SafeArea(
                child: Material(
                  color: Colors.transparent,
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      size: 28,
                    ),
                    onPressed: () => Navigator.maybePop(context),
                    tooltip: 'Back',
                  ),
                ),
              ),
            ),

          // ── Main Content ──
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: isWide ? 40 : 16, vertical: 32),
              child: isWide
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: _EnterpriseHeroSection(isDark: isDark)),
                        const SizedBox(width: 80),
                        _LoginCard(
                          formKey: _formKey,
                          usernameCtrl: _usernameCtrl,
                          passwordCtrl: _passwordCtrl,
                          passwordFocusNode: _passwordFocusNode,
                          isLoading: _isLoading,
                          obscurePassword: _obscurePassword,
                          rememberMe: _rememberMe,
                          isCapsLockOn: _isCapsLockOn,
                          isDark: isDark,
                          errorMessage: authState.error,
                          detectedBackup: _detectedBackup,
                          onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                          onToggleRememberMe: (val) => setState(() => _rememberMe = val ?? false),
                          onLogin: _login,
                          onOpenMaintenance: _showMaintenanceModal,
                          onOpenHelp: _showFirstTimeHelp,
                          onRestoreDetectedBackup: _importData,
                        ),
                      ],
                    )
                  : _LoginCard(
                      formKey: _formKey,
                      usernameCtrl: _usernameCtrl,
                      passwordCtrl: _passwordCtrl,
                      passwordFocusNode: _passwordFocusNode,
                      isLoading: _isLoading,
                      obscurePassword: _obscurePassword,
                      rememberMe: _rememberMe,
                      isCapsLockOn: _isCapsLockOn,
                      isDark: isDark,
                      errorMessage: authState.error,
                      detectedBackup: _detectedBackup,
                      onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                      onToggleRememberMe: (val) => setState(() => _rememberMe = val ?? false),
                      onLogin: _login,
                      onOpenMaintenance: _showMaintenanceModal,
                      onOpenHelp: _showFirstTimeHelp,
                      onRestoreDetectedBackup: _importData,
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
    required this.passwordFocusNode,
    required this.isLoading,
    required this.obscurePassword,
    required this.rememberMe,
    required this.isCapsLockOn,
    required this.isDark,
    this.errorMessage,
    this.detectedBackup,
    required this.onTogglePassword,
    required this.onToggleRememberMe,
    required this.onLogin,
    required this.onOpenMaintenance,
    required this.onOpenHelp,
    required this.onRestoreDetectedBackup,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController usernameCtrl;
  final TextEditingController passwordCtrl;
  final FocusNode passwordFocusNode;
  final bool isLoading;
  final bool obscurePassword;
  final bool rememberMe;
  final bool isCapsLockOn;
  final bool isDark;
  final String? errorMessage;
  final File? detectedBackup;
  final VoidCallback onTogglePassword;
  final ValueChanged<bool?> onToggleRememberMe;
  final VoidCallback onLogin;
  final VoidCallback onOpenMaintenance;
  final VoidCallback onOpenHelp;
  final VoidCallback onRestoreDetectedBackup;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;

    return Container(
      constraints: const BoxConstraints(maxWidth: 450),
      padding: EdgeInsets.symmetric(horizontal: isWide ? 40 : 24, vertical: isWide ? 40 : 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF17172B).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.06),
            blurRadius: isDark ? 40 : 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Brand Header ──
            Center(
              child: Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                ),
              ).animate().scale(curve: Curves.easeOutBack, duration: 600.ms),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Welcome to BizNext',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Sign in to manage your shop, billing & accounts',
                style: TextStyle(
                  color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Auto-Detected Backup Pill ──
            if (detectedBackup != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.settings_backup_restore_rounded, color: AppColors.accent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Database backup detected.',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onRestoreDetectedBackup,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Restore', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],

            // ── Inline Error Message ──
            if (errorMessage != null && errorMessage!.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.error,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().shake(duration: 400.ms),
            ],

            // ── Username / Email Field ──
            _ModernAuthField(
              controller: usernameCtrl,
              label: 'Username or Work Email',
              hint: 'Enter your username or email',
              icon: Icons.alternate_email_rounded,
              isDark: isDark,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => FocusScope.of(context).requestFocus(passwordFocusNode),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter your username';
                return null;
              },
            ),
            const SizedBox(height: 18),

            // ── Password Field with CapsLock Detection ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Password',
                      style: TextStyle(
                        color: isDark ? AppColors.textMuted : const Color(0xFF475569),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (isCapsLockOn)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.keyboard_capslock_rounded, size: 12, color: Colors.amber),
                            SizedBox(width: 4),
                            Text(
                              'Caps Lock ON',
                              style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 200.ms),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: passwordCtrl,
                  focusNode: passwordFocusNode,
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter your password';
                    return null;
                  },
                  onFieldSubmitted: (_) => onLogin(),
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.primary.withValues(alpha: 0.7), size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 20,
                        color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                      ),
                      onPressed: onTogglePassword,
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Remember Me & Help ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: rememberMe,
                        onChanged: onToggleRememberMe,
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => onToggleRememberMe(!rememberMe),
                      child: Text(
                        'Remember me',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: onOpenHelp,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Setup Guidance', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Sign In Button ──
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                  shadowColor: AppColors.primary.withValues(alpha: 0.4),
                ),
                child: isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                          SizedBox(width: 14),
                          Text('Authenticating securely...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Sign In to Your Business', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          SizedBox(width: 10),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Register Account Link ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'New business? ',
                  style: TextStyle(
                    color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                    );
                  },
                  child: const Text('Create Account', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            const SizedBox(height: 8),

            // ── Maintenance & Recovery Footer Link ──
            Center(
              child: TextButton.icon(
                onPressed: onOpenMaintenance,
                icon: Icon(
                  Icons.build_circle_outlined,
                  size: 16,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
                label: Text(
                  'Data Backup & Maintenance',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.08, end: 0);
  }
}

class _EnterpriseHeroSection extends StatelessWidget {
  final bool isDark;
  const _EnterpriseHeroSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.2)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('✦', style: TextStyle(color: AppColors.primary, fontSize: 12)),
              SizedBox(width: 6),
              Text(
                'ALL-IN-ONE BUSINESS & BILLING SOFTWARE',
                style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Simple Billing,\nStock & Accounts',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 46,
            fontWeight: FontWeight.w900,
            height: 1.1,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Fast barcode billing, live stock tracking, customer credit (Khata), and profit reports designed for everyday business owners.',
          style: TextStyle(
            color: isDark ? AppColors.textMuted : const Color(0xFF475569),
            fontSize: 17,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 36),

        // Live Status Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success),
              ),
              const SizedBox(width: 10),
              Text(
                '100% Offline Ready • Safe Local Data • Fast & Easy to Use',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 36),
        _FeatureHighlight(
          icon: Icons.receipt_long_rounded,
          title: 'Super-Fast POS & GST Invoicing',
          description: 'Scan barcodes, add items in seconds, apply quick discounts, and print bills on any thermal or regular printer.',
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        _FeatureHighlight(
          icon: Icons.inventory_2_outlined,
          title: 'Live Stock & Low-Stock Alerts',
          description: 'Always know what is on your shelves, receive low-stock alerts, and track purchase rates with ease.',
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        _FeatureHighlight(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Customer Khata (Udhar) & Profit Reports',
          description: 'Track customer balances, record payments received, and check your daily sales and net profit at a glance.',
          isDark: isDark,
        ),
      ],
    ).animate().fadeIn(duration: 700.ms);
  }
}

class _FeatureHighlight extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isDark;

  const _FeatureHighlight({
    required this.icon,
    required this.title,
    required this.description,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModernAuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isDark;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;

  const _ModernAuthField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.isDark,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
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
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          textInputAction: textInputAction,
          validator: validator,
          onFieldSubmitted: onSubmitted,
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
            prefixIcon: Icon(icon, color: AppColors.primary.withValues(alpha: 0.7), size: 20),
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFCBD5E1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _GlowOrb({
    required this.color,
    required this.size,
    this.opacity = 0.14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: opacity), Colors.transparent],
        ),
      ),
    );
  }
}
