// lib/core/widgets/app_sidebar.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../../features/settings/providers/settings_provider.dart';
import 'app_shell.dart';
import '../services/sync_service.dart';
import '../database/database_providers.dart';
import '../services/rbac_service.dart';

import '../constants/app_constants.dart';

class NavDestination {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const NavDestination({required this.label, required this.icon, required this.activeIcon});
}

const navDestinations = [
  NavDestination(label: 'Dashboard', icon: Icons.grid_view_rounded, activeIcon: Icons.grid_view_rounded),
  NavDestination(label: 'POS Billing', icon: Icons.shopping_cart_outlined, activeIcon: Icons.shopping_cart_rounded),
  NavDestination(label: 'Sales History', icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded),
  NavDestination(label: 'Record Purchase', icon: Icons.add_business_outlined, activeIcon: Icons.add_business_rounded),
  NavDestination(label: 'Purchase History', icon: Icons.shopping_bag_outlined, activeIcon: Icons.shopping_bag_rounded),
  NavDestination(label: 'Inventory', icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2_rounded),
  NavDestination(label: 'Customers', icon: Icons.people_outline_rounded, activeIcon: Icons.people_rounded),
  NavDestination(label: 'Suppliers', icon: Icons.local_shipping_outlined, activeIcon: Icons.local_shipping_rounded),
  NavDestination(label: 'Accounts', icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded),
  NavDestination(label: 'Reports', icon: Icons.analytics_outlined, activeIcon: Icons.analytics_rounded),
  NavDestination(label: 'Budgeting & Goals', icon: Icons.pie_chart_outline_rounded, activeIcon: Icons.pie_chart_rounded),
  NavDestination(label: 'Offers & Promotions', icon: Icons.local_offer_outlined, activeIcon: Icons.local_offer_rounded),
  NavDestination(label: 'Loyalty Program', icon: Icons.stars_rounded, activeIcon: Icons.stars_rounded),
  NavDestination(label: 'Notifications', icon: Icons.chat_bubble_rounded, activeIcon: Icons.chat_bubble_rounded),
  NavDestination(label: 'AI Assistant', icon: Icons.insights_rounded, activeIcon: Icons.insights_rounded),
  NavDestination(label: 'Settings', icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded),
];

