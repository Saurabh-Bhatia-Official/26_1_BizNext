// lib/features/notifications/screens/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../models/notification_item_model.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notificationsAsync = ref.watch(notificationsProvider);
    final filteredItems = ref.watch(filteredNotificationsProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final activeFilter = ref.watch(notificationFilterTypeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Header Bar ──
            _buildHeader(context, ref, isDark, unreadCount),
            const SizedBox(height: 20),

            // ── KPI Summary Cards ──
            notificationsAsync.maybeWhen(
              data: (items) => _buildKpiRow(items, isDark),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // ── Search & Filter Ribbon ──
            _buildFilterAndSearchRibbon(context, ref, isDark, activeFilter),
            const SizedBox(height: 16),

            // ── Notifications Content List ──
            Expanded(
              child: notificationsAsync.when(
                data: (_) {
                  if (filteredItems.isEmpty) {
                    return _buildEmptyState(isDark, activeFilter);
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 32),
                    itemCount: filteredItems.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                      final item = filteredItems[index];
                      return _NotificationCard(item: item, isDark: isDark);
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text('Failed to load notifications: $err'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                        onPressed: () => ref.read(notificationsProvider.notifier).refresh(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, bool isDark, int unreadCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Notifications Center',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : AppColors.textLight,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      '$unreadCount NEW',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'Automated business alerts, low stock warnings, and payment reminders',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.radar_rounded, size: 16),
              label: const Text('Scan Alerts'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final count = await ref.read(notificationsProvider.notifier).scanAndGenerateAlerts();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(count > 0 ? 'Found & generated $count new alerts' : 'All systems clear! No new alerts found.'),
                      backgroundColor: count > 0 ? AppColors.success : Colors.indigo,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            if (unreadCount > 0)
              FilledButton.tonalIcon(
                icon: const Icon(Icons.done_all_rounded, size: 16),
                label: const Text('Mark All Read'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => ref.read(notificationsProvider.notifier).markAllAsRead(),
              ),
            IconButton.outlined(
              icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: AppColors.error),
              tooltip: 'Clear All Notifications',
              onPressed: () => _confirmClearAll(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiRow(List<NotificationItemModel> items, bool isDark) {
    final unread = items.where((n) => !n.isRead).length;
    final stockAlerts = items.where((n) => n.type == SystemNotificationType.lowStock).length;
    final dueAlerts = items.where((n) => n.type == SystemNotificationType.duePayment).length;

    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            title: 'Unread Alerts',
            value: '$unread',
            icon: Icons.notifications_active_rounded,
            color: AppColors.primary,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            title: 'Low Stock Warnings',
            value: '$stockAlerts',
            icon: Icons.inventory_2_rounded,
            color: Colors.orange,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            title: 'Payment & Dues',
            value: '$dueAlerts',
            icon: Icons.account_balance_wallet_rounded,
            color: AppColors.error,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterAndSearchRibbon(BuildContext context, WidgetRef ref, bool isDark, String activeFilter) {
    final filters = [
      {'id': 'all', 'label': 'All Alerts', 'icon': Icons.grid_view_rounded},
      {'id': 'unread', 'label': 'Unread Only', 'icon': Icons.mark_email_unread_rounded},
      {'id': 'low_stock', 'label': 'Low Stock', 'icon': Icons.inventory_2_rounded},
      {'id': 'due_payment', 'label': 'Payment Dues', 'icon': Icons.account_balance_wallet_rounded},
      {'id': 'sales_milestone', 'label': 'Sales', 'icon': Icons.trending_up_rounded},
      {'id': 'system', 'label': 'System', 'icon': Icons.settings_suggest_rounded},
    ];

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((f) {
                final isSelected = activeFilter == f['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(
                      f['icon'] as IconData,
                      size: 14,
                      color: isSelected ? Colors.white : AppColors.primary,
                    ),
                    label: Text(
                      f['label'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textLight),
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) => ref.read(notificationFilterTypeProvider.notifier).state = f['id'] as String,
                    selectedColor: AppColors.primary,
                    backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 260,
          height: 42,
          child: TextField(
            controller: _searchController,
            onChanged: (v) => ref.read(notificationSearchQueryProvider.notifier).state = v,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Search notifications...',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.primary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(notificationSearchQueryProvider.notifier).state = '';
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark, String activeFilter) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            activeFilter == 'all' ? 'All Caught Up!' : 'No Notifications in this filter',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.textLight,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'New inventory alerts, balance dues, and system events will appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Notifications?'),
        content: const Text('This will delete all notifications from your notification center permanently.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(notificationsProvider.notifier).clearAll();
    }
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textLight,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  final NotificationItemModel item;
  final bool isDark;

  const _NotificationCard({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeColor = item.type.color;

    return InkWell(
      onTap: () {
        if (!item.isRead && item.id != null) {
          ref.read(notificationsProvider.notifier).markAsRead(item.id!);
        }
        _handleActionNavigation(context, ref, item);
      },
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? (item.isRead ? AppColors.darkCard : AppColors.darkCard.withValues(alpha: 0.95))
              : (item.isRead ? Colors.white : const Color(0xFFF8FAFF)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: !item.isRead
                ? AppColors.primary.withValues(alpha: 0.3)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: !item.isRead ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: !item.isRead
                  ? AppColors.primary.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Icon Container ──
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.type.icon, color: typeColor, size: 24),
            ),
            const SizedBox(width: 14),

            // ── Details ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Priority Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.priority.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.priority.value.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: item.priority.color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Type Name
                      Text(
                        item.type.displayName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const Spacer(),
                      // Timestamp
                      Text(
                        item.timeAgo(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (!item.isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? Colors.white70 : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Action Buttons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (item.actionType != null)
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                          label: Text(_getActionLabel(item.actionType)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _handleActionNavigation(context, ref, item),
                        )
                      else
                        const SizedBox.shrink(),

                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!item.isRead && item.id != null)
                            IconButton(
                              icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                              tooltip: 'Mark as read',
                              onPressed: () => ref.read(notificationsProvider.notifier).markAsRead(item.id!),
                            ),
                          if (item.id != null)
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                              tooltip: 'Dismiss',
                              onPressed: () => ref.read(notificationsProvider.notifier).deleteNotification(item.id!),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getActionLabel(String? actionType) {
    switch (actionType) {
      case 'nav_inventory':
        return 'Manage Inventory';
      case 'nav_customers':
        return 'View Customer Ledger';
      case 'nav_sales':
        return 'View Sales';
      case 'nav_accounts':
        return 'Check Accounts';
      default:
        return 'Take Action';
    }
  }

  void _handleActionNavigation(BuildContext context, WidgetRef ref, NotificationItemModel item) {
    if (item.actionType == 'nav_inventory') {
      ref.read(selectedNavIndexProvider.notifier).state = 5; // Inventory Screen
    } else if (item.actionType == 'nav_customers') {
      ref.read(selectedNavIndexProvider.notifier).state = 6; // Customers Screen
    } else if (item.actionType == 'nav_sales') {
      ref.read(selectedNavIndexProvider.notifier).state = 2; // Sales Screen
    } else if (item.actionType == 'nav_accounts') {
      ref.read(selectedNavIndexProvider.notifier).state = 8; // Accounts Screen
    }
  }
}
