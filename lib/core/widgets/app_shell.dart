// lib/core/widgets/app_shell.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import 'app_sidebar.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/billing/screens/sales_screen.dart';
import '../../features/billing/screens/pos_billing_screen.dart';
import '../../features/customers/screens/customer_screen.dart';
import '../../features/suppliers/screens/supplier_screen.dart';
import '../../features/purchases/screens/purchase_screen.dart';
import '../../features/purchases/screens/add_purchase_screen.dart';
import '../../features/accounts/screens/accounts_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/discounts/screens/offers_screen.dart';
import '../../features/coming_soon/loyalty_screen.dart';
import '../../features/coming_soon/notifications_screen.dart';
import '../../features/settings/screens/profile_screen.dart';
import '../../features/ai_chatbot/screens/chatbot_screen.dart';
import '../../features/budgeting/screens/budget_screen.dart';
import 'notification_overlay.dart';
import '../../core/services/sync_service.dart';
import '../services/subscription_service.dart';
import '../../core/services/shortcut_service.dart';

final selectedNavIndexProvider = StateProvider<int>((ref) => 0);
final previousNavIndexProvider = StateProvider<int>((ref) => 0);
final sidebarHiddenProvider = StateProvider<bool>((ref) => false);
final shellNavigatorKey = GlobalKey<NavigatorState>();

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}


