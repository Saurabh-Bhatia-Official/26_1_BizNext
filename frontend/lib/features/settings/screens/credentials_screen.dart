import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/notification_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../../../core/services/rbac_service.dart';

final _allUsersProvider = FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.getAllUsers();
});

class CredentialsScreen extends ConsumerWidget {
  const CredentialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rbac = ref.watch(rbacProvider);
    
    if (!rbac.hasPermission(AppPermission.manageCredentials)) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: Navigator.canPop(context)
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87),
                  onPressed: () => Navigator.maybePop(context),
                  tooltip: 'Back',
                ),
              )
            : null,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 64,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
              const SizedBox(height: 16),
              Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You do not have permission to view or manage credentials.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final usersAsync = ref.watch(_allUsersProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Header Bar ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (Navigator.canPop(context)) ...[
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: isDark ? Colors.white : AppColors.textLight,
                      size: 26,
                    ),
                    onPressed: () => Navigator.maybePop(context),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All Login Credentials',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Manage user accounts, assigned roles, and login access',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddUserDialog(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.person_add_rounded, size: 20),
                  label: const Text(
                    'Add User',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── RBAC Security Notice ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AES-256 Encryption & Salted HMAC SHA-256 Password Hashing Active. All user accounts, tokens, and credentials are cryptographically protected.',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Users Table / Cards ──
            usersAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(
                    'Failed to load users: $e',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
              data: (users) {
                if (users.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          const Icon(Icons.people_outline_rounded, size: 56, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          const Text(
                            'No user credentials found',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showAddUserDialog(context, ref),
                            icon: const Icon(Icons.person_add_rounded),
                            label: const Text('Create First User Account'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Material(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Column(
                    children: [
                      _HeaderRow(isDark: isDark),
                      ...List.generate(users.length, (i) {
                        final user = users[i];
                        final isCurrentUser = ref.watch(currentUserProvider)?.id == user.id;

                        return Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: user.role == AppConstants.roleOwner || user.role == AppConstants.roleAdmin
                                    ? Colors.amber.withValues(alpha: 0.18)
                                    : AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                user.role == AppConstants.roleOwner || user.role == AppConstants.roleAdmin
                                    ? Icons.star_rounded
                                    : Icons.person_rounded,
                                color: user.role == AppConstants.roleOwner || user.role == AppConstants.roleAdmin
                                    ? Colors.amber.shade700
                                    : AppColors.primary,
                                size: 22,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  user.fullName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: isDark ? Colors.white : AppColors.textLight,
                                  ),
                                ),
                                if (isCurrentUser) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'You',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '@${user.username}',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  if (user.email != null && user.email!.isNotEmpty)
                                    Text('Email: ${user.email!}', style: const TextStyle(fontSize: 12)),
                                  if (user.phone != null && user.phone!.isNotEmpty)
                                    Text('Phone: ${user.phone!}', style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Role Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _getRoleColor(user.role).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _getRoleColor(user.role).withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    user.role.toUpperCase().replaceAll('_', ' '),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: _getRoleColor(user.role),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Edit Button
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, size: 20, color: AppColors.primary),
                                  tooltip: 'Edit User & Role',
                                  onPressed: () => _showEditUserDialog(context, ref, user),
                                ),

                                // Reset Password Button
                                IconButton(
                                  icon: const Icon(Icons.key_rounded, size: 20, color: Colors.orange),
                                  tooltip: 'Reset Password',
                                  onPressed: () => _showChangePasswordDialog(context, ref, user),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case AppConstants.roleOwner:
        return Colors.purple;
      case AppConstants.roleAdmin:
        return Colors.amber.shade800;
      case AppConstants.roleManager:
        return Colors.blue;
      case AppConstants.rolePurchaseManager:
        return Colors.teal;
      case AppConstants.roleInventoryManager:
        return Colors.indigo;
      case AppConstants.roleCashier:
        return Colors.green;
      default:
        return Colors.grey.shade700;
    }
  }

  // ── Add User Modal ──────────────────────────────────────────────────────────
  void _showAddUserDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formKey = GlobalKey<FormState>();

    final fullNameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String selectedRole = AppConstants.roleAdmin;
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E34) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.person_add_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                'Add Login Credential',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: fullNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Full name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: usernameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Username *',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Username is required';
                        if (v.trim().length < 3) return 'Must be at least 3 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password *',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => obscurePassword = !obscurePassword),
                        ),
                      ),
                      validator: (v) => v == null || v.length < 4 ? 'Password must be at least 4 characters' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address (Optional)',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number (Optional)',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Assigned Role *',
                        prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                      ),
                      dropdownColor: isDark ? const Color(0xFF1E1E34) : Colors.white,
                      items: const [
                        DropdownMenuItem(value: AppConstants.roleAdmin, child: Text('Admin (Full Control)')),
                        DropdownMenuItem(value: AppConstants.roleOwner, child: Text('Owner (Full Control)')),
                        DropdownMenuItem(value: AppConstants.roleManager, child: Text('Manager (Operations)')),
                        DropdownMenuItem(value: AppConstants.rolePurchaseManager, child: Text('Purchase Manager')),
                        DropdownMenuItem(value: AppConstants.roleInventoryManager, child: Text('Inventory Manager')),
                        DropdownMenuItem(value: AppConstants.roleCashier, child: Text('Cashier (Billing Only)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => selectedRole = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Create User'),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final repo = ref.read(authRepositoryProvider);
                final bizId = ref.read(activeBusinessIdProvider);

                final username = usernameCtrl.text.trim();
                final exists = await repo.isUsernameTaken(username);
                if (exists) {
                  if (context.mounted) {
                    AppAlert.error(ref, "Username '$username' is already registered.");
                  }
                  return;
                }

                try {
                  await repo.createUser(
                    username: username,
                    password: passwordCtrl.text,
                    fullName: fullNameCtrl.text.trim(),
                    email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                    phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                    role: selectedRole,
                    businessId: bizId,
                  );
                  ref.invalidate(_allUsersProvider);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    AppAlert.success(ref, "User account '@$username' created successfully!");
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppAlert.error(ref, "Failed to create user: $e");
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit User Modal ─────────────────────────────────────────────────────────
  void _showEditUserDialog(BuildContext context, WidgetRef ref, UserModel user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formKey = GlobalKey<FormState>();

    final fullNameCtrl = TextEditingController(text: user.fullName);
    final emailCtrl = TextEditingController(text: user.email ?? '');
    final phoneCtrl = TextEditingController(text: user.phone ?? '');
    String selectedRole = user.role;
    bool isActive = user.isActive;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E34) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.edit_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                'Edit User: @${user.username}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: fullNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Full name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Assigned Role *',
                        prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                      ),
                      dropdownColor: isDark ? const Color(0xFF1E1E34) : Colors.white,
                      items: const [
                        DropdownMenuItem(value: AppConstants.roleAdmin, child: Text('Admin (Full Control)')),
                        DropdownMenuItem(value: AppConstants.roleOwner, child: Text('Owner (Full Control)')),
                        DropdownMenuItem(value: AppConstants.roleManager, child: Text('Manager (Operations)')),
                        DropdownMenuItem(value: AppConstants.rolePurchaseManager, child: Text('Purchase Manager')),
                        DropdownMenuItem(value: AppConstants.roleInventoryManager, child: Text('Inventory Manager')),
                        DropdownMenuItem(value: AppConstants.roleCashier, child: Text('Cashier (Billing Only)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => selectedRole = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      title: const Text('Account Status Active', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Inactive users cannot log into the software', style: TextStyle(fontSize: 12)),
                      value: isActive,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() => isActive = val),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save Changes'),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final repo = ref.read(authRepositoryProvider);

                final updatedUser = user.copyWith(
                  fullName: fullNameCtrl.text.trim(),
                  email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                  phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  role: selectedRole,
                  isActive: isActive,
                );

                try {
                  await repo.updateUser(updatedUser);
                  ref.invalidate(_allUsersProvider);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    AppAlert.success(ref, "User profile '@${user.username}' updated successfully!");
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppAlert.error(ref, "Failed to update user: $e");
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Change Password Modal ───────────────────────────────────────────────────
  void _showChangePasswordDialog(BuildContext context, WidgetRef ref, UserModel user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formKey = GlobalKey<FormState>();
    final passCtrl = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E34) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.key_rounded, color: Colors.orange),
              const SizedBox(width: 10),
              Text(
                'Reset Password: @${user.username}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: passCtrl,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'New Password *',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => obscurePassword = !obscurePassword),
                  ),
                ),
                validator: (v) => v == null || v.length < 4 ? 'Password must be at least 4 characters' : null,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              icon: const Icon(Icons.lock_reset_rounded),
              label: const Text('Update Password'),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final repo = ref.read(authRepositoryProvider);

                try {
                  await repo.changePassword(user.id!, passCtrl.text);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    AppAlert.success(ref, "Password updated successfully for '@${user.username}'!");
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppAlert.error(ref, "Failed to update password: $e");
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final bool isDark;
  const _HeaderRow({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSidebar : Colors.grey.withValues(alpha: 0.04),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 52),
          Text('User & Contact Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textMuted)),
          const Spacer(),
          Text('Role & Actions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(width: 80),
        ],
      ),
    );
  }
}