class AppSidebar extends ConsumerWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;
  final bool? isCollapsedOverride;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.isCollapsedOverride,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarColor = isDark ? AppColors.darkSidebar : AppColors.lightSidebar;
    final isCollapsed = isCollapsedOverride ?? (MediaQuery.of(context).size.width < 1100);
    final settings = ref.watch(featureSettingsProvider);
    final isWide = MediaQuery.of(context).size.width >= AppConstants.sidebarBreakpoint;

    return Container(
      width: isCollapsed ? 88 : 280,
      height: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: sidebarColor,
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(5, 0)),
        ],
        border: Border(right: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.05), width: 1)),
      ),
      child: Column(
        children: [
          // ── Brand Identity ──
          Padding(
            padding: EdgeInsets.fromLTRB(isCollapsed ? 12 : 24, 40, isCollapsed ? 12 : 24, 32),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    if (!isCollapsed) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'BIZNEXT',
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.textLight,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'BUSINESS',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isWide) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => ref.read(sidebarHiddenProvider.notifier).state = true,
                          icon: const Icon(Icons.menu_open_rounded, color: AppColors.primary, size: 20),
                          tooltip: 'Hide Sidebar',
                        ),
                      ],
                    ],
                  ],
                ),
                if (!isCollapsed) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const _ReloadButton(),
                      const SizedBox(width: 8),
                      _ThemeToggleSmall(),
                    ],
                  ),
                ],
                if (isCollapsed) ...[
                  const SizedBox(height: 20),
                  const _ReloadButton(),
                  const SizedBox(height: 12),
                  _ThemeToggleSmall(),
                  if (isWide) ...[
                    const SizedBox(height: 12),
                    IconButton(
                      onPressed: () => ref.read(sidebarHiddenProvider.notifier).state = true,
                      icon: const Icon(Icons.menu_open_rounded, color: AppColors.primary, size: 20),
                      tooltip: 'Hide Sidebar',
                    ),
                  ],
                ],
              ],
            ),
          ),

          // ── Workplace Switcher ──
          if (!isCollapsed) const _BusinessSwitcher(),
          
          const SizedBox(height: 16),

          // ── Navigation Engine ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                if (!isCollapsed) _SectionHeader(title: 'MAIN'),
                _buildNavItem(context, ref, 0, isCollapsed), // Dashboard
                
                const SizedBox(height: 24),
                if (!isCollapsed) _SectionHeader(title: 'SALES & BILLING'),
                _buildNavItem(context, ref, 1, isCollapsed), // POS
                _buildNavItem(context, ref, 2, isCollapsed), // Sales History

                const SizedBox(height: 24),
                if (!isCollapsed) _SectionHeader(title: 'PURCHASES & STOCK'),
                _buildNavItem(context, ref, 3, isCollapsed), // Record Purchase
                _buildNavItem(context, ref, 4, isCollapsed), // Purchase History
                if (settings.inventoryTrackingEnabled) _buildNavItem(context, ref, 5, isCollapsed), // Inventory

                const SizedBox(height: 24),
                if (!isCollapsed) _SectionHeader(title: 'RELATIONSHIPS'),
                _buildNavItem(context, ref, 6, isCollapsed), // Customers
                _buildNavItem(context, ref, 7, isCollapsed), // Suppliers

                const SizedBox(height: 24),
                if (!isCollapsed) _SectionHeader(title: 'FINANCE & AUDIT'),
                _buildNavItem(context, ref, 8, isCollapsed), // Accounts
                _buildNavItem(context, ref, 9, isCollapsed), // Reports
                _buildNavItem(context, ref, 10, isCollapsed), // Budgeting

                const SizedBox(height: 24),
                if (!isCollapsed && (settings.offersEnabled || settings.loyaltyEnabled)) _SectionHeader(title: 'PROMOTIONS & LOYALTY'),
                if (settings.offersEnabled) _buildNavItem(context, ref, 11, isCollapsed), // Offers & Promotions
                if (settings.loyaltyEnabled) _buildNavItem(context, ref, 12, isCollapsed), // Loyalty

                if (settings.notificationsEnabled) ...[
                  const SizedBox(height: 24),
                  if (!isCollapsed) _SectionHeader(title: 'COMMUNICATION'),
                  _buildNavItem(context, ref, 13, isCollapsed), // Notifications
                ],

                const SizedBox(height: 24),
                if (!isCollapsed) _SectionHeader(title: 'AI INSIGHTS'),
                _buildNavItem(context, ref, 14, isCollapsed), // AI Assistant

                const SizedBox(height: 24),
                if (!isCollapsed) _SectionHeader(title: 'CONFIGURATION'),
                _buildNavItem(context, ref, 15, isCollapsed), // Settings
                const SizedBox(height: 32),
              ],
            ),
          ),

          // ── Theme Switcher & Footer ──
          _SidebarFooter(isCollapsed: isCollapsed),
        ],
      ),
    );
  }
  Widget _buildNavItem(BuildContext context, WidgetRef ref, int index, bool isCollapsed) {
    final d = navDestinations[index];
    final active = selectedIndex == index;
    
    // Gate role-based access
    final rbac = ref.watch(rbacProvider);
    bool hasRoleAccess = true;
    if (index == 9) { // Reports
      hasRoleAccess = rbac.hasPermission(AppPermission.viewReports);
    } else if (index == 10) { // Budgeting
      hasRoleAccess = rbac.hasPermission(AppPermission.manageBudgets);
    } else if (index == 15) { // Settings
      hasRoleAccess = rbac.hasPermission(AppPermission.manageSettings);
    } else if (index == 8) { // Accounts
      hasRoleAccess = rbac.isOwnerOrAdmin || rbac.isManager;
    } else if (index == 3 || index == 4 || index == 5 || index == 7) { // Purchase & Inventory, Suppliers
      hasRoleAccess = rbac.isOwnerOrAdmin || rbac.isManager;
    }

    if (!hasRoleAccess) {
      return const SizedBox.shrink(); // Hide the nav item completely for unauthorized roles
    }

    return _SidebarItem(
      label: d.label,
      icon: active ? d.activeIcon : d.icon,
      isSelected: active,
      isCollapsed: isCollapsed,
      isLocked: false,
      onTap: () {
        onDestinationSelected(index);
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white.withValues(alpha: 0.3) : AppColors.textLight.withValues(alpha: 0.4),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _BusinessSwitcher extends ConsumerWidget {
  const _BusinessSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biz = ref.watch(currentBusinessProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => ref.read(authProvider.notifier).goToBusinessSelector(),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary.withValues(alpha: 0.2), AppColors.accent.withValues(alpha: 0.2)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.business_center_rounded, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        biz?.name ?? 'No Business',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: isDark ? Colors.white : AppColors.textLight, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                      Text('Switch Workspace', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Icon(Icons.unfold_more_rounded, color: AppColors.textMuted, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isCollapsed;
  final bool isLocked;
  final VoidCallback onTap;

  const _SidebarItem({required this.label, required this.icon, required this.isSelected, required this.isCollapsed, this.isLocked = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: 250.ms,
            curve: Curves.fastOutSlowIn,
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 12, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected 
                  ? AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08) 
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: isLocked
                      ? Colors.grey.withValues(alpha: 0.5)
                      : (isSelected ? AppColors.primary : (isDark ? Colors.white.withValues(alpha: 0.35) : AppColors.textLight.withValues(alpha: 0.5))),
                  size: 20,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isLocked
                            ? Colors.grey.withValues(alpha: 0.5)
                            : (isSelected ? (isDark ? Colors.white : AppColors.primary) : (isDark ? Colors.white.withValues(alpha: 0.7) : AppColors.textLight.withValues(alpha: 0.8))),
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  if (isLocked)
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: Colors.amber.shade800.withValues(alpha: 0.7),
                    )
                  else if (isSelected)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 4),
                        ],
                      ),
                    ).animate().scale(duration: 200.ms),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends ConsumerWidget {
  final bool isCollapsed;
  const _SidebarFooter({required this.isCollapsed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const tier = 'pro';
    const isPro = true;

    if (isCollapsed) {
      return InkWell(
        onTap: () {
          ref.read(previousNavIndexProvider.notifier).state = ref.read(selectedNavIndexProvider);
          ref.read(selectedNavIndexProvider.notifier).state = 16;
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          margin: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : AppColors.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.primary.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: const Icon(Icons.person_rounded, size: 18, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              IconButton(
                onPressed: () => ref.read(authProvider.notifier).logout(),
                icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                tooltip: 'Logout',
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: () {
        ref.read(previousNavIndexProvider.notifier).state = ref.read(selectedNavIndexProvider);
        ref.read(selectedNavIndexProvider.notifier).state = 16;
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.all(14),
        decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
            ),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: const Icon(Icons.person_rounded, size: 18, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user?.fullName ?? 'Admin',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  (user?.role ?? 'Owner').toUpperCase(),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => ref.read(authProvider.notifier).logout(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.logout_rounded, size: 16, color: AppColors.error),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }
}
class _ThemeToggleSmall extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return InkWell(
      onTap: () => ref.read(themeModeProvider.notifier).toggle(),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: 300.ms,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
        ),
        child: Icon(
          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          color: isDark ? Colors.amber : AppColors.primary,
          size: 18,
        ),
      ),
    );
  }
}

class _ReloadButton extends ConsumerStatefulWidget {
  const _ReloadButton();

  @override
  ConsumerState<_ReloadButton> createState() => _ReloadButtonState();
}

class _ReloadButtonState extends ConsumerState<_ReloadButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleReload({bool isAutoTriggered = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    _controller.repeat();

    try {
      await SyncService().syncNow("dummy_token_12345");
      if (mounted && !isAutoTriggered) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Software and data reloaded successfully!"),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Reload failed: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        _controller.stop();
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Automatically trigger synchronization when local data or settings change in DB
    ref.listen<int>(databaseVersionProvider, (previous, next) {
      if (previous != null && next > previous) {
        _handleReload(isAutoTriggered: true);
      }
    });

    return Tooltip(
      message: 'Reload Software',
      child: InkWell(
        onTap: () => _handleReload(isAutoTriggered: false),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
            ),
          ),
          child: RotationTransition(
            turns: _controller,
            child: Icon(
              Icons.sync_rounded,
              color: isDark ? AppColors.accent : AppColors.primary,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}