class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Trigger sync immediately on shell start
    _triggerFocusSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _triggerFocusSync();
    }
  }

  void _triggerFocusSync() {
    try {
      SyncService().syncNow("dummy_token_12345");
    } catch (e) {
      debugPrint("Auto-sync on app focus error: $e");
    }
  }
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    20, // Generated 20 keys to prevent bounds issues with new screens
    (index) => GlobalKey<NavigatorState>(),
  );

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedNavIndexProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final isWide = MediaQuery.of(context).size.width >= AppConstants.sidebarBreakpoint;

    final screens = [
      const DashboardScreen(),
      PosBillingScreen(),
      const SalesScreen(),
      const AddPurchaseScreen(),
      const PurchaseScreen(),
      const InventoryScreen(),
      const CustomerScreen(),
      const SupplierScreen(),
      const AccountsScreen(),
      const ReportsScreen(),
      const BudgetScreen(),
      const OffersScreen(),
      const LoyaltyScreen(),
      const NotificationsScreen(),
      const ChatbotScreen(),
      const SettingsScreen(),
      const ProfileScreen(),
    ];

    return ShortcutListener(
      child: Stack(
        children: [
          AppShortcut(
            actionId: 'nav_dashboard',
            onPressed: () => ref.read(selectedNavIndexProvider.notifier).state = 0,
            child: const SizedBox.shrink(),
          ),
          AppShortcut(
            actionId: 'nav_pos',
            onPressed: () => ref.read(selectedNavIndexProvider.notifier).state = 1,
            child: const SizedBox.shrink(),
          ),
          AppShortcut(
            actionId: 'nav_sales',
            onPressed: () => ref.read(selectedNavIndexProvider.notifier).state = 2,
            child: const SizedBox.shrink(),
          ),
          AppShortcut(
            actionId: 'nav_inventory',
            onPressed: () => ref.read(selectedNavIndexProvider.notifier).state = 5,
            child: const SizedBox.shrink(),
          ),
          AppShortcut(
            actionId: 'nav_settings',
            onPressed: () => ref.read(selectedNavIndexProvider.notifier).state = 15,
            child: const SizedBox.shrink(),
          ),
          Scaffold(
            backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        appBar: isWide
            ? null
            : AppBar(
                backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                elevation: 0,
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      selectedIndex < navDestinations.length 
                        ? navDestinations[selectedIndex].label 
                        : 'Profile',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                centerTitle: true,
                leading: Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                    onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
        drawer: isWide
            ? null
            : Drawer(
                width: 260,
                child: AppSidebar(
                  selectedIndex: selectedIndex,
                  isCollapsedOverride: false,
                  onDestinationSelected: (i) {
                    ref.read(previousNavIndexProvider.notifier).state = ref.read(selectedNavIndexProvider);
                    ref.read(selectedNavIndexProvider.notifier).state = i;
                    Navigator.of(context).pop();
                  },
                ),
              ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Row(
                    children: [
                      if (isWide && !ref.watch(sidebarHiddenProvider))
                        AppSidebar(
                          selectedIndex: selectedIndex,
                          onDestinationSelected: (i) {
                            ref.read(previousNavIndexProvider.notifier).state = ref.read(selectedNavIndexProvider);
                            ref.read(selectedNavIndexProvider.notifier).state = i;
                          },
                        ),
                      Expanded(
                        child: Stack(
                          children: [
                            IndexedStack(
                              index: selectedIndex,
                              children: List.generate(screens.length, (index) {
                                final isPro = ref.watch(subscriptionServiceProvider).isPro;
                                final restrictedIndices = [11, 12, 13, 14];
                                final showLock = !isPro && restrictedIndices.contains(index);
  
                                if (showLock) {
                                  return const PremiumLockedScreen();
                                }
  
                                return Navigator(
                                  key: _navigatorKeys[index],
                                  onGenerateRoute: (settings) => MaterialPageRoute(
                                    builder: (context) => screens[index],
                                  ),
                                );
                              }),
                            ),
                            if (isWide && ref.watch(sidebarHiddenProvider))
                              Positioned(
                                left: 16,
                                top: 24,
                                child: Material(
                                  color: isDark ? AppColors.darkSurface : Colors.white,
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                    ),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.menu_rounded, color: AppColors.primary),
                                    onPressed: () => ref.read(sidebarHiddenProvider.notifier).state = false,
                                    tooltip: 'Show Sidebar',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const NotificationOverlay(),
                ],
              ),
            ),
            const _BetaBanner(),
          ],
        ),
        bottomNavigationBar: isWide
            ? null
            : Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildBottomNavItem(
                          context,
                          ref,
                          icon: Icons.grid_view_rounded,
                          activeIcon: Icons.grid_view_rounded,
                          label: 'Dashboard',
                          index: 0,
                          currentIndex: selectedIndex,
                        ),
                        _buildBottomNavItem(
                          context,
                          ref,
                          icon: Icons.shopping_cart_outlined,
                          activeIcon: Icons.shopping_cart_rounded,
                          label: 'POS',
                          index: 1,
                          currentIndex: selectedIndex,
                        ),
                        _buildBottomNavItem(
                          context,
                          ref,
                          icon: Icons.receipt_long_outlined,
                          activeIcon: Icons.receipt_long_rounded,
                          label: 'Sales',
                          index: 2,
                          currentIndex: selectedIndex,
                        ),
                        _buildBottomNavItem(
                          context,
                          ref,
                          icon: Icons.inventory_2_outlined,
                          activeIcon: Icons.inventory_2_rounded,
                          label: 'Stock',
                          index: 5,
                          currentIndex: selectedIndex,
                        ),
                        Builder(
                          builder: (ctx) => _buildBottomNavItem(
                            context,
                            ref,
                            icon: Icons.menu_rounded,
                            activeIcon: Icons.menu_rounded,
                            label: 'More',
                            index: -1,
                            currentIndex: selectedIndex,
                            onTap: () {
                              Scaffold.of(ctx).openDrawer();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required int currentIndex,
    VoidCallback? onTap,
  }) {
    final isSelected = index == currentIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Expanded(
      child: InkWell(
        onTap: onTap ?? () {
          ref.read(previousNavIndexProvider.notifier).state = ref.read(selectedNavIndexProvider);
          ref.read(selectedNavIndexProvider.notifier).state = index;
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? AppColors.primary : (isDark ? Colors.white60 : Colors.black54),
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.primary : (isDark ? Colors.white60 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BetaBanner extends StatelessWidget {
  const _BetaBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFF59E0B),
            Color(0xFFD97706),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.science_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              '🧪  BETA TESTING VERSION — This is a beta version of the software. It may contain bugs. We appreciate your patience and feedback.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumLockedScreen extends ConsumerWidget {
  const PremiumLockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 30,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded, size: 50, color: Colors.amber),
              ),
              const SizedBox(height: 24),
              const Text(
                'Premium Feature Locked',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'This module requires an active PRO subscription. Enjoy advanced loyalty sync, database integrations, chatbot help, and infinite invoice generation.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    // Navigate to Subscription Management in Settings (index 15)
                    ref.read(selectedNavIndexProvider.notifier).state = 15;
                  },
                  icon: const Icon(Icons.star_rounded),
                  label: const Text('Upgrade via Razorpay', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
