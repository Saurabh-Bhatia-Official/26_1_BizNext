// lib/features/settings/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/providers/notification_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/database/database_helper.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => ref.read(selectedNavIndexProvider.notifier).state = ref.read(previousNavIndexProvider),
                  icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : AppColors.textLight),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'My Profile',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textLight,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
                  icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: isDark ? Colors.amber : AppColors.primary),
                ),
              ],
            ),
            const Text('Manage your personal account information and security', 
                style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
            const SizedBox(height: 40),

            _ProfileSection(
              title: 'Personal Information',
              isDark: isDark,
              children: [
                _ProfileTile(
                  label: 'Full Name',
                  value: user?.fullName ?? 'Admin',
                  icon: Icons.person_rounded,
                  onTap: () => _showEditDialog(context, ref, 'Full Name', user?.fullName ?? '', (v) async {
                    if (user == null) return;
                    final success = await ref.read(authProvider.notifier).updateProfile(user.copyWith(fullName: v));
                    if (success) AppAlert.success(ref, 'Profile name updated');
                  }),
                ),
                _ProfileTile(
                  label: 'Email Address',
                  value: user?.email ?? 'Not set',
                  icon: Icons.email_rounded,
                  onTap: () => _showEditDialog(context, ref, 'Email', user?.email ?? '', (v) async {
                    if (user == null) return;
                    final success = await ref.read(authProvider.notifier).updateProfile(user.copyWith(email: v));
                    if (success) AppAlert.success(ref, 'Email updated successfully');
                  }),
                ),
                _ProfileTile(
                  label: 'Username',
                  value: user?.username ?? 'admin',
                  icon: Icons.alternate_email_rounded,
                  onTap: () {}, // Username usually read-only
                ),
              ],
            ),

            const SizedBox(height: 32),

            _ProfileSection(
              title: 'Security & Privacy',
              isDark: isDark,
              children: [
                _ProfileTile(
                  label: 'Reset Account Data',
                  value: 'Permanently delete all your business data',
                  icon: Icons.person_off_rounded,
                  color: AppColors.error,
                  onTap: () => _confirmAccountReset(context, ref),
                ),
                _ProfileTile(
                  label: 'Sign Out',
                  value: 'Logout from the application',
                  icon: Icons.logout_rounded,
                  color: AppColors.error,
                  onTap: () => _confirmLogout(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, String title, String current, Function(String) onSave) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $title'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: 'Enter new $title'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              onSave(ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmAccountReset(BuildContext context, WidgetRef ref) {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Reset Account Data?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('This action will permanently delete all business data, inventory, and transactions associated with your account (${user.username}). Your account itself will remain active, but you will be logged out to re-initialize your workspace.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final success = await DatabaseHelper.instance.resetAccountData(user.username);
                if (success && context.mounted) {
                  AppAlert.success(ref, 'Account data reset successfully.');
                  ref.read(authProvider.notifier).logout();
                }
              } catch (e) {
                if (context.mounted) AppAlert.error(ref, 'Reset failed: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('RESET ACCOUNT'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Sign Out?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isDark;
  const _ProfileSection({required this.title, required this.children, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.5)),
        const SizedBox(height: 16),
        Material(
          color: isDark ? AppColors.darkCard : Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _ProfileTile({required this.label, required this.value, required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: (color ?? AppColors.primary).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color ?? AppColors.primary, size: 18),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      subtitle: Text(value, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }
}
