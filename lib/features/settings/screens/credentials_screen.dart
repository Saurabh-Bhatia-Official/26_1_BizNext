import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../auth/models/user_model.dart';

final _allUsersProvider = FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.getAllUsers();
});

class CredentialsScreen extends ConsumerWidget {
  const CredentialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usersAsync = ref.watch(_allUsersProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All Login Credentials',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.textLight),
            ),
            const SizedBox(height: 8),
            const Text('View all registered user accounts', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Default credentials: admin / admin123',
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load users: $e', style: const TextStyle(color: AppColors.error))),
              data: (users) {
                if (users.isEmpty) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('No users found', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
                  ));
                }
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Column(
                    children: [
                      _HeaderRow(isDark: isDark),
                      ...List.generate(users.length, (i) {
                        final user = users[i];
                        final isDefault = user.username == 'admin';
                        return Container(
                          decoration: BoxDecoration(
                            color: isDefault ? AppColors.primary.withValues(alpha: 0.05) : null,
                            border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                          ),
                          child: ListTile(
                            title: Text(user.fullName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: isDark ? Colors.white : AppColors.textLight)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('@${user.username}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                if (user.email != null) Text(user.email!, style: const TextStyle(fontSize: 12)),
                                if (user.phone != null) Text(user.phone!, style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDefault ? Colors.amber.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isDefault ? Icons.star_rounded : Icons.person_rounded,
                                color: isDefault ? Colors.amber : AppColors.primary,
                                size: 20,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: user.role == 'owner' ? AppColors.primary.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                user.role.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: user.role == 'owner' ? AppColors.primary : Colors.green,
                                ),
                              ),
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
}

class _HeaderRow extends StatelessWidget {
  final bool isDark;
  const _HeaderRow({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSidebar : Colors.grey.withValues(alpha: 0.04),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 48),
          Text('User', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textMuted)),
          const Spacer(),
          Text('Role', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}
