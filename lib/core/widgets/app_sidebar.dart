// lib/core/widgets/app_sidebar.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/settings/providers/settings_provider.dart';
import 'app_shell.dart';

import '../database/database_providers.dart';
import '../services/rbac_service.dart';
import '../../features/notifications/providers/notifications_provider.dart';

import '../constants/app_constants.dart';

class NavDestination {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const NavDestination({required this.label, required this.icon, required this.activeIcon});
}

const navDestinations = [
  NavDestination(label: 'Dashboard', icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded),
  NavDestination(label: 'POS Billing', icon: Icons.point_of_sale_outlined, activeIcon: Icons.point_of_sale_rounded),
  NavDestination(label: 'Sales History', icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded),
  NavDestination(label: 'Quick Purchase', icon: Icons.add_shopping_cart_rounded, activeIcon: Icons.add_shopping_cart_rounded),
  NavDestination(label: 'Purchase History', icon: Icons.shopping_bag_outlined, activeIcon: Icons.shopping_bag_rounded),
  NavDestination(label: 'Inventory', icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2_rounded),
  NavDestination(label: 'Customers', icon: Icons.people_outline_rounded, activeIcon: Icons.people_rounded),
  NavDestination(label: 'Suppliers', icon: Icons.local_shipping_outlined, activeIcon: Icons.local_shipping_rounded),
  NavDestination(label: 'Accounts', icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded),
  NavDestination(label: 'Reports', icon: Icons.analytics_outlined, activeIcon: Icons.analytics_rounded),
  NavDestination(label: 'Budgeting & Goals', icon: Icons.pie_chart_outline_rounded, activeIcon: Icons.pie_chart_rounded),
  NavDestination(label: 'Offers & Promotions', icon: Icons.local_offer_outlined, activeIcon: Icons.local_offer_rounded),
  NavDestination(label: 'Loyalty Program', icon: Icons.stars_rounded, activeIcon: Icons.stars_rounded),
  NavDestination(label: 'Notifications', icon: Icons.notifications_none_rounded, activeIcon: Icons.notifications_rounded),
  NavDestination(label: 'AI Assistant', icon: Icons.insights_rounded, activeIcon: Icons.insights_rounded),
  NavDestination(label: 'Settings', icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded),
];

class AppSidebar extends ConsumerWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;
  final bool? isCollapsedOverride;
  final GlobalKey? dashboardKey;
  final GlobalKey? posKey;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.isCollapsedOverride,
    this.dashboardKey,
    this.posKey,
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
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    if (!isCollapsed) ...[
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'BIZNEXT',
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.textLight,
                                fontSize: 22,
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
                if (isCollapsed && isWide) ...[
                  const SizedBox(height: 12),
                  IconButton(
                    onPressed: () => ref.read(sidebarHiddenProvider.notifier).state = true,
                    icon: const Icon(Icons.menu_open_rounded, color: AppColors.primary, size: 20),
                    tooltip: 'Hide Sidebar',
                  ),
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

    // ── Role-based access gate ─────────────────────────────────────────────
    final rbac = ref.watch(rbacProvider);
    bool hasRoleAccess;

    switch (index) {
      case 0: // Dashboard — everyone
      case 1: // POS / Billing — everyone
      case 2: // Sales History — everyone
      case 14: // AI Assistant — everyone
        hasRoleAccess = true;
        break;

      case 3: // Record Purchase
      case 4: // Purchase History
        hasRoleAccess = rbac.hasPermission(AppPermission.managePurchases);
        break;

      case 5: // Inventory
        hasRoleAccess = rbac.hasPermission(AppPermission.manageInventory);
        break;

      case 6: // Customers
        hasRoleAccess = rbac.hasPermission(AppPermission.manageCustomers);
        break;

      case 7: // Suppliers
        hasRoleAccess = rbac.hasPermission(AppPermission.manageSuppliers);
        break;

      case 8: // Accounts — Owner & Admin only
        hasRoleAccess = rbac.hasPermission(AppPermission.viewAccounts);
        break;

      case 9: // Reports
        hasRoleAccess = rbac.hasPermission(AppPermission.viewReports);
        break;

      case 10: // Budgeting
        hasRoleAccess = rbac.hasPermission(AppPermission.manageBudgets);
        break;

      case 11: // Offers & Promotions
        hasRoleAccess = rbac.hasPermission(AppPermission.manageOffers);
        break;

      case 12: // Loyalty
        hasRoleAccess = rbac.hasPermission(AppPermission.manageLoyalty);
        break;

      case 13: // Notifications — Owner, Admin, Manager
        hasRoleAccess = rbac.isOwnerOrAdmin || rbac.isManager;
        break;

      case 15: // Settings — Owner & Admin only
        hasRoleAccess = rbac.hasPermission(AppPermission.manageSettings);
        break;

      default:
        hasRoleAccess = true;
    }

    if (!hasRoleAccess) {
      return const SizedBox.shrink(); // Hide nav item completely for unauthorised roles
    }


    int badgeCount = 0;
    if (index == 13) {
      badgeCount = ref.watch(unreadNotificationsCountProvider);
    }

    return _SidebarItem(
      key: index == 0 ? dashboardKey : (index == 1 ? posKey : null),
      label: d.label,
      icon: active ? d.activeIcon : d.icon,
      isSelected: active,
      isCollapsed: isCollapsed,
      isLocked: false,
      badgeCount: badgeCount,
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
                        (biz?.name != null && biz!.name.isNotEmpty) ? biz.name : 'Company Name',
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
  final int badgeCount;
  final VoidCallback onTap;

  const _SidebarItem({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isCollapsed,
    this.isLocked = false,
    this.badgeCount = 0,
    required this.onTap,
  });

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
                badgeCount > 0 && isCollapsed
                    ? Badge.count(
                        count: badgeCount,
                        backgroundColor: AppColors.primary,
                        textColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
                        child: Icon(
                          icon,
                          color: isLocked
                              ? Colors.grey.withValues(alpha: 0.5)
                              : (isSelected ? AppColors.primary : (isDark ? Colors.white.withValues(alpha: 0.35) : AppColors.textLight.withValues(alpha: 0.5))),
                          size: 20,
                        ),
                      )
                    : Icon(
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
                  else if (badgeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
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
